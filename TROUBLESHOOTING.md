# Troubleshooting Guide

Common issues and their solutions when deploying the production Kubernetes cluster.

## 🚨 Infrastructure Issues

### Terraform Errors

**Error**: `InvalidKeyPair.NotFound`
```bash
# Solution: Create EC2 key pair first
aws ec2 create-key-pair --key-name your-keypair --query 'KeyMaterial' --output text > ~/.ssh/your-keypair.pem
chmod 400 ~/.ssh/your-keypair.pem
```

**Error**: `UnauthorizedOperation`
```bash
# Solution: Check AWS credentials and permissions
aws sts get-caller-identity
aws iam get-user
```

**Error**: `LimitExceeded` for EC2 instances
```bash
# Solution: Request limit increase or use smaller instances
# Check current limits:
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A
```

### SSH Connection Issues

**Error**: `Permission denied (publickey)`
```bash
# Solution 1: Check key permissions
chmod 400 ~/.ssh/your-key.pem

# Solution 2: Use correct username
ssh -i ~/.ssh/your-key.pem ubuntu@<IP>  # Not ec2-user

# Solution 3: Check security group allows SSH from your IP
aws ec2 describe-security-groups --group-ids <SG_ID>
```

**Error**: `Connection timeout`
```bash
# Solution: Check your public IP and security group
curl -s ipinfo.io/ip
# Update terraform.tfvars with correct my_ip_cidr
```

## 🔧 Kubernetes Issues

### kubeadm init Failures

**Error**: `[ERROR Mem]: the system RAM (914 MB) is less than the minimum 1700 MB`
```bash
# Solution: Use larger instance types
# In terraform.tfvars:
instance_type_master = "t3.medium"  # Instead of t3.small
```

**Error**: `context deadline exceeded` during API server wait
```bash
# Solution 1: Use local IP instead of DNS
sudo sed -i 's/api.k8s.yourdomain.com/10.0.10.9/' /etc/kubeadm/kubeadm-config-aws.yaml

# Solution 2: Check if NLB is internal
# In terraform.tfvars:
lb_internal = true
```

**Error**: `couldn't validate the identity of the API Server`
```bash
# Solution: Reset and retry with correct config
sudo kubeadm reset -f
sudo kubeadm init --config /etc/kubeadm/kubeadm-config-local.yaml --upload-certs
```

### Node Join Issues

**Error**: `token has expired`
```bash
# Solution: Generate new token
kubeadm token create --print-join-command
```

**Error**: `certificate key has expired`
```bash
# Solution: Upload new certificates
kubeadm init phase upload-certs --upload-certs
```

**Error**: `connection refused` when joining
```bash
# Solution: Check if control plane is ready
kubectl get nodes
kubectl get pods -n kube-system
```

### Pod Issues

**Error**: Pods stuck in `Pending` state
```bash
# Diagnosis:
kubectl describe pod <POD_NAME>
kubectl get events --sort-by=.metadata.creationTimestamp

# Common solutions:
# 1. No worker nodes
kubectl get nodes

# 2. Resource constraints
kubectl top nodes
kubectl describe nodes

# 3. Taints on nodes
kubectl describe nodes | grep -i taint
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

**Error**: Pods in `ImagePullBackOff`
```bash
# Diagnosis:
kubectl describe pod <POD_NAME>

# Solutions:
# 1. Check image name and tag
# 2. Check if image exists in registry
# 3. Check pull secrets if using private registry
```

**Error**: `CrashLoopBackOff`
```bash
# Diagnosis:
kubectl logs <POD_NAME> --previous
kubectl describe pod <POD_NAME>

# Common causes:
# 1. Application configuration errors
# 2. Missing environment variables
# 3. Resource limits too low
```

### Networking Issues

**Error**: Pods can't communicate
```bash
# Check CNI installation
kubectl get pods -n kube-system | grep calico
kubectl get nodes -o wide

# Reinstall Calico if needed
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
```

**Error**: DNS resolution not working
```bash
# Check CoreDNS
kubectl get pods -n kube-system | grep coredns
kubectl logs -n kube-system deployment/coredns

# Test DNS
kubectl run test-dns --image=busybox --rm -it -- nslookup kubernetes.default
```

**Error**: LoadBalancer services stuck in `Pending`
```bash
# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Install if missing
kubectl apply -k "github.com/aws/aws-load-balancer-controller/deploy/kubernetes/overlays/stable/?ref=v2.6.0"

# Check IAM permissions for nodes
aws sts get-caller-identity
```

### Storage Issues

**Error**: PVCs stuck in `Pending`
```bash
# Check EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi

# Check storage class
kubectl get storageclass

# Check node IAM permissions for EBS
aws ec2 describe-volumes --region us-east-1
```

**Error**: `failed to provision volume`
```bash
# Check EBS CSI controller logs
kubectl logs -n kube-system deployment/ebs-csi-controller

# Common issues:
# 1. IAM permissions missing
# 2. Availability zone mismatch
# 3. Volume type not supported
```

## 🔍 Diagnostic Commands

### Cluster Health Check
```bash
# Overall cluster status
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A

# Component status
kubectl get componentstatuses
kubectl get events --sort-by=.metadata.creationTimestamp

# Resource usage
kubectl top nodes
kubectl top pods -A
```

### Node Diagnostics
```bash
# Node details
kubectl describe nodes
kubectl get nodes --show-labels

# Node conditions
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,REASON:.status.conditions[-1].reason

# Kubelet logs
sudo journalctl -u kubelet -f
```

### Network Diagnostics
```bash
# CNI status
kubectl get pods -n kube-system -l k8s-app=calico-node
kubectl exec -n kube-system <calico-pod> -- calicoctl node status

# Service endpoints
kubectl get endpoints
kubectl get services -A

# Network policies
kubectl get networkpolicies -A
```

### Storage Diagnostics
```bash
# Storage classes
kubectl get storageclass
kubectl describe storageclass gp3

# Persistent volumes
kubectl get pv
kubectl get pvc -A

# CSI driver status
kubectl get pods -n kube-system | grep csi
kubectl get csinodes
```

## 🛠️ Recovery Procedures

### Reset Single Node
```bash
# On the problematic node
sudo kubeadm reset -f
sudo systemctl restart kubelet
sudo systemctl restart containerd

# Rejoin the node
kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
```

### Reset Entire Cluster
```bash
# On all nodes
sudo kubeadm reset -f

# On first control plane
sudo kubeadm init --config /etc/kubeadm/kubeadm-config-local.yaml --upload-certs

# Rejoin all other nodes
```

### Backup and Restore etcd
```bash
# Backup
sudo ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key

# Restore
sudo ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-snapshot.db \
    --data-dir=/var/lib/etcd-restore
```

## 📞 Getting Help

### Log Collection
```bash
# Collect all relevant logs
mkdir -p /tmp/k8s-logs
kubectl logs -n kube-system deployment/coredns > /tmp/k8s-logs/coredns.log
kubectl get events -A > /tmp/k8s-logs/events.log
kubectl describe nodes > /tmp/k8s-logs/nodes.log
sudo journalctl -u kubelet > /tmp/k8s-logs/kubelet.log
```

### Useful Resources
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- [kubeadm Troubleshooting](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Calico Troubleshooting](https://docs.projectcalico.org/maintenance/troubleshoot/)

### Community Support
- Kubernetes Slack: #kubeadm, #sig-cluster-lifecycle
- AWS Forums: AWS Container Services
- Stack Overflow: kubernetes, amazon-eks tags