# Production Multi-AZ Kubernetes Cluster

Production-ready Kubernetes cluster deployed across multiple AWS availability zones using Terraform and kubeadm. Features 3 control plane nodes, 6 worker nodes, Calico CNI, EBS CSI storage, ingress-nginx, cert-manager, and comprehensive monitoring stack.

## 🚀 One-Command Deployment

```bash
# Clone the repository
git clone https://github.com/subrotosharma/production-multi-az-k8s-cluster.git
cd production-multi-az-k8s-cluster

# Configure your AWS credentials
aws configure

# Deploy everything automatically
./deploy-full-automation.sh
```

**That's it!** The script will:
1. Deploy AWS infrastructure (VPC, subnets, instances, load balancers)
2. Initialize the first control plane node
3. Install Calico CNI, Helm, and essential components
4. Join remaining control plane and worker nodes
5. Deploy a sample HA application
6. Verify the entire cluster

## 📚 Documentation

- **[Complete Deployment Guide](DEPLOYMENT_GUIDE.md)** - Step-by-step instructions for full deployment
- **[Quick Start Guide](QUICK_START.md)** - 15-minute deployment for experienced users
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Common issues and solutions

### Component Documentation
- **[Infrastructure Guide](docs/INFRASTRUCTURE.md)** - AWS infrastructure and Terraform details
- **[Kubernetes Guide](docs/KUBERNETES.md)** - K8s components and configurations
- **[Sample Application](docs/SAMPLE_APP.md)** - HA application deployment patterns
- **[CI/CD Pipeline](docs/CI_CD.md)** - Automated deployment and testing

## 🏗️ Architecture

- **High Availability**: 3 control plane nodes across 3 AZs
- **Scalable**: 6 worker nodes with auto-scaling capability  
- **Production-Ready**: Complete with monitoring, logging, and security
- **Infrastructure as Code**: Fully automated with Terraform
- **Multi-AZ Deployment**: Fault-tolerant across availability zones
- **Enterprise Security**: Pod security standards, network policies, cert-manager
- **Storage**: EBS CSI driver with gp3 storage class
- **Networking**: Calico CNI with ingress-nginx controller

## ⚡ Quick Commands

```bash
# Deploy cluster
./deploy-full-automation.sh

# Access cluster
ssh ubuntu@$(cd infra/terraform/aws && terraform output -raw bastion_public_ip)
ssh ubuntu@$(cd infra/terraform/aws && terraform output -json control_plane_private_ips | jq -r '.[0]')

# Check cluster
kubectl get nodes
kubectl get pods -A
kubectl get svc -n production

# Destroy cluster
cd infra/terraform/aws && terraform destroy -auto-approve
```

## 📁 Project Structure

```
├── infra/
│   └── terraform/aws/          # AWS infrastructure + automation
├── apps/
│   └── sample-ha-app/          # Sample HA application (Helm chart)
├── docs/                       # Complete documentation
└── deploy-full-automation.sh   # One-command deployment
```

## 🔧 Components Included

- **Container Runtime**: containerd
- **CNI**: Calico
- **Storage**: AWS EBS CSI Driver (gp3)
- **Ingress**: ingress-nginx
- **Certificates**: cert-manager
- **Security**: Kyverno policies
- **Monitoring**: metrics-server
- **Auto-scaling**: HPA configured

## 🛡️ Security Features

- Pod Security Standards enforced
- Network policies with Calico
- RBAC configured
- Kyverno policy engine
- TLS certificates via cert-manager
- Private subnets for worker nodes

## 📊 Monitoring & Observability

- Metrics server for resource monitoring
- HPA for auto-scaling
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
- `deploy-full-automation.sh` - One-command deployment
- `infra/terraform/aws/user-data-k8s-init.sh` - Automated cluster initialization

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

**No more manual commands - just run `./deploy-full-automation.sh` and get a production-ready cluster!** 🚀