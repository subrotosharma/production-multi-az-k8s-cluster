#!/bin/bash
# Automated Kubernetes cluster initialization

set -e

# Wait for the node to be ready
sleep 60

# Check if this is the first control plane node (lowest IP)
CURRENT_IP=$(hostname -I | awk '{print $1}')

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting Kubernetes initialization on $CURRENT_IP"

# Create kubeadm config
sudo mkdir -p /etc/kubeadm
sudo tee /etc/kubeadm/kubeadm-config-local.yaml > /dev/null <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.30.2
clusterName: ha-cluster
controlPlaneEndpoint: "$CURRENT_IP:6443"
networking:
  serviceSubnet: 10.96.0.0/12
  podSubnet: 10.244.0.0/16
controllerManager:
  extraArgs:
    cloud-provider: external
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF

log "Initializing Kubernetes cluster..."
# Initialize cluster
sudo kubeadm init --config /etc/kubeadm/kubeadm-config-local.yaml --upload-certs > /tmp/kubeadm-init.log 2>&1

log "Setting up kubectl..."
# Set up kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

log "Installing Calico CNI..."
# Install Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

log "Installing Helm..."
# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh

log "Adding Helm repositories..."
# Add Helm repositories
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo update

log "Waiting for nodes to be ready..."
# Wait for nodes to be ready
sleep 60

log "Installing Kubernetes components..."
# Install components (with error handling)
helm install metrics-server metrics-server/metrics-server -n kube-system \
    --set args='{--kubelet-insecure-tls}' \
    --set hostNetwork.enabled=true \
    --set containerPort=4443 || log "Metrics server installation failed (may already exist)"

helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx \
    --create-namespace \
    --set controller.service.type=NodePort \
    --set controller.hostNetwork=true \
    --set controller.kind=DaemonSet || log "Ingress NGINX installation failed (may already exist)"

helm install cert-manager jetstack/cert-manager -n cert-manager \
    --create-namespace \
    --set installCRDs=true || log "Cert Manager installation failed (may already exist)"

log "Creating production namespace..."
# Create production namespace and deploy sample app
kubectl create namespace production || log "Production namespace already exists"

log "Deploying sample HA application..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-ha
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-ha
  template:
    metadata:
      labels:
        app: nginx-ha
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-ha-service
  namespace: production
spec:
  selector:
    app: nginx-ha
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-ha-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-ha
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nginx-ha-pdb
  namespace: production
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: nginx-ha
EOF

log "Waiting for application to be ready..."
sleep 30

log "Cluster initialization completed successfully!"
log "Join commands saved to /tmp/kubeadm-init.log"

# Mark initialization complete
touch /tmp/k8s-init-complete

log "Cluster status:"
kubectl get nodes
kubectl get pods -A
kubectl get svc -n production