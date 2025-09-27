# Production Multi-AZ Kubernetes Cluster

Production-ready Kubernetes cluster deployed across multiple AWS availability zones using Terraform and kubeadm. Features 3 control plane nodes, 6 worker nodes, Calico CNI, EBS CSI storage, ingress-nginx, cert-manager, and comprehensive monitoring stack.

## 📚 Documentation

- **[Complete Deployment Guide](DEPLOYMENT_GUIDE.md)** - Step-by-step instructions for full deployment
- **[Quick Start Guide](QUICK_START.md)** - 15-minute deployment for experienced users
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Common issues and solutions

## 🏗️ Architecture

- **High Availability**: 3 control plane nodes across 3 AZs
- **Scalable**: 6 worker nodes with auto-scaling capability  
- **Production-Ready**: Complete with monitoring, logging, and security
- **Infrastructure as Code**: Fully automated with Terraform
- **Multi-AZ Deployment**: Fault-tolerant across availability zones
- **Enterprise Security**: Pod security standards, network policies, cert-manager
- **Storage**: EBS CSI driver with gp3 storage class
- **Networking**: Calico CNI with ingress-nginx controller

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured
- Terraform installed
- kubectl installed
- SSH key pair in AWS

### 1. Deploy Infrastructure
```bash
cd infra/terraform/aws
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init && terraform apply -auto-approve
```

### 2. Initialize Control Plane
```bash
# SSH to first control plane node
ssh ubuntu@<cp1-ip>
sudo kubeadm init --config /etc/kubeadm/kubeadm-config-aws.yaml --upload-certs
```

### 3. Install Components
```bash
# Set up kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install CNI and components
./install-components.sh
```

### 4. Join Nodes
Use the join commands from kubeadm init output to add control plane and worker nodes.

## 📁 Project Structure

```
├── infra/
│   └── terraform/aws/          # AWS infrastructure
├── k8s/
│   ├── addons/                 # Kubernetes addons
│   ├── aws/                    # AWS-specific manifests
│   ├── cni/                    # Container Network Interface
│   ├── ingress-nginx/          # Ingress controller
│   ├── logging/                # Logging stack
│   ├── monitoring/             # Monitoring stack
│   └── storage/                # Storage classes
├── apps/                       # Sample applications
└── scripts/                    # Deployment scripts
```

## 🔧 Components Included

- **Container Runtime**: containerd
- **CNI**: Calico
- **Storage**: AWS EBS CSI Driver (gp3)
- **Ingress**: ingress-nginx
- **Certificates**: cert-manager
- **Security**: Kyverno policies
- **Monitoring**: metrics-server
- **Logging**: Loki stack (optional)

## 🛡️ Security Features

- Pod Security Standards enforced
- Network policies with Calico
- RBAC configured
- Kyverno policy engine
- TLS certificates via cert-manager
- Private subnets for worker nodes

## 📊 Monitoring & Observability

- Metrics server for resource monitoring
- Loki stack for centralized logging
- Grafana dashboards (optional)
- Prometheus monitoring (optional)

## 🔄 CI/CD Ready

- GitHub Actions workflows included
- Container image scanning
- Security policy validation
- Automated deployments

## 📝 Configuration

Key configuration files:
- `infra/terraform/aws/terraform.tfvars` - Infrastructure settings
- `k8s/addons/cert-manager/` - Certificate management
- `k8s/addons/kyverno/` - Security policies
- `apps/sample-ha-app/` - Sample HA application

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🆘 Support

For issues and questions:
- Create an issue in this repository
- Check the troubleshooting guide in docs/
- Review AWS and Kubernetes documentation

---

**Built with ❤️ for production workloads**