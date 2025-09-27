#!/usr/bin/env bash
# Fill TOKEN, HASH and CERT_KEY from kubeadm init output.
# Control planes:
# sudo kubeadm join api.k8s.subrotosharma.site:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH> --control-plane --certificate-key <CERT_KEY>
# Workers:
# sudo kubeadm join api.k8s.subrotosharma.site:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
