#!/bin/bash
# Fully automated Kubernetes cluster deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if required tools are installed
    command -v terraform >/dev/null 2>&1 || error "Terraform is not installed"
    command -v aws >/dev/null 2>&1 || error "AWS CLI is not installed"
    command -v jq >/dev/null 2>&1 || error "jq is not installed"
    
    # Check AWS credentials
    aws sts get-caller-identity >/dev/null 2>&1 || error "AWS credentials not configured"
    
    # Check if terraform.tfvars exists
    if [ ! -f "infra/terraform/aws/terraform.tfvars" ]; then
        warn "terraform.tfvars not found, creating from example..."
        cp infra/terraform/aws/terraform.tfvars.example infra/terraform/aws/terraform.tfvars
        error "Please edit infra/terraform/aws/terraform.tfvars with your settings and run again"
    fi
    
    log "Prerequisites check passed ✅"
}

# Generate SSH key if not exists
setup_ssh_key() {
    log "Setting up SSH key..."
    
    if [ ! -f ~/.ssh/k8s-cluster ]; then
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/k8s-cluster -N "" -C "k8s-cluster-key"
        log "Generated new SSH key: ~/.ssh/k8s-cluster"
    fi
    
    # Add to SSH agent
    eval "$(ssh-agent -s)" >/dev/null 2>&1
    ssh-add ~/.ssh/k8s-cluster >/dev/null 2>&1
    
    log "SSH key setup completed ✅"
}

# Wait for SSH connectivity
wait_for_ssh() {
    local host=$1
    local max_attempts=30
    local attempt=1
    
    log "Waiting for SSH connectivity to $host..."
    
    while [ $attempt -le $max_attempts ]; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster ubuntu@$host "echo 'SSH ready'" >/dev/null 2>&1; then
            log "SSH to $host is ready ✅"
            return 0
        fi
        
        echo -n "."
        sleep 10
        ((attempt++))
    done
    
    error "Failed to establish SSH connection to $host after $max_attempts attempts"
}

# Main deployment function
main() {
    log "🚀 Starting fully automated Kubernetes cluster deployment..."
    
    # Check prerequisites
    check_prerequisites
    
    # Setup SSH key
    setup_ssh_key
    
    # Step 1: Deploy AWS infrastructure
    log "📦 Deploying AWS infrastructure..."
    cd infra/terraform/aws
    
    terraform init
    terraform apply -auto-approve
    
    # Get outputs
    BASTION_IP=$(terraform output -raw bastion_public_ip)
    CP1_IP=$(terraform output -json control_plane_private_ips | jq -r '.[0]')
    CP2_IP=$(terraform output -json control_plane_private_ips | jq -r '.[1]')
    CP3_IP=$(terraform output -json control_plane_private_ips | jq -r '.[2]')
    WORKER_IPS=($(terraform output -json worker_private_ips | jq -r '.[]'))
    
    log "✅ Infrastructure deployed:"
    log "   Bastion: $BASTION_IP"
    log "   Control Planes: $CP1_IP, $CP2_IP, $CP3_IP"
    log "   Workers: ${WORKER_IPS[*]}"
    
    cd ../../..
    
    # Step 2: Wait for instances to be ready
    log "⏳ Waiting for instances to be ready..."
    wait_for_ssh $BASTION_IP
    
    # Wait for private instances through bastion
    log "Checking private instance connectivity..."
    sleep 60
    
    # Step 3: Setup SSH key on bastion
    log "🔑 Setting up SSH access through bastion..."
    scp -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster ~/.ssh/k8s-cluster ubuntu@$BASTION_IP:~/.ssh/id_rsa
    scp -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster ~/.ssh/k8s-cluster.pub ubuntu@$BASTION_IP:~/.ssh/id_rsa.pub
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster ubuntu@$BASTION_IP "chmod 600 ~/.ssh/id_rsa"
    
    # Step 4: Initialize Kubernetes cluster
    log "🎯 Initializing Kubernetes cluster..."
    
    # Copy initialization script to first control plane
    scp -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster -o ProxyCommand="ssh -W %h:%p -i ~/.ssh/k8s-cluster ubuntu@$BASTION_IP" \
        infra/terraform/aws/user-data-k8s-init.sh ubuntu@$CP1_IP:~/init-k8s.sh
    
    # Run initialization
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster -o ProxyCommand="ssh -W %h:%p -i ~/.ssh/k8s-cluster ubuntu@$BASTION_IP" \
        ubuntu@$CP1_IP "chmod +x init-k8s.sh && ./init-k8s.sh"
    
    # Step 5: Get join commands
    log "📋 Getting join commands..."
    JOIN_COMMANDS=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster -o ProxyCommand="ssh -W %h:%p -i ~/.ssh/k8s-cluster ubuntu@$BASTION_IP" \
        ubuntu@$CP1_IP "sudo kubeadm token create --print-join-command")
    
    CERT_KEY=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster -o ProxyCommand="ssh -W %h:%p -i ~/.ssh/k8s-cluster ubuntu@$BASTION_IP" \
        ubuntu@$CP1_IP "sudo kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1")
    
    CP_JOIN_CMD="$JOIN_COMMANDS --control-plane --certificate-key $CERT_KEY"
    
    # Step 6: Join other control plane nodes
    log "🔗 Joining control plane nodes..."
    for CP_IP in $CP2_IP $CP3_IP; do
        log "   Joining $CP_IP..."
        ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster -o ProxyCommand="ssh -W %h:%p -i ~/.ssh/k8s-cluster ubuntu@$BASTION_IP" \
            ubuntu@$CP_IP "sudo $CP_JOIN_CMD" &
    done
    wait
    
    # Step 7: Join worker nodes
    log "👷 Joining worker nodes..."
    for WORKER_IP in "${WORKER_IPS[@]}"; do
        log "   Joining $WORKER_IP..."
        ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster -o ProxyCommand="ssh -W %h:%p -i ~/.ssh/k8s-cluster ubuntu@$BASTION_IP" \
            ubuntu@$WORKER_IP "sudo $JOIN_COMMANDS" &
    done
    wait
    
    # Step 8: Wait for cluster to be ready
    log "⏳ Waiting for cluster to be ready..."
    sleep 120
    
    # Step 9: Verify cluster
    log "✅ Verifying cluster..."
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster -o ProxyCommand="ssh -W %h:%p -i ~/.ssh/k8s-cluster ubuntu@$BASTION_IP" \
        ubuntu@$CP1_IP "kubectl get nodes && kubectl get pods -A && kubectl get svc -n production"
    
    # Step 10: Copy kubeconfig
    log "📋 Copying kubeconfig..."
    mkdir -p ~/.kube
    scp -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster -o ProxyCommand="ssh -W %h:%p -i ~/.ssh/k8s-cluster ubuntu@$BASTION_IP" \
        ubuntu@$CP1_IP:~/.kube/config ~/.kube/config-k8s-cluster
    
    log ""
    log "🎉 Kubernetes cluster deployment completed successfully!"
    log ""
    log "📊 Cluster Summary:"
    log "   • 3 Control Plane nodes across 3 AZs"
    log "   • 6 Worker nodes across 3 AZs"
    log "   • HA nginx application with auto-scaling"
    log "   • Calico CNI, Metrics Server, Ingress NGINX, Cert Manager"
    log ""
    log "🔗 Access:"
    log "   Bastion: ssh -i ~/.ssh/k8s-cluster ubuntu@$BASTION_IP"
    log "   Control Plane: ssh -i ~/.ssh/k8s-cluster -J ubuntu@$BASTION_IP ubuntu@$CP1_IP"
    log "   Kubeconfig: export KUBECONFIG=~/.kube/config-k8s-cluster"
    log ""
    log "🧹 To destroy: ./deploy-full-automation.sh destroy"
}

# Cleanup function
cleanup() {
    log "🧹 Cleaning up..."
    cd infra/terraform/aws
    terraform destroy -auto-approve
    log "Cleanup completed ✅"
}

# Handle script arguments
case "${1:-}" in
    "destroy")
        cleanup
        ;;
    *)
        main
        ;;
esac