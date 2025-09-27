# Production Multi-AZ Kubernetes Cluster - Complete Deployment Guide

This guide provides step-by-step instructions to deploy a production-ready, highly available Kubernetes cluster across multiple AWS availability zones.

## 📋 Prerequisites

### Required Tools
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip && sudo mv terraform /usr/local/bin/

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### AWS Requirements
- AWS Account with administrative access
- AWS CLI configured with credentials
- EC2 Key Pair created in your target region
- Route53 Hosted Zone (optional, for custom domain)

### Configure AWS CLI
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
# Enter output format: json
```

## 🚀 Step-by-Step Deployment

### Step 1: Clone the Repository
```bash
git clone https://github.com/subrotosharma/production-multi-az-k8s-cluster.git
cd production-multi-az-k8s-cluster
```

### Step 2: Configure Infrastructure Variables
```bash
cd infra/terraform/aws
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values:
```hcl
region              = "us-east-1"                    # Your AWS region
cluster_name        = "production-k8s"               # Your cluster name
key_pair_name       = "your-ec2-keypair"            # Your EC2 key pair name
create_route53      = false                          # Set to true if you have Route53
hosted_zone_id      = ""                            # Your Route53 zone ID (if using)
api_fqdn            = "api.k8s.yourdomain.com"      # Your API endpoint (if using Route53)
apps_wildcard_fqdn  = "*.apps.yourdomain.com"       # Your apps wildcard domain
my_ip_cidr          = "YOUR_PUBLIC_IP/32"           # Your public IP for SSH access
lb_internal         = true                           # Keep as true for private subnets
instance_type_master = "t3.medium"                   # Control plane instance type
instance_type_worker = "t3.medium"                   # Worker node instance type
```

**Important**: Replace `YOUR_PUBLIC_IP` with your actual public IP:
```bash
curl -s https://ipinfo.io/ip
```

### Step 3: Deploy AWS Infrastructure
```bash
# Initialize Terraform
terraform init

# Plan the deployment (optional but recommended)
terraform plan

# Deploy infrastructure
terraform apply -auto-approve
```

**Expected Output**: Terraform will create:
- VPC with 3 public and 3 private subnets across 3 AZs
- 1 Bastion host in public subnet
- 3 Control plane nodes in private subnets
- 6 Worker nodes in private subnets
- Network Load Balancer for API server
- Security groups and IAM roles
- Route53 records (if enabled)

### Step 4: Get Infrastructure Details
```bash
# Get all outputs
terraform output

# Note down these important IPs:
# - bastion_public_ip
# - control_plane_private_ips
# - worker_private_ips
```

### Step 5: Set Up SSH Access
```bash
# Copy your SSH key to bastion (replace with your key path and bastion IP)
scp -i ~/.ssh/your-key.pem ~/.ssh/your-key.pem ubuntu@<BASTION_PUBLIC_IP>:~/.ssh/

# SSH to bastion with agent forwarding
ssh -A -i ~/.ssh/your-key.pem ubuntu@<BASTION_PUBLIC_IP>
```

### Step 6: Initialize First Control Plane Node
From the bastion host:
```bash
# SSH to first control plane node
ssh ubuntu@<CONTROL_PLANE_1_IP>

# Check if kubeadm config exists
ls -la /etc/kubeadm/

# Initialize cluster with local IP (to avoid DNS issues)
sudo cp /etc/kubeadm/kubeadm-config-aws.yaml /etc/kubeadm/kubeadm-config-local.yaml
sudo sed -i 's/api.k8s.yourdomain.com/<CONTROL_PLANE_1_IP>/' /etc/kubeadm/kubeadm-config-local.yaml

# Initialize the cluster
sudo kubeadm init --config /etc/kubeadm/kubeadm-config-local.yaml --upload-certs
```

**Save the output!** You'll need the join commands for other nodes.

### Step 7: Configure kubectl
On the first control plane node:
```bash
# Set up kubectl for ubuntu user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Test kubectl
kubectl get nodes
```

### Step 8: Install Essential Components
```bash
# Install Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Install EBS CSI driver
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.24"

# Create gp3 storage class
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

# Install ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/aws/deploy.yaml

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
```

### Step 9: Join Additional Control Plane Nodes
From bastion, SSH to each remaining control plane node and run the join command from Step 6 output:
```bash
# SSH to control plane node 2
ssh ubuntu@<CONTROL_PLANE_2_IP>
sudo kubeadm join <CONTROL_PLANE_1_IP>:6443 --token <TOKEN> \
    --discovery-token-ca-cert-hash sha256:<HASH> \
    --control-plane --certificate-key <CERT_KEY>

# SSH to control plane node 3
ssh ubuntu@<CONTROL_PLANE_3_IP>
sudo kubeadm join <CONTROL_PLANE_1_IP>:6443 --token <TOKEN> \
    --discovery-token-ca-cert-hash sha256:<HASH> \
    --control-plane --certificate-key <CERT_KEY>
```

### Step 10: Join Worker Nodes
From bastion, SSH to each worker node and run the worker join command:
```bash
# For each worker node:
ssh ubuntu@<WORKER_NODE_IP>
sudo kubeadm join <CONTROL_PLANE_1_IP>:6443 --token <TOKEN> \
    --discovery-token-ca-cert-hash sha256:<HASH>
```

**Automated approach**: Create a script to join all workers:
```bash
# On bastion, create join script
cat > join-workers.sh << 'EOF'
#!/bin/bash
WORKERS=("10.0.10.48" "10.0.10.192" "10.0.11.79" "10.0.11.219" "10.0.12.14" "10.0.12.174")
JOIN_CMD="sudo kubeadm join <CONTROL_PLANE_1_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>"

for worker in "${WORKERS[@]}"; do
    echo "Joining worker: $worker"
    ssh ubuntu@$worker "$JOIN_CMD" &
done
wait
EOF

chmod +x join-workers.sh
./join-workers.sh
```

### Step 11: Verify Cluster
Back on the first control plane node:
```bash
# Check all nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -A

# Check services
kubectl get svc -A

# Test with a sample deployment
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get svc nginx
```

### Step 12: Test Cluster Functionality
```bash
# Test pod scheduling
kubectl run test-pod --image=busybox --command -- sleep 3600
kubectl get pods -o wide

# Test storage
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: gp3
EOF

kubectl get pvc

# Test ingress (optional)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: test.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF
```

## 🔧 Post-Deployment Configuration

### Configure kubectl on Your Local Machine
```bash
# Copy kubeconfig from control plane to your local machine
scp -i ~/.ssh/your-key.pem ubuntu@<BASTION_IP>:~/.kube/config ~/.kube/config-production

# Set KUBECONFIG
export KUBECONFIG=~/.kube/config-production

# Test connection
kubectl get nodes
```

### Install Additional Components (Optional)
```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install monitoring stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
    -n monitoring --create-namespace

# Install logging stack
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack -n logging --create-namespace
```

## 🛡️ Security Hardening

### Enable Pod Security Standards
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
EOF
```

### Configure Network Policies
```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
```

## 📊 Monitoring and Maintenance

### Regular Health Checks
```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A
kubectl top nodes
kubectl top pods -A

# Check certificates expiry
sudo kubeadm certs check-expiration

# Check etcd health
kubectl get pods -n kube-system | grep etcd
```

### Backup Procedures
```bash
# Backup etcd
sudo ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key

# Backup important configs
sudo cp -r /etc/kubernetes /backup/kubernetes-configs
```

## 🚨 Troubleshooting

### Common Issues and Solutions

**Issue**: Pods stuck in Pending state
```bash
# Check node resources
kubectl describe nodes
kubectl get events --sort-by=.metadata.creationTimestamp
```

**Issue**: LoadBalancer services stuck in Pending
```bash
# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer
# Install if missing:
# kubectl apply -k "github.com/aws/aws-load-balancer-controller/deploy/kubernetes/overlays/stable/?ref=v2.6.0"
```

**Issue**: DNS resolution problems
```bash
# Check CoreDNS
kubectl get pods -n kube-system | grep coredns
kubectl logs -n kube-system deployment/coredns
```

**Issue**: Certificate errors
```bash
# Regenerate certificates
sudo kubeadm certs renew all
sudo systemctl restart kubelet
```

## 🧹 Cleanup

To destroy the entire infrastructure:
```bash
cd infra/terraform/aws
terraform destroy -auto-approve
```

## 📞 Support

- **Issues**: Create an issue in the GitHub repository
- **Documentation**: Check the `/docs` directory
- **Community**: Join Kubernetes Slack channels

---

**🎉 Congratulations!** You now have a production-ready, highly available Kubernetes cluster running across multiple AWS availability zones.

**Next Steps**:
1. Deploy your applications
2. Set up CI/CD pipelines
3. Configure monitoring and alerting
4. Implement backup strategies
5. Plan for scaling and updates