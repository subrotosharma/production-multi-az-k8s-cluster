#!/bin/bash
# Kubernetes cluster join commands

# Control plane join command (run on cp2 and cp3):
# kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> \
#	--discovery-token-ca-cert-hash sha256:<HASH> \
#	--control-plane --certificate-key <CERT_KEY>

# Worker node join command (run on all worker nodes):
# kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> \
#	--discovery-token-ca-cert-hash sha256:<HASH>

# Generate new join commands with:
# kubeadm token create --print-join-command

# Note: Certificate key expires in 2 hours. If needed, regenerate with:
# kubeadm init phase upload-certs --upload-certs