# CI/CD Documentation

Complete guide to continuous integration and deployment pipelines for the Kubernetes cluster.

## 🎯 CI/CD Overview

The CI/CD pipeline provides automated:
- **Infrastructure Deployment**: Terraform validation and deployment
- **Security Scanning**: Container image and infrastructure security checks
- **Kubernetes Deployment**: Automated application deployment
- **Testing**: Integration and smoke tests
- **Rollback**: Automated rollback on failure

## 📁 CI/CD Structure

```
ci/
├── github-actions-deploy.yaml    # GitHub Actions workflow
├── terraform-plan.yaml          # Infrastructure planning workflow
├── security-scan.yaml           # Security scanning workflow
└── k8s-deploy.yaml              # Kubernetes deployment workflow
```

## 🚀 GitHub Actions Workflows

### Main Deployment Workflow
```yaml
# .github/workflows/deploy.yml
name: Deploy Production K8s Cluster

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  AWS_REGION: us-east-1
  CLUSTER_NAME: production-k8s

jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: 1.6.0
    
    - name: Terraform Init
      run: |
        cd infra/terraform/aws
        terraform init
    
    - name: Terraform Plan
      run: |
        cd infra/terraform/aws
        terraform plan -var-file="terraform.tfvars"
```

### Infrastructure Deployment
```yaml
  terraform-apply:
    needs: terraform-plan
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
    
    - name: Deploy Infrastructure
      run: |
        cd infra/terraform/aws
        terraform init
        terraform apply -auto-approve -var-file="terraform.tfvars"
    
    - name: Save Terraform Outputs
      run: |
        cd infra/terraform/aws
        terraform output -json > ../../../terraform-outputs.json
    
    - name: Upload Terraform Outputs
      uses: actions/upload-artifact@v4
      with:
        name: terraform-outputs
        path: terraform-outputs.json
```

### Kubernetes Deployment
```yaml
  k8s-deploy:
    needs: terraform-apply
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Download Terraform Outputs
      uses: actions/download-artifact@v4
      with:
        name: terraform-outputs
    
    - name: Configure kubectl
      run: |
        # Extract bastion and control plane IPs from terraform outputs
        BASTION_IP=$(jq -r '.bastion_public_ip.value' terraform-outputs.json)
        CP1_IP=$(jq -r '.control_plane_private_ips.value[0]' terraform-outputs.json)
        
        # Setup SSH and kubectl configuration
        echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
        chmod 600 ~/.ssh/id_rsa
        
        # Copy kubeconfig from cluster
        scp -o StrictHostKeyChecking=no ubuntu@$BASTION_IP:~/.kube/config ~/.kube/config
    
    - name: Deploy Kubernetes Components
      run: |
        kubectl apply -f k8s/cni/calico.yaml
        kubectl apply -f k8s/addons/metrics-server.yaml
        kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.24"
        kubectl apply -f k8s/storage/aws/storageclass-gp3.yaml
    
    - name: Deploy Sample Application
      run: |
        helm upgrade --install sample-app apps/sample-ha-app/ \
          -n production --create-namespace \
          --wait --timeout=10m
    
    - name: Run Smoke Tests
      run: |
        kubectl wait --for=condition=ready pod -l app=sample-ha-app -n production --timeout=300s
        kubectl get pods -n production
        kubectl get svc -n production
```

## 🔒 Security Scanning

### Container Image Scanning
```yaml
  security-scan:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: 'trivy-results.sarif'
    
    - name: Scan Kubernetes manifests
      run: |
        # Install kubesec
        wget https://github.com/controlplaneio/kubesec/releases/latest/download/kubesec_linux_amd64.tar.gz
        tar -xzf kubesec_linux_amd64.tar.gz
        
        # Scan manifests
        ./kubesec scan k8s/**/*.yaml
        ./kubesec scan apps/sample-ha-app/templates/*.yaml
```

### Infrastructure Security Scanning
```yaml
  terraform-security:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Run tfsec
      uses: aquasecurity/tfsec-action@v1.0.3
      with:
        working_directory: infra/terraform/aws
    
    - name: Run Checkov
      uses: bridgecrewio/checkov-action@master
      with:
        directory: infra/terraform/aws
        framework: terraform
```

## 🧪 Testing Pipeline

### Integration Tests
```yaml
  integration-tests:
    needs: k8s-deploy
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup kubectl
      run: |
        # Configure kubectl from previous step
        
    - name: Test Cluster Functionality
      run: |
        # Test node readiness
        kubectl get nodes
        kubectl wait --for=condition=Ready nodes --all --timeout=300s
        
        # Test pod scheduling
        kubectl run test-pod --image=busybox --command -- sleep 60
        kubectl wait --for=condition=Ready pod/test-pod --timeout=120s
        kubectl delete pod test-pod
        
        # Test storage
        kubectl apply -f - <<EOF
        apiVersion: v1
        kind: PersistentVolumeClaim
        metadata:
          name: test-pvc
        spec:
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 1Gi
          storageClassName: gp3
        EOF
        
        kubectl wait --for=condition=Bound pvc/test-pvc --timeout=120s
        kubectl delete pvc test-pvc
        
        # Test ingress
        kubectl get ingress -A
        
        # Test application
        kubectl get pods -n production -l app=sample-ha-app
        kubectl wait --for=condition=ready pod -l app=sample-ha-app -n production --timeout=300s
```

### Load Testing
```yaml
  load-tests:
    needs: integration-tests
    runs-on: ubuntu-latest
    
    steps:
    - name: Install hey
      run: |
        wget https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
        chmod +x hey_linux_amd64
        sudo mv hey_linux_amd64 /usr/local/bin/hey
    
    - name: Run Load Test
      run: |
        # Get ingress endpoint
        INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        
        # Run load test
        hey -n 1000 -c 10 -H "Host: app.yourdomain.com" http://$INGRESS_IP/
        
        # Check HPA scaling
        kubectl get hpa -n production
```

## 🔄 GitOps with ArgoCD

### ArgoCD Installation
```yaml
  argocd-setup:
    runs-on: ubuntu-latest
    
    steps:
    - name: Install ArgoCD
      run: |
        kubectl create namespace argocd
        kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
        
        # Wait for ArgoCD to be ready
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    
    - name: Configure ArgoCD Application
      run: |
        kubectl apply -f k8s/addons/argocd/root-app.yaml
```

### ArgoCD Application Configuration
```yaml
# k8s/addons/argocd/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: production-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/subrotosharma/production-multi-az-k8s-cluster
    targetRevision: main
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

## 📊 Monitoring and Alerting

### Prometheus Monitoring
```yaml
  monitoring-setup:
    runs-on: ubuntu-latest
    
    steps:
    - name: Install Prometheus Stack
      run: |
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        
        helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
          -f k8s/monitoring/kube-prometheus-stack-values.yaml \
          -n monitoring --create-namespace \
          --wait --timeout=10m
    
    - name: Configure Alerts
      run: |
        kubectl apply -f - <<EOF
        apiVersion: monitoring.coreos.com/v1
        kind: PrometheusRule
        metadata:
          name: deployment-alerts
          namespace: monitoring
        spec:
          groups:
          - name: deployment.rules
            rules:
            - alert: DeploymentReplicasMismatch
              expr: kube_deployment_spec_replicas != kube_deployment_status_ready_replicas
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "Deployment has mismatched replicas"
        EOF
```

## 🚨 Rollback Procedures

### Automatic Rollback
```yaml
  rollback-on-failure:
    if: failure()
    runs-on: ubuntu-latest
    
    steps:
    - name: Rollback Application
      run: |
        helm rollback sample-app -n production
        kubectl rollout status deployment/sample-ha-app -n production
    
    - name: Rollback Infrastructure (if needed)
      run: |
        cd infra/terraform/aws
        git checkout HEAD~1 -- .
        terraform apply -auto-approve -var-file="terraform.tfvars"
```

### Manual Rollback Commands
```bash
# Rollback application
helm rollback sample-app 1 -n production

# Rollback Kubernetes deployment
kubectl rollout undo deployment/sample-ha-app -n production

# Rollback infrastructure
cd infra/terraform/aws
git revert HEAD
terraform apply -auto-approve
```

## 🔧 Pipeline Configuration

### Required Secrets
```bash
# GitHub Repository Secrets
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
SSH_PRIVATE_KEY=-----BEGIN OPENSSH PRIVATE KEY-----...
KUBECONFIG=apiVersion: v1...
```

### Environment Variables
```yaml
env:
  AWS_REGION: us-east-1
  CLUSTER_NAME: production-k8s
  TERRAFORM_VERSION: 1.6.0
  KUBECTL_VERSION: 1.28.0
  HELM_VERSION: 3.12.0
```

## 📈 Pipeline Optimization

### Caching
```yaml
- name: Cache Terraform
  uses: actions/cache@v4
  with:
    path: |
      ~/.terraform.d/plugin-cache
    key: ${{ runner.os }}-terraform-${{ hashFiles('**/.terraform.lock.hcl') }}

- name: Cache Helm
  uses: actions/cache@v4
  with:
    path: ~/.cache/helm
    key: ${{ runner.os }}-helm-${{ hashFiles('**/Chart.lock') }}
```

### Parallel Execution
```yaml
jobs:
  security-scan:
    runs-on: ubuntu-latest
    # Runs in parallel with terraform-plan
    
  terraform-plan:
    runs-on: ubuntu-latest
    # Runs in parallel with security-scan
    
  terraform-apply:
    needs: [security-scan, terraform-plan]
    # Waits for both jobs to complete
```

This CI/CD pipeline provides automated, secure, and reliable deployment of your Kubernetes infrastructure and applications.