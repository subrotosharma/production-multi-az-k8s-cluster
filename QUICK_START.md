# Quick Start Guide

I get it - you want to see this thing work without reading a novel. Here's the fastest path to a running cluster.

## Before You Start

Make sure you have:
- AWS account with admin access (sorry, you need the permissions)
- These tools installed: `terraform`, `aws-cli`, `jq`
- About 15 minutes and a cup of coffee

## The 5-Minute Setup

### 1. Get the code
```bash
git clone https://github.com/subrotosharma/production-multi-az-k8s-cluster.git
cd production-multi-az-k8s-cluster
```

### 2. Configure AWS
```bash
aws configure
# Enter your keys, set region to us-east-1, output to json
```

### 3. Deploy everything
```bash
./deploy-full-automation.sh
```

Seriously, that's it. The script handles:
- SSH key generation
- Infrastructure deployment
- Kubernetes cluster setup
- All the monitoring and security stuff

## What Happens Next

The script will:
1. **Check prerequisites** (takes 30 seconds)
2. **Deploy AWS infrastructure** (5-7 minutes)
3. **Initialize Kubernetes** (3-4 minutes)  
4. **Install components** (2-3 minutes)
5. **Deploy sample app** (1 minute)

Total time: **12-15 minutes** depending on AWS response times.

## Verify It Works

When it's done, you'll see output like:
```
🎉 Kubernetes cluster deployment completed successfully!

📊 Cluster Summary:
   • 3 Control Plane nodes across 3 AZs
   • 6 Worker nodes across 3 AZs
   • HA nginx application with auto-scaling

🔗 Access:
   Bastion: ssh -i ~/.ssh/k8s-cluster ubuntu@54.91.202.121
   Kubeconfig: export KUBECONFIG=~/.kube/config-k8s-cluster
```

Test it:
```bash
# Use the cluster locally
export KUBECONFIG=~/.kube/config-k8s-cluster
kubectl get nodes

# Should show 9 nodes (3 masters + 6 workers)
```

## Access Your Stuff

### Grafana Dashboards
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80
# Open http://localhost:3000
# Login: admin / prom-operator
```

### Sample Application
```bash
kubectl get svc -n production
# Note the NodePort, then access via any node IP
```

### SSH to Cluster
```bash
# The script shows you the exact command, something like:
ssh -i ~/.ssh/k8s-cluster ubuntu@<BASTION_IP>
```

## If Something Breaks

Check the [troubleshooting guide](TROUBLESHOOTING.md). Most issues are:
- AWS permissions (need admin access)
- Wrong region (script assumes us-east-1)
- Service limits (you need quota for 10+ instances)

## Clean Up

When you're done playing:
```bash
./deploy-full-automation.sh destroy
```

This nukes everything and stops the AWS charges.

## What's Actually Running

You get a real production setup:
- **High availability**: Everything spread across 3 AZs
- **Monitoring**: Prometheus + Grafana with useful dashboards
- **Security**: Runtime protection and policy enforcement
- **Auto-scaling**: HPA configured for the sample app
- **Storage**: EBS CSI driver with gp3 storage class

## Cost Warning

This runs about **$8-12 per day** in AWS costs (9 t3.xlarge instances). Don't forget to destroy it when you're done experimenting.

## Next Steps

Once you've verified everything works:
1. Read the [deployment guide](DEPLOYMENT_GUIDE.md) to understand what happened
2. Check out the [monitoring docs](docs/MONITORING.md) to explore Grafana
3. Look at the [security setup](docs/SECURITY.md) to see what's protecting you
4. Deploy your own applications using the sample as a template

---

**Pro tip**: The automation script is idempotent. If something fails halfway through, just run it again.