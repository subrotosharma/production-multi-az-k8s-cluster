# Infrastructure Documentation

Complete guide to the AWS infrastructure components and Terraform configuration.

## 🏗️ Infrastructure Overview

### Network Architecture
- **VPC**: Custom VPC with CIDR 10.0.0.0/16
- **Public Subnets**: 3 subnets for bastion and NLB
- **Private Subnets**: 3 subnets for K8s nodes
- **NAT Gateways**: 3 NAT gateways for private subnet outbound access

### Compute Resources
- **Bastion Host**: 1 t3.micro in public subnet
- **Control Plane**: 3 t3.medium instances in private subnets
- **Worker Nodes**: 6 t3.medium instances in private subnets

### Load Balancing
- **Network Load Balancer**: Internal NLB for Kubernetes API server

## 📁 Terraform Structure

```
infra/terraform/aws/
├── providers.tf          # AWS provider configuration
├── variables.tf         # Input variables
├── vpc.tf              # VPC, subnets, gateways
├── security_groups.tf  # Security group rules
├── iam.tf              # IAM roles and policies
├── ec2_masters.tf      # Control plane instances
├── ec2_workers.tf      # Worker node instances
├── bastion.tf          # Bastion host
├── nlb_api.tf          # Network Load Balancer
└── outputs.tf          # Output values
```

## 🔧 Configuration

### Required Variables
```hcl
region = "us-east-1"
cluster_name = "production-k8s"
key_pair_name = "your-keypair"
my_ip_cidr = "YOUR_IP/32"
```

## 🚀 Deployment

```bash
cd infra/terraform/aws
terraform init
terraform apply -auto-approve
```