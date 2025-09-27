#!/usr/bin/env bash
set -euo pipefail
CFG=${1:-/etc/kubeadm/kubeadm-config-aws.yaml}
sudo kubeadm init --config "$CFG" --upload-certs | tee /root/kubeadm-init.out
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
