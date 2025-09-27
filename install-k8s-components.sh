#!/bin/bash
set -e

echo "🔧 Installing Kubernetes components..."

# Install Calico CNI
echo "🌐 Installing Calico CNI..."
kubectl apply -f k8s/cni/calico.yaml

# Install AWS Cloud Controller Manager
echo "☁️ Installing AWS Cloud Controller Manager..."
kubectl apply -f k8s/aws/ccm.yaml

# Install EBS CSI Driver
echo "💾 Installing EBS CSI Driver..."
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update
helm upgrade --install ebs-csi aws-ebs-csi-driver/aws-ebs-csi-driver \
    -n kube-system \
    --set controller.replicaCount=2

kubectl apply -f k8s/storage/aws/storageclass-gp3.yaml

# Install ingress-nginx
echo "🌍 Installing ingress-nginx..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    -n ingress-nginx \
    --create-namespace \
    -f k8s/ingress-nginx/values.yaml

# Install cert-manager
echo "🔐 Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
    -n cert-manager \
    --create-namespace \
    --set crds.enabled=true

echo "⚠️  Please update k8s/addons/cert-manager/route53-credentials-secret.yaml with your AWS credentials"
echo "Then run: kubectl apply -f k8s/addons/cert-manager/route53-credentials-secret.yaml"
echo "And: kubectl apply -f k8s/addons/cert-manager/clusterissuer-route53-dns01.yaml"

# Install Kyverno
echo "🛡️ Installing Kyverno..."
kubectl apply -f k8s/addons/kyverno/install.yaml
sleep 30
kubectl apply -f k8s/addons/kyverno/policies-baseline.yaml

# Install metrics-server
echo "📊 Installing metrics-server..."
kubectl apply -f k8s/addons/metrics-server.yaml

# Install Loki stack
echo "📝 Installing Loki stack..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm upgrade --install loki grafana/loki-stack \
    -n logging \
    --create-namespace \
    -f k8s/logging/loki-values.yaml

# Apply pod security standards
echo "🔒 Applying pod security standards..."
kubectl apply -f k8s/addons/pod-security-standards.yaml

# Install sample HA app
echo "🚀 Installing sample HA app..."
kubectl create ns apps || true
helm upgrade --install sample-ha-app ./apps/sample-ha-app \
    -n apps \
    --create-namespace

echo "✅ All components installed successfully!"
echo ""
echo "Access Grafana: kubectl port-forward -n logging svc/loki-grafana 3000:80"
echo "Default Grafana credentials: admin/admin"