#!/bin/bash
# Install monitoring and security components

set -e

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 Installing monitoring and security components..."

# Add Helm repositories
log "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# Create Grafana admin secret
log "🔐 Creating Grafana admin secret..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic grafana-admin-secret \
    --from-literal=password="$(openssl rand -base64 32)" \
    -n monitoring \
    --dry-run=client -o yaml | kubectl apply -f -

# Install Prometheus + Grafana monitoring stack
log "📊 Installing Prometheus + Grafana stack..."
helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
    -n monitoring --create-namespace \
    -f monitoring/prometheus/values.yaml \
    --wait --timeout=10m

# Install Loki logging stack
log "📋 Installing Loki logging stack..."
helm upgrade --install loki grafana/loki-stack \
    -n monitoring \
    -f monitoring/loki/values.yaml \
    --wait --timeout=5m

# Install Falco runtime security
log "🔒 Installing Falco runtime security..."
helm upgrade --install falco falcosecurity/falco \
    -n falco --create-namespace \
    -f security/falco/values.yaml \
    --wait --timeout=5m

# Install Gatekeeper policy engine
log "🛡️ Installing Gatekeeper policy engine..."
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Wait for Gatekeeper to be ready
log "Waiting for Gatekeeper to be ready..."
kubectl wait --for=condition=Ready pod -l control-plane=controller-manager -n gatekeeper-system --timeout=300s

# Apply security policies
log "🔐 Applying security policies..."
kubectl apply -f security/gatekeeper/constraint-templates.yaml
sleep 30
kubectl apply -f security/gatekeeper/constraints.yaml

# Apply network policies
log "🌐 Applying network policies..."
kubectl apply -f security/network-policies/default-deny.yaml

# Label namespaces for network policies
kubectl label namespace production name=production --overwrite
kubectl label namespace monitoring name=monitoring --overwrite
kubectl label namespace ingress-nginx name=ingress-nginx --overwrite

log "✅ Monitoring and security installation completed!"
log ""
log "📊 Access Grafana:"
log "   kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80"
log "   Username: admin"
log "   Password: kubectl get secret grafana-admin-secret -n monitoring -o jsonpath='{.data.password}' | base64 -d"
log ""
log "🔒 Access Falco UI:"
log "   kubectl port-forward -n falco svc/falco-falcosidekick-ui 2802:2802"
log ""
log "🛡️ Check Gatekeeper policies:"
log "   kubectl get constraints"