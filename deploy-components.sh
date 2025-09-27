#!/bin/bash
# Deploy Kubernetes components

BASTION_IP="3.87.89.79"
CP1_IP="10.0.10.9"

echo "Copying k8s manifests to bastion..."
scp -i /root/SecOps.pem -r k8s ubuntu@${BASTION_IP}:~/

echo "Copying manifests from bastion to control plane..."
ssh -i /root/SecOps.pem ubuntu@${BASTION_IP} "scp -r k8s ubuntu@${CP1_IP}:~/"

echo "Installing components on control plane..."
ssh -i /root/SecOps.pem ubuntu@${BASTION_IP} "ssh ubuntu@${CP1_IP} '
# Install Calico CNI
kubectl apply -f k8s/cni/calico.yaml

# Install AWS CCM
kubectl apply -f k8s/aws/ccm.yaml

# Install storage class
kubectl apply -f k8s/storage/aws/storageclass-gp3.yaml

# Install metrics server
kubectl apply -f k8s/addons/metrics-server.yaml

# Install Kyverno
kubectl apply -f k8s/addons/kyverno/install.yaml
kubectl apply -f k8s/addons/kyverno/policies-baseline.yaml

# Install pod security standards
kubectl apply -f k8s/addons/pod-security-standards.yaml

echo "Checking cluster status..."
kubectl get nodes
kubectl get pods -A
'"

echo "Components deployment completed!"