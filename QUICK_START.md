# Quick Start Guide - 15 Minutes to Production K8s

This is a condensed version for experienced users who want to deploy quickly.

## Prerequisites Check
```bash
# Verify tools
aws --version && terraform --version && kubectl version --client
```

## 1. Clone and Configure (2 minutes)
```bash
git clone https://github.com/subrotosharma/production-multi-az-k8s-cluster.git
cd production-multi-az-k8s-cluster/infra/terraform/aws
cp terraform.tfvars.example terraform.tfvars
```

**Edit terraform.tfvars:**
```hcl
region = "us-east-1"
key_pair_name = "your-keypair"
my_ip_cidr = "$(curl -s ipinfo.io/ip)/32"
lb_internal = true
instance_type_master = "t3.medium"
instance_type_worker = "t3.medium"
```

## 2. Deploy Infrastructure (5 minutes)
```bash
terraform init && terraform apply -auto-approve
```

## 3. Initialize Cluster (3 minutes)
```bash
# Get bastion IP
BASTION_IP=$(terraform output -raw bastion_public_ip)
CP1_IP=$(terraform output -json control_plane_private_ips | jq -r '.[0]')

# SSH to bastion then control plane
ssh -A -i ~/.ssh/your-key.pem ubuntu@$BASTION_IP
ssh ubuntu@$CP1_IP

# Initialize cluster
sudo cp /etc/kubeadm/kubeadm-config-aws.yaml /etc/kubeadm/kubeadm-config-local.yaml
sudo sed -i "s/api.k8s.yourdomain.com/$CP1_IP/" /etc/kubeadm/kubeadm-config-local.yaml
sudo kubeadm init --config /etc/kubeadm/kubeadm-config-local.yaml --upload-certs
```

## 4. Configure kubectl (1 minute)
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## 5. Install Components (2 minutes)
```bash
# Install all essential components
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.24"
```

## 6. Join Nodes (2 minutes)
```bash
# Use join commands from step 3 output
# For control planes: add --control-plane --certificate-key <key>
# For workers: use basic join command

# Quick script for workers:
WORKERS=($(terraform output -json worker_private_ips | jq -r '.[]'))
JOIN_CMD="sudo kubeadm join $CP1_IP:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>"

for worker in "${WORKERS[@]}"; do
    ssh ubuntu@$worker "$JOIN_CMD" &
done
wait
```

## 7. Verify (1 minute)
```bash
kubectl get nodes
kubectl get pods -A
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
```

## Done! 🎉
Your production HA Kubernetes cluster is ready in ~15 minutes.

**Access from local machine:**
```bash
scp -i ~/.ssh/your-key.pem ubuntu@$BASTION_IP:~/.kube/config ~/.kube/config-prod
export KUBECONFIG=~/.kube/config-prod
kubectl get nodes
```