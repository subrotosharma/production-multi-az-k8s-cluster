# Production Multi-AZ Kubernetes Cluster

After struggling with manual Kubernetes deployments for months, I decided to build a fully automated solution. This project deploys a production-ready, highly available Kubernetes cluster across multiple AWS availability zones with zero manual intervention.

## Why I Built This

I was tired of spending hours setting up Kubernetes clusters manually, dealing with:
- Complex multi-master setups
- Networking configuration headaches  
- Security hardening tasks
- Monitoring stack installations
- Manual node joining processes

So I automated everything. Now you can get a complete production cluster in 15 minutes.

## What You Get

```bash
# Seriously, this is all you need to run:
./deploy-full-automation.sh
```

This single command gives you:
- **3 control plane nodes** spread across 3 availability zones
- **6 worker nodes** (2 per AZ) for your workloads
- **Complete networking** with Calico CNI and ingress controller
- **Monitoring stack** with Prometheus, Grafana, and Loki
- **Security hardening** with Falco runtime protection and OPA policies
- **Sample HA application** to verify everything works

## Quick Start

I've tested this on macOS and Linux. Windows users should use WSL2.

### Prerequisites
```bash
# Install the tools (if you don't have them)
brew install terraform awscli jq  # macOS
# or
sudo apt install terraform awscli jq  # Ubuntu

# Configure AWS (you need admin access)
aws configure
```

### Deploy Everything
```bash
git clone https://github.com/subrotosharma/production-multi-az-k8s-cluster.git
cd production-multi-az-k8s-cluster
./deploy-full-automation.sh
```

That's it. Go grab coffee while it builds your cluster.

## Architecture

I designed this with production workloads in mind:

**Infrastructure:**
- VPC with public/private subnets across 3 AZs
- Bastion host for secure access
- Network Load Balancer for API server HA
- EBS gp3 storage with 80GB per instance

**Kubernetes:**
- kubeadm-based cluster (no managed services)
- Calico for pod networking
- ingress-nginx for external access
- cert-manager for TLS certificates
- Horizontal Pod Autoscaler configured

**Monitoring:**
- Prometheus for metrics collection
- Grafana with pre-built dashboards
- Loki for centralized logging
- AlertManager for notifications

**Security:**
- Falco for runtime threat detection
- OPA Gatekeeper for policy enforcement
- Network policies with default deny
- Pod Security Standards enforced

## Documentation

- **[Quick Start Guide](QUICK_START.md)** - 15-minute deployment
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Common issues I've encountered

That's it. Everything else is automated.

## Project Structure

```
├── infra/terraform/aws/     # All the AWS infrastructure code
├── apps/sample-ha-app/      # Example HA application
├── monitoring/              # Prometheus, Grafana configs
├── security/               # Falco, Gatekeeper policies
└── deploy-full-automation.sh  # The magic script
```

## Access Your Cluster

After deployment completes:

```bash
# SSH to your cluster (IP will be shown in output)
ssh -i ~/.ssh/k8s-cluster ubuntu@<BASTION_IP>

# Use kubectl locally
export KUBECONFIG=~/.kube/config-k8s-cluster
kubectl get nodes

# Access Grafana dashboards
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80
# Open http://localhost:3000
# Username: admin
# Password: kubectl get secret grafana-admin-secret -n monitoring -o jsonpath='{.data.password}' | base64 -d
```

## Costs

Running this cluster costs approximately:
- **$200-300/month** for the infrastructure (9 t3.xlarge instances)
- **$50-100/month** for EBS storage and data transfer
- **$0** for the Kubernetes software (all open source)

You can reduce costs by using smaller instance types in `terraform.tfvars`.

## Cleanup

When you're done experimenting:
```bash
./deploy-full-automation.sh destroy
```

This removes everything and stops the billing.

## Contributing

Found a bug? Have an improvement? I welcome contributions:

1. Fork the repo
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

## My Experience

Building this took me about 3 months of evenings and weekends. The trickiest parts were:
- Getting the multi-master setup stable
- Automating the node joining process
- Configuring monitoring without breaking things
- Making the security policies actually useful

I've deployed this setup for several production workloads and it's been rock solid.

## Support

If you run into issues:
- Check the [troubleshooting guide](TROUBLESHOOTING.md) first
- Open an issue with logs and error details
- Join the discussion in issues

## License

MIT License - use this however you want. If it saves you time, that makes me happy.

---

**Built by a developer, for developers who hate manual infrastructure setup.**

Stop clicking through AWS consoles. Start deploying with code.