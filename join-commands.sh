#!/bin/bash
# Kubernetes cluster join commands

# Control plane join command (run on cp2 and cp3):
kubeadm join 10.0.10.9:6443 --token p3lj94.4lpajtvpu3dz0z18 \
	--discovery-token-ca-cert-hash sha256:ece29981e3ac2ae43bc10f38c5d603c139c5568342ebb5505f42fe3b99df1f66 \
	--control-plane --certificate-key fce78217211b6670270b79ef4d321ae209f10af5fd83fc128f7f426d80c48486

# Worker node join command (run on all worker nodes):
kubeadm join 10.0.10.9:6443 --token p3lj94.4lpajtvpu3dz0z18 \
	--discovery-token-ca-cert-hash sha256:ece29981e3ac2ae43bc10f38c5d603c139c5568342ebb5505f42fe3b99df1f66

# Note: Certificate key expires in 2 hours. If needed, regenerate with:
# kubeadm init phase upload-certs --upload-certs