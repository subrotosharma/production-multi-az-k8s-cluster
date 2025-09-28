# Kubernetes Components Documentation

Complete guide to all Kubernetes manifests and configurations.

## 🎯 Components Overview

### Core Components
- **CNI**: Calico for pod networking
- **Storage**: AWS EBS CSI Driver with gp3 storage class
- **Ingress**: ingress-nginx controller
- **Certificates**: cert-manager for TLS automation
- **Security**: Kyverno policies and Pod Security Standards
- **Monitoring**: metrics-server for resource monitoring

## 📁 Kubernetes Structure

```
k8s/
├── addons/
│   ├── cert-manager/        # Certificate management
│   ├── kyverno/            # Security policies
│   ├── metrics-server.yaml # Resource monitoring
│   └── pod-security-standards.yaml
├── aws/
│   └── ccm.yaml            # AWS Cloud Controller Manager
├── cni/
│   └── calico.yaml         # Container Network Interface
├── ingress-nginx/
│   └── values.yaml         # Ingress controller config
├── storage/
│   └── aws/
│       └── storageclass-gp3.yaml
└── monitoring/
    └── kube-prometheus-stack-values.yaml
```

## 🔧 Component Installation

### 1. CNI (Calico)
```bash
kubectl apply -f k8s/cni/calico.yaml
```

### 2. Storage (EBS CSI)
```bash
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.24"
kubectl apply -f k8s/storage/aws/storageclass-gp3.yaml
```

### 3. Ingress Controller
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/aws/deploy.yaml
```

### 4. Certificate Manager
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
kubectl apply -f k8s/addons/cert-manager/
```

### 5. Security Policies
```bash
kubectl apply -f k8s/addons/kyverno/install.yaml
kubectl apply -f k8s/addons/kyverno/policies-baseline.yaml
kubectl apply -f k8s/addons/pod-security-standards.yaml
```

## 🛡️ Security Configuration

### Pod Security Standards
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

## 📊 Monitoring Setup

### Metrics Server
```bash
kubectl apply -f k8s/addons/metrics-server.yaml
kubectl top nodes
kubectl top pods -A
```

### Prometheus Stack (Optional)
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
    -f k8s/monitoring/kube-prometheus-stack-values.yaml \
    -n monitoring --create-namespace
```