# Quick Start - One Command Deployment

Deploy a production-ready HA Kubernetes cluster in minutes.

## Prerequisites

```bash
# Install required tools
brew install terraform awscli jq  # macOS
# or
sudo apt install terraform awscli jq  # Ubuntu

# Configure AWS
aws configure
```

## One-Command Deployment

```bash
# Clone repository
git clone https://github.com/subrotosharma/production-multi-az-k8s-cluster.git
cd production-multi-az-k8s-cluster

# Deploy everything
./deploy-full-automation.sh
```

## What Gets Deployed

- ✅ **AWS Infrastructure**: VPC, subnets, instances, load balancers
- ✅ **Kubernetes Cluster**: 3 control planes + 6 workers across 3 AZs
- ✅ **Essential Components**: Calico CNI, Metrics Server, Ingress NGINX, Cert Manager
- ✅ **Sample HA App**: Auto-scaling nginx with 3-10 replicas
- ✅ **SSH Access**: Automatic key generation and setup

## Access Your Cluster

```bash
# SSH to bastion
ssh -i ~/.ssh/k8s-cluster ubuntu@<BASTION_IP>

# Use kubectl locally
export KUBECONFIG=~/.kube/config-k8s-cluster
kubectl get nodes

# Test the application
kubectl get svc -n production
```

## Cleanup

```bash
./deploy-full-automation.sh destroy
```

**Total deployment time: ~15 minutes** ⚡️