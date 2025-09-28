# Troubleshooting Guide

I've broken this cluster setup in every way imaginable while building it. Here are the issues you're most likely to hit and how to fix them.

## Before You Start Debugging

**Check the basics first:**
- Are you in the right AWS region? (Script assumes us-east-1)
- Do you have admin AWS permissions?
- Is your IP address correct in terraform.tfvars?
- Did you wait long enough? Some operations take 5-10 minutes.

## Infrastructure Problems

### Terraform Fails to Apply

**"InvalidKeyPair.NotFound"**
```bash
# You need to create an EC2 key pair first
aws ec2 create-key-pair --key-name my-keypair --query 'KeyMaterial' --output text > ~/.ssh/my-keypair.pem
chmod 400 ~/.ssh/my-keypair.pem

# Update terraform.tfvars
key_pair_name = "my-keypair"
```

**"UnauthorizedOperation"**
Your AWS user doesn't have enough permissions. You need admin access for this to work. I know it's broad, but Kubernetes infrastructure touches everything.

```bash
# Check what user you're using
aws sts get-caller-identity

# Make sure this user has admin permissions in IAM console
```

**"LimitExceeded" for EC2 instances**
You've hit AWS service limits. This setup needs 10 instances (1 bastion + 3 masters + 6 workers).

```bash
# Check your limits
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A

# Request an increase, or use fewer/smaller instances temporarily
```

**"InsufficientInstanceCapacity"**
AWS doesn't have enough t3.xlarge instances in that AZ. Try a different region or instance type.

```bash
# In terraform.tfvars, try:
instance_type_master = "t3.large"
instance_type_worker = "t3.large"
```

### SSH Connection Issues

**"Permission denied (publickey)"**
```bash
# Check key permissions
chmod 400 ~/.ssh/your-key.pem

# Make sure you're using 'ubuntu' as the username
ssh -i ~/.ssh/your-key.pem ubuntu@<IP>

# NOT 'ec2-user' or 'admin'
```

**"Connection timeout"**
Your IP address is probably wrong in the security group.

```bash
# Get your real public IP
curl -s ipinfo.io/ip

# Update terraform.tfvars with the correct IP
my_ip_cidr = "YOUR_ACTUAL_IP/32"

# Apply the change
terraform apply
```

## Kubernetes Cluster Issues

### kubeadm init Fails

**"[ERROR Mem]: the system RAM is less than the minimum"**
You're using instances that are too small. t3.micro won't work.

```bash
# Use at least t3.medium
instance_type_master = "t3.medium"
```

**"context deadline exceeded" waiting for API server**
This usually means the control plane endpoint is wrong. I've seen this when DNS isn't working.

```bash
# Use the local IP instead of DNS
sudo sed -i 's/api.k8s.yourdomain.com/$(hostname -I | awk "{print $1}")/' /etc/kubeadm/kubeadm-config.yaml
```

**"couldn't validate the identity of the API Server"**
The certificates are messed up. Reset and try again.

```bash
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/
sudo systemctl restart kubelet
# Then run kubeadm init again
```

### Node Join Problems

**"token has expired"**
Tokens only last 24 hours. Generate a new one.

```bash
# On the first control plane node
kubeadm token create --print-join-command
```

**"certificate key has expired"**
For control plane joins, you need a fresh certificate key.

```bash
kubeadm init phase upload-certs --upload-certs
# Use the new key in your join command
```

**"connection refused"**
The control plane isn't ready yet, or there's a firewall issue.

```bash
# Check if the API server is running
kubectl get nodes
sudo systemctl status kubelet

# Check if the port is open
sudo netstat -tlnp | grep :6443
```

### Pod Issues

**Pods stuck in "Pending"**
Usually means no worker nodes are ready, or resource constraints.

```bash
# Check node status
kubectl get nodes -o wide
kubectl describe nodes

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# If nodes have taints, remove them
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

**"ImagePullBackOff"**
Can't pull the container image.

```bash
# Check the image name
kubectl describe pod <POD_NAME>

# Test pulling manually
sudo crictl pull nginx:1.21
```

**"CrashLoopBackOff"**
The application is crashing on startup.

```bash
# Check logs
kubectl logs <POD_NAME> --previous
kubectl describe pod <POD_NAME>

# Common cause: resource limits too low
kubectl patch deployment <DEPLOYMENT> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<CONTAINER>","resources":{"limits":{"memory":"512Mi"}}}]}}}}'
```

### Networking Problems

**Pods can't talk to each other**
CNI isn't working properly.

```bash
# Check Calico pods
kubectl get pods -n kube-system | grep calico

# Restart Calico if needed
kubectl delete pods -n kube-system -l k8s-app=calico-node
```

**DNS doesn't work**
CoreDNS is probably broken.

```bash
# Test DNS
kubectl run test-dns --image=busybox --rm -it -- nslookup kubernetes.default

# Check CoreDNS
kubectl get pods -n kube-system | grep coredns
kubectl logs -n kube-system deployment/coredns

# Restart if needed
kubectl rollout restart deployment/coredns -n kube-system
```

**LoadBalancer services stuck in "Pending"**
You need the AWS Load Balancer Controller.

```bash
# Check if it's installed
kubectl get pods -n kube-system | grep aws-load-balancer

# Install it if missing
kubectl apply -k "github.com/aws/aws-load-balancer-controller/deploy/kubernetes/overlays/stable/?ref=v2.6.0"
```

### Storage Issues

**PVCs stuck in "Pending"**
EBS CSI driver isn't working.

```bash
# Check the CSI driver
kubectl get pods -n kube-system | grep ebs-csi

# Check storage class
kubectl get storageclass

# Make sure nodes have the right IAM permissions
aws sts get-caller-identity
```

## Monitoring and Security Issues

**Prometheus won't start**
Usually a resource issue.

```bash
# Check pod status
kubectl get pods -n monitoring

# Look at events
kubectl describe pod -n monitoring <PROMETHEUS_POD>

# Common fix: increase resources in values.yaml
```

**Grafana shows no data**
Prometheus isn't scraping metrics.

```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-kube-prome-prometheus 9090:9090
# Open http://localhost:9090/targets
```

**Falco not detecting anything**
Check if it's actually running.

```bash
# Check Falco pods
kubectl get pods -n falco

# Look at logs
kubectl logs -n falco daemonset/falco
```

## Performance Issues

**Cluster is slow**
Check resource usage.

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -A

# Look for resource-hungry pods
kubectl get pods -A --sort-by=.status.containerStatuses[0].restartCount
```

**High memory usage**
Probably too many pods on small instances.

```bash
# Check pod distribution
kubectl get pods -A -o wide

# Scale down non-essential workloads
kubectl scale deployment <DEPLOYMENT> --replicas=1
```

## Emergency Procedures

### Reset a Single Node
```bash
# On the problematic node
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/
sudo systemctl restart kubelet

# Rejoin with fresh token
kubeadm join <CONTROL_PLANE_IP>:6443 --token <NEW_TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
```

### Reset the Entire Cluster
```bash
# On all nodes
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/

# Start over with kubeadm init on first control plane
```

### Backup etcd (Do this regularly!)
```bash
sudo ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-$(date +%Y%m%d-%H%M%S).db \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key
```

## Getting Help

### Collect Debug Info
```bash
# Create a debug bundle
mkdir -p /tmp/k8s-debug
kubectl cluster-info dump > /tmp/k8s-debug/cluster-info.log
kubectl get events -A > /tmp/k8s-debug/events.log
kubectl get pods -A -o wide > /tmp/k8s-debug/pods.log
kubectl describe nodes > /tmp/k8s-debug/nodes.log
sudo journalctl -u kubelet --since "1 hour ago" > /tmp/k8s-debug/kubelet.log

tar -czf k8s-debug-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp k8s-debug/
```

### Where to Ask
- **GitHub Issues**: For problems with this specific setup
- **Kubernetes Slack**: #kubeadm channel for general kubeadm issues
- **Stack Overflow**: kubernetes, kubeadm, aws tags

## My Debugging Process

When something breaks, I follow this order:

1. **Check the obvious stuff** - permissions, networking, resources
2. **Look at events** - `kubectl get events --sort-by=.metadata.creationTimestamp`
3. **Check logs** - kubelet logs, pod logs, system logs
4. **Verify connectivity** - can nodes talk to each other?
5. **Test components** - is DNS working? Can you pull images?
6. **Reset if needed** - sometimes it's faster to start over

## Prevention

**Things I do to avoid problems:**
- Always test in a dev environment first
- Keep backups of etcd
- Monitor resource usage
- Update components regularly
- Document any custom changes

**Things that will save you time:**
- Use the automation script instead of manual deployment
- Set up monitoring from day one
- Keep your AWS credentials and permissions organized
- Test disaster recovery procedures before you need them

---

**Remember**: Kubernetes is complex. Don't feel bad if it takes time to debug issues. I've been doing this for years and still learn new things every time something breaks.

The automation script handles most of these edge cases, which is why I recommend using it unless you're specifically trying to learn the manual process.