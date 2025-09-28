#!/bin/bash
# Create Grafana admin secret

kubectl create secret generic grafana-admin-secret \
  --from-literal=password="$(openssl rand -base64 32)" \
  -n monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Grafana admin password created. Get it with:"
echo "kubectl get secret grafana-admin-secret -n monitoring -o jsonpath='{.data.password}' | base64 -d"