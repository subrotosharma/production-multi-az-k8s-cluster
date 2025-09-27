#!/bin/bash
set -e

echo "🚀 Starting HA Kubernetes cluster deployment..."

# Step 1: Deploy infrastructure with Terraform
echo "📦 Deploying AWS infrastructure..."
cd infra/terraform/aws
terraform init
terraform plan
read -p "Do you want to apply the Terraform plan? (y/N): " confirm
if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    terraform apply -auto-approve
else
    echo "Deployment cancelled."
    exit 1
fi

# Get outputs
API_LB_DNS=$(terraform output -raw api_lb_dns)
echo "API Load Balancer DNS: $API_LB_DNS"

cd ../../..

# Step 2: Create Route53 record for API endpoint
echo "🌐 Creating Route53 DNS record..."
aws route53 change-resource-record-sets --hosted-zone-id Z04439106WYRY5ZWG75C --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "api.k8s.subrotosharma.site",
      "Type": "CNAME",
      "TTL": 300,
      "ResourceRecords": [{"Value": "'$API_LB_DNS'"}]
    }
  }]
}'

echo "⏳ Waiting 5 minutes for instances to initialize..."
sleep 300

# Step 3: Copy kubeadm config to first master
echo "📋 Copying kubeadm config to master nodes..."
MASTER1_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=ha-cluster-cp1" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].InstanceId' --output text)

aws ssm send-command \
    --instance-ids $MASTER1_ID \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["mkdir -p /etc/kubeadm"]' \
    --output text

# Copy kubeadm config
aws ssm send-command \
    --instance-ids $MASTER1_ID \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["cat > /etc/kubeadm/kubeadm-config-aws.yaml << '\''EOF'\''
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v1.30.2
clusterName: ha-cluster
controlPlaneEndpoint: \"api.k8s.subrotosharma.site:6443\"
networking:
  serviceSubnet: 10.96.0.0/12
  podSubnet: 10.244.0.0/16
controllerManager:
  extraArgs:
    cloud-provider: external
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF"]' \
    --output text

echo "✅ Infrastructure deployed successfully!"
echo ""
echo "Next steps:"
echo "1. SSH to the first master node: aws ssm start-session --target $MASTER1_ID"
echo "2. Initialize the cluster: sudo kubeadm init --config /etc/kubeadm/kubeadm-config-aws.yaml --upload-certs"
echo "3. Follow the join commands to add other nodes"
echo "4. Install CNI and other components as described in README.md"