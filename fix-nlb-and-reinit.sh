#!/bin/bash
# Fix NLB configuration and reinitialize cluster

echo "Applying Terraform changes to make NLB internal..."
cd infra/terraform/aws
terraform apply -auto-approve

echo "Terraform changes applied. Now connect to the control plane node and run:"
echo ""
echo "ssh ubuntu@10.0.10.9"
echo "sudo kubeadm reset -f"
echo "sudo kubeadm init --config /etc/kubeadm/kubeadm-config-aws.yaml --upload-certs"