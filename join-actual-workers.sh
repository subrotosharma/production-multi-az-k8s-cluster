#!/bin/bash
# Join actual worker nodes found in the cluster

WORKER_IPS=(
    "10.0.10.48"
    "10.0.10.192"
    "10.0.11.79"
    "10.0.11.219"
    "10.0.12.14"
    "10.0.12.174"
)

JOIN_CMD="sudo kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>"

echo "Joining worker nodes to cluster..."

for ip in "${WORKER_IPS[@]}"; do
    echo "Joining worker node: $ip"
    ssh -o StrictHostKeyChecking=no ubuntu@$ip "$JOIN_CMD" &
done

echo "Waiting for all joins to complete..."
wait

echo "Worker nodes joined! Check with: kubectl get nodes"