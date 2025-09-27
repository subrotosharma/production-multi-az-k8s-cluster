#!/bin/bash
# SSH Key Setup for HA Cluster

echo "Setting up SSH access to cluster nodes..."

# Copy SSH key to bastion
echo "Copying SSH key to bastion host..."
scp -i /root/SecOps.pem /root/SecOps.pem ubuntu@3.87.89.79:~/.ssh/

# SSH to bastion with agent forwarding
echo "Connecting to bastion with SSH agent forwarding..."
ssh -A -i /root/SecOps.pem ubuntu@3.87.89.79

echo "From bastion, you can now SSH to any node:"
echo "ssh ubuntu@10.0.10.9   # Master 1"
echo "ssh ubuntu@10.0.11.93  # Master 2" 
echo "ssh ubuntu@10.0.12.36  # Master 3"