#!/bin/bash
# Automated script to join all worker nodes

# Worker node IPs (update these with your actual worker IPs)
WORKER_IPS=(
    "10.0.10.100"
    "10.0.10.101" 
    "10.0.10.102"
    "10.0.11.100"
    "10.0.11.101"
    "10.0.11.102"
    "10.0.12.100"
    "10.0.12.101"
    "10.0.12.102"
)

# Join command
JOIN_CMD="sudo kubeadm join 10.0.10.9:6443 --token p3lj94.4lpajtvpu3dz0z18 --discovery-token-ca-cert-hash sha256:ece29981e3ac2ae43bc10f38c5d603c139c5568342ebb5505f42fe3b99df1f66"

echo "Joining worker nodes to cluster..."

for ip in "${WORKER_IPS[@]}"; do
    echo "Joining worker node: $ip"
    ssh -o StrictHostKeyChecking=no ubuntu@$ip "$JOIN_CMD" &
done

echo "Waiting for all joins to complete..."
wait

echo "All worker nodes join initiated. Check status with: kubectl get nodes"