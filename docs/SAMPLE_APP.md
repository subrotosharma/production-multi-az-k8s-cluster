# Sample HA Application Documentation

Complete guide to deploying and managing the sample highly available application.

## 🎯 Application Overview

The sample HA application demonstrates production-ready deployment patterns including:
- **High Availability**: Multiple replicas across nodes
- **Auto-scaling**: Horizontal Pod Autoscaler (HPA)
- **Load Balancing**: Service with multiple endpoints
- **Persistent Storage**: StatefulSet with PVCs
- **Network Security**: Network policies
- **Ingress**: External access via ingress controller
- **Pod Disruption Budget**: Ensures availability during updates

## 📁 Application Structure

```
apps/sample-ha-app/
├── Chart.yaml              # Helm chart metadata
├── values.yaml            # Default configuration values
└── templates/
    ├── deployment.yaml    # Application deployment
    ├── service.yaml       # Service definition
    ├── ingress.yaml       # Ingress configuration
    ├── hpa.yaml          # Horizontal Pod Autoscaler
    ├── pvc.yaml          # Persistent Volume Claims
    ├── pdb.yaml          # Pod Disruption Budget
    └── networkpolicy.yaml # Network security policies
```

## 🚀 Deployment Methods

### Method 1: Using Helm
```bash
# Install the application
helm install sample-app apps/sample-ha-app/ -n production --create-namespace

# Upgrade the application
helm upgrade sample-app apps/sample-ha-app/ -n production

# Check status
helm status sample-app -n production

# Uninstall
helm uninstall sample-app -n production
```

### Method 2: Using kubectl
```bash
# Apply all manifests
kubectl apply -f apps/sample-ha-app/templates/ -n production

# Check deployment
kubectl get all -n production

# Delete application
kubectl delete -f apps/sample-ha-app/templates/ -n production
```

## 🔧 Configuration Options

### values.yaml Configuration
```yaml
# Application settings
app:
  name: sample-ha-app
  image: nginx:1.21
  replicas: 3
  port: 80

# Resource limits
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Auto-scaling
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# Storage
persistence:
  enabled: true
  size: 1Gi
  storageClass: gp3

# Ingress
ingress:
  enabled: true
  host: app.yourdomain.com
  tls: true
```

### Custom Values
```bash
# Create custom values file
cat > custom-values.yaml << EOF
app:
  replicas: 5
  image: nginx:1.22

resources:
  limits:
    cpu: 1000m
    memory: 1Gi

ingress:
  host: myapp.example.com
EOF

# Deploy with custom values
helm install sample-app apps/sample-ha-app/ -f custom-values.yaml -n production
```

## 📊 Application Components Detail

### Deployment Configuration
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-ha-app
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: sample-ha-app
  template:
    spec:
      containers:
      - name: app
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
```

### Service Configuration
```yaml
apiVersion: v1
kind: Service
metadata:
  name: sample-ha-app
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: sample-ha-app
```

### Horizontal Pod Autoscaler
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: sample-ha-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: sample-ha-app
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Pod Disruption Budget
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: sample-ha-app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: sample-ha-app
```

### Ingress Configuration
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sample-ha-app-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - app.yourdomain.com
    secretName: sample-ha-app-tls
  rules:
  - host: app.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: sample-ha-app
            port:
              number: 80
```

## 🔍 Monitoring and Testing

### Check Application Health
```bash
# Check pods
kubectl get pods -n production -l app=sample-ha-app

# Check service endpoints
kubectl get endpoints -n production

# Check HPA status
kubectl get hpa -n production

# Check PDB status
kubectl get pdb -n production

# View logs
kubectl logs -n production deployment/sample-ha-app -f
```

### Load Testing
```bash
# Install hey load testing tool
go install github.com/rakyll/hey@latest

# Get ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Run load test
hey -n 1000 -c 10 -H "Host: app.yourdomain.com" http://$INGRESS_IP/

# Watch HPA scale
kubectl get hpa -n production -w
```

### Chaos Testing
```bash
# Delete random pods to test resilience
kubectl delete pod -n production -l app=sample-ha-app --field-selector=status.phase=Running --dry-run=client

# Simulate node failure
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Check application availability during disruption
while true; do curl -s -o /dev/null -w "%{http_code}\n" http://app.yourdomain.com; sleep 1; done
```

## 🔒 Security Features

### Network Policy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sample-ha-app-netpol
spec:
  podSelector:
    matchLabels:
      app: sample-ha-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

### Security Context
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000
  seccompProfile:
    type: RuntimeDefault
containers:
- name: app
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
      - ALL
```

## 📈 Scaling and Updates

### Manual Scaling
```bash
# Scale deployment
kubectl scale deployment sample-ha-app --replicas=5 -n production

# Check scaling
kubectl get pods -n production -l app=sample-ha-app
```

### Rolling Updates
```bash
# Update image
kubectl set image deployment/sample-ha-app app=nginx:1.22 -n production

# Check rollout status
kubectl rollout status deployment/sample-ha-app -n production

# Rollback if needed
kubectl rollout undo deployment/sample-ha-app -n production
```

### Blue-Green Deployment
```bash
# Create new version
helm install sample-app-v2 apps/sample-ha-app/ \
    --set app.image=nginx:1.22 \
    --set app.name=sample-ha-app-v2 \
    -n production

# Switch traffic (update ingress)
kubectl patch ingress sample-ha-app-ingress -n production \
    --type='json' \
    -p='[{"op": "replace", "path": "/spec/rules/0/http/paths/0/backend/service/name", "value": "sample-ha-app-v2"}]'

# Remove old version
helm uninstall sample-app -n production
```

## 🧹 Cleanup

### Remove Application
```bash
# Using Helm
helm uninstall sample-app -n production

# Using kubectl
kubectl delete -f apps/sample-ha-app/templates/ -n production

# Remove namespace
kubectl delete namespace production
```

This sample application demonstrates all the key patterns needed for running production workloads on Kubernetes with high availability, security, and observability.