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

# Get join command from kubeadm init output or generate new token:
# kubeadm token create --print-join-command

echo "Please update JOIN_CMD with actual values from your cluster"
echo "Example: kubeadm token create --print-join-command"
echo "Then update this script with the real join command"

# Uncomment and update the following lines with real values:
# JOIN_CMD="sudo kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>"
# 
# echo "Joining worker nodes to cluster..."
# 
# for ip in "${WORKER_IPS[@]}"; do
#     echo "Joining worker node: $ip"
#     ssh -o StrictHostKeyChecking=no ubuntu@$ip "$JOIN_CMD" &
# done
# 
# echo "Waiting for all joins to complete..."
# wait
# 
# echo "All worker nodes join initiated. Check status with: kubectl get nodes"