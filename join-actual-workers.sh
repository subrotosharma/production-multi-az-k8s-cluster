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

JOIN_CMD="sudo kubeadm join 10.0.10.9:6443 --token p3lj94.4lpajtvpu3dz0z18 --discovery-token-ca-cert-hash sha256:ece29981e3ac2ae43bc10f38c5d603c139c5568342ebb5505f42fe3b99df1f66"

echo "Joining worker nodes to cluster..."

for ip in "${WORKER_IPS[@]}"; do
    echo "Joining worker node: $ip"
    ssh -o StrictHostKeyChecking=no ubuntu@$ip "$JOIN_CMD" &
done

echo "Waiting for all joins to complete..."
wait

echo "Worker nodes joined! Check with: kubectl get nodes"