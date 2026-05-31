# Low-Level Design (LLD) - AKS Production-Grade POC Setup

## Document Information
- **Version**: 1.0
- **Author**: DevOps Team
- **Date**: 2026-05-31
- **Project**: AKS Production-Grade POC
- **Azure Subscription ID**: 7908ea24-a708-4291-be15-98426e3e9ca5

## Table of Contents
1. [Infrastructure Detailed Design](#infrastructure-detailed-design)
2. [Kubernetes Configuration](#kubernetes-configuration)
3. [CI/CD Pipeline Architecture](#cicd-pipeline-architecture)
4. [GitOps Implementation](#gitops-implementation)
5. [Observability Stack Configuration](#observability-stack-configuration)
6. [Network Configuration](#network-configuration)
7. [Security Implementation](#security-implementation)
8. [Storage Configuration](#storage-configuration)
9. [GPU Workload Configuration](#gpu-workload-configuration)
10. [Application Deployment Architecture](#application-deployment-architecture)

---

## Infrastructure Detailed Design

### Terraform Structure
```
terraform/
├── main.tf                 # Main entry point
├── variables.tf            # Input variables
├── outputs.tf             # Output values
├── provider.tf            # Azure provider configuration
├── backend.tf             # Terraform state backend
├── modules/
│   ├── vnet/
│   ├── aks/
│   ├── acr/
│   ├── database/
│   └── monitoring/
└── environments/
    ├── dev/
    ├── staging/
    └── prod/
```

### Azure Resource Specifications

#### 1. Virtual Network Configuration
```hcl
# VNet Address Space: 10.0.0.0/16
# Subnet Configuration:
- aks-system-subnet: 10.0.1.0/24 (System node pool)
- aks-user-subnet: 10.0.2.0/24 (User node pool)
- aks-gpu-subnet: 10.0.3.0/24 (GPU node pool - optional)
- database-subnet: 10.0.4.0/24 (Azure Database)
- app-gateway-subnet: 10.0.5.0/24 (Application Gateway)
- bastion-subnet: 10.0.6.0/24 (Azure Bastion)
```

#### 2. AKS Cluster Configuration
```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-poc-cluster"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-poc"
  
  # Network Profile
  network_profile {
    network_plugin     = "azure"
    network_policy     = "calico"
    load_balancer_sku = "standard"
    service_cidr       = "10.0.0.0/16"
    dns_service_ip     = "10.0.0.10"
  }
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  # Default Node Pool (System)
  default_node_pool {
    name                = "systempool"
    node_count          = 2
    vm_size             = "Standard_DS2_v2"
    os_disk_size_gb     = 30
    os_disk_type        = "Premium_LRS"
    vnet_subnet_id      = azurerm_subnet.aks-system.id
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 3
    max_pods            = 110
    node_labels = {
      "nodepool-type" = "system"
    }
    taints = [
      "CriticalAddonsOnly=true:NoSchedule"
    ]
  }
  
  # Additional User Node Pool
  addon_profile {
    azure_policy {
      enabled = true
    }
    http_application_routing {
      enabled = false
    }
    oms_agent {
      enabled = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
    }
  }
  
  # RBAC
  role_based_access_control {
    enabled = true
    azure_rbac_enabled = true
  }
  
  # Azure AD Integration
  aad_profile {
    managed = true
    admin_group_object_ids = [var.azure_ad_admin_group_id]
  }
  
  # Tags
  tags = var.tags
}
```

#### 3. User Node Pool Configuration
```hcl
resource "azurerm_kubernetes_cluster_node_pool" "userpool" {
  name                = "userpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  node_count          = 2
  vm_size             = "Standard_DS3_v2"
  os_disk_size_gb     = 50
  os_disk_type        = "Premium_LRS"
  vnet_subnet_id      = azurerm_subnet.aks-user.id
  enable_auto_scaling = true
  min_count           = 2
  max_count           = 5
  max_pods            = 110
  node_labels = {
    "nodepool-type" = "user"
  }
  node_taints = []
}
```

#### 4. GPU Node Pool Configuration (Optional)
```hcl
resource "azurerm_kubernetes_cluster_node_pool" "gpupool" {
  name                = "gpupool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  node_count          = 0  # Start with 0, scale on demand
  vm_size             = "Standard_NC4as_T4_v3"  # Cost-effective GPU
  os_disk_size_gb     = 100
  os_disk_type        = "Premium_LRS"
  vnet_subnet_id      = azurerm_subnet.aks-gpu.id
  enable_auto_scaling = true
  min_count           = 0
  max_count           = 2
  max_pods            = 110
  node_labels = {
    "nodepool-type" = "gpu"
    "accelerator"   = "nvidia-tesla-t4"
  }
  node_taints = [
    "nvidia.com/gpu=true:NoSchedule"
  ]
  
  # Spot instance for cost savings
  priority = "Spot"
  eviction_policy = "Delete"
  spot_max_price = -1  # Max price = on-demand price
}
```

### Azure Container Registry Configuration
```hcl
resource "azurerm_container_registry" "acr" {
  name                = "aksPocRegistry"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = true
  
  # Network isolation
  network_rule_set {
    default_action = "Allow"
    ip_rule = []
    virtual_network_subnet_id = azurerm_subnet.aks-user.id
  }
  
  # Retention policy
  retention_policy {
    days    = 30
    enabled = true
  }
  
  # Trust policy
  trust_policy {
    enabled = true
  }
}
```

### Database Configuration (Azure PostgreSQL)
```hcl
resource "azurerm_postgresql_server" "postgres" {
  name                = "aks-poc-postgres"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  administrator_login          = var.db_admin_username
  administrator_login_password = var.db_admin_password
  
  sku_name = "GP_Gen5_2"  # General Purpose, 2 vCores
  
  storage_mb = 51200
  version   = "11"
  
  # Network
  public_network_access_enabled    = false
  ssl_enforcement_enabled          = true
  minimal_tls_version              = "TLS1_2"
  
  # Backup
  backup_retention_days = 7
  geo_redundant_backup  = false
  
  # High Availability
  create_mode               = "Default"
  point_in_time_restore_enabled = false
}

resource "azurerm_postgresql_firewall_rule" "allow_aks" {
  name                = "allow-aks"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.postgres.name
  start_ip_address    = azurerm_subnet.aks-user.address_prefix
  end_ip_address      = azurerm_subnet.aks-user.address_prefix
}

resource "azurerm_postgresql_database" "appdb" {
  name                = "appdb"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.postgres.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}
```

---

## Kubernetes Configuration

### Namespace Configuration
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    env: production
    team: platform
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    env: monitoring
    team: platform
---
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    env: gitops
    team: platform
```

### Resource Quotas
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: production
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "4"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: production
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "256Mi"
    type: Container
```

### Pod Disruption Budget
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: application-pdb
  namespace: production
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: myapp
```

### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-nginx-ingress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
```

---

## CI/CD Pipeline Architecture

### GitHub Actions Workflow Structure

#### 1. Build and Push Workflow (.github/workflows/build.yml)
```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: docker.io
  IMAGE_NAME: esarathmails/aks-poc-app

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Login to Docker Hub
      uses: docker/login-action@v2
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}
    
    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v4
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=sha,prefix={{branch}}-
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
    
    - name: Build and push
      uses: docker/build-push-action@v4
      with:
        context: ./applications/myapp
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:buildcache
        cache-to: type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:buildcache,mode=max
    
    - name: Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Upload Trivy results
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'
```

#### 2. Helm Package and Push Workflow (.github/workflows/helm.yml)
```yaml
name: Package and Push Helm Chart

on:
  push:
    paths:
      - 'helm-charts/**'
    branches: [ main ]

jobs:
  helm-package:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Set up Helm
      uses: azure/setup-helm@v1
      with:
        version: 'v3.12.0'
    
    - name: Lint Helm Chart
      run: |
        cd helm-charts/myapp
        helm lint .
    
    - name: Package Helm Chart
      run: |
        cd helm-charts
        helm package myapp
    
    - name: Login to Azure
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Push Helm Chart to ACR
      run: |
        az acr helm push -n ${{ secrets.ACR_NAME }} helm-charts/myapp-*.tgz
```

#### 3. Deploy Workflow (.github/workflows/deploy.yml)
```yaml
name: Deploy to AKS

on:
  push:
    branches: [ main ]
  workflow_dispatch:

env:
  AKS_RESOURCE_GROUP: rg-aks-poc
  AKS_CLUSTER_NAME: aks-poc-cluster
  ACR_NAME: akspocregistry

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Login to Azure
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Get AKS credentials
      run: |
        az aks get-credentials --resource-group ${{ env.AKS_RESOURCE_GROUP }} \
          --name ${{ env.AKS_CLUSTER_NAME }} --admin
    
    - name: Update ArgoCD application
      run: |
        kubectl config set-context --current --namespace=argocd
        argocd app sync myapp --server argocd-server.argocd.svc.cluster.local
      env:
        ARGOCD_AUTH_TOKEN: ${{ secrets.ARGOCD_TOKEN }}
```

### Pipeline Stages

#### Stage 1: Build and Test
- Checkout source code
- Run unit tests
- Build Docker image
- Run security scans (Trivy, Snyk)
- Push to container registry

#### Stage 2: Package
- Package Helm charts
- Validate chart syntax
- Version control chart artifacts

#### Stage 3: Deploy
- Update GitOps repository
- Trigger ArgoCD sync
- Verify deployment
- Run smoke tests

---

## GitOps Implementation

### ArgoCD Installation

#### 1. Install ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

#### 2. ArgoCD Application Configuration
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: https://github.com/esarath/aks-poc-setup.git
    targetRevision: HEAD
    path: helm-charts/myapp
    helm:
      valueFiles:
      - values-prod.yaml
  
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

#### 3. ArgoCD Project Configuration
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  description: Production applications
  sourceRepos:
  - https://github.com/esarath/aks-poc-setup.git
  
  destinations:
  - namespace: production
    server: https://kubernetes.default.svc
  - namespace: monitoring
    server: https://kubernetes.default.svc
  
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  
  namespaceResourceWhitelist:
  - group: apps
    kind: Deployment
  - group: apps
    kind: StatefulSet
  - group: apps
    kind: DaemonSet
  - group: ''
    kind: Service
  - group: ''
    kind: ConfigMap
  - group: ''
    kind: Secret
  - group: networking.k8s.io
    kind: Ingress
  - group: autoscaling
    kind: HorizontalPodAutoscaler
```

#### 4. ArgoCD Values Configuration (values-prod.yaml)
```yaml
replicaCount: 3

image:
  repository: esarathmails/aks-poc-app
  tag: "latest"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 250m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

database:
  host: "aks-poc-postgres.postgres.database.azure.com"
  port: 5432
  name: "appdb"
  sslmode: "require"

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
  - host: app.example.com
    paths:
    - path: /
      pathType: Prefix
  tls:
  - secretName: app-tls
    hosts:
    - app.example.com

nodeSelector: {}
tolerations: []
affinity: {}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - myapp
      topologyKey: kubernetes.io/hostname
```

---

## Observability Stack Configuration

### Prometheus Installation

#### 1. Prometheus Operator (Helm)
```yaml
# prometheus-values.yaml
prometheus:
  prometheusSpec:
    resources:
      requests:
        cpu: 200m
        memory: 2Gi
      limits:
        cpu: 500m
        memory: 4Gi
    
    retention: 15d
    retentionSize: 50GB
    
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorNamespaceSelectorNilUsesHelmValues: false
    
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: azure-disk
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    
    walCompression: true
    
    enableAdminAPI: false
    
    externalLabels:
      cluster: aks-poc
      env: production

alertmanager:
  enabled: true
  alertmanagerSpec:
    resources:
      requests:
        cpu: 50m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
    
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: azure-disk
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 2Gi

grafana:
  enabled: true
  adminPassword: prom-operator
  
  persistence:
    enabled: true
    storageClassName: azure-disk
    size: 10Gi
  
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi
  
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/default
  
  dashboards:
    default:
      kubernetes-cluster:
        gnetId: 7249
        revision: 1
        datasource: Prometheus
      kubernetes-pods:
        gnetId: 6417
        revision: 1
        datasource: Prometheus
      node-exporter:
        gnetId: 1860
        revision: 9
        datasource: Prometheus
```

#### 2. ServiceMonitor Configuration
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-monitor
  namespace: production
  labels:
    app: myapp
spec:
  selector:
    matchLabels:
      app: myapp
  namespaceSelector:
    matchNames:
    - production
  endpoints:
  - port: http
    interval: 30s
    path: /metrics
    scheme: http
```

#### 3. Prometheus Rules
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: myapp-alerts
  namespace: production
spec:
  groups:
  - name: myapp.rules
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{job="myapp",status=~"5.."}[5m]) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value }} errors/second"
    
    - alert: HighLatency
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="myapp"}[5m])) > 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High latency detected"
        description: "95th percentile latency is {{ $value }}s"
    
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total{namespace="production",pod=~"myapp-.*"}[15m]) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod is crash looping"
        description: "Pod {{ $labels.pod }} is crash looping"
```

### Azure Monitor Integration

#### 1. Azure Monitor Container Insights
```hcl
resource "azurerm_log_analytics_workspace" "main" {
  name                = "aks-poc-log-analytics"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_log_analytics_linked_service" "aks" {
  resource_group_name = var.resource_group_name
  workspace_name      = azurerm_log_analytics_workspace.main.name
  linked_service_name = "aks"
  resource_id         = azurerm_kubernetes_cluster.aks.id
}
```

#### 2. Prometheus Scraping Configuration
```hcl
resource "azurerm_kubernetes_cluster_extension" "monitor" {
  name                  = "azure-monitor"
  cluster_name          = azurerm_kubernetes_cluster.aks.name
  resource_group_name   = var.resource_group_name
  extension_type        = "Microsoft.AzureMonitor.Containers"
  plan {
    name = "azure-monitor"
    publisher = "Microsoft"
    product = "azure-monitor-containers"
  }
  
  configuration_settings = {
    "enableMicrosoftAzureMonitorReceiver" = "true"
    "destinationsOutputName" = "MyMonitorWorkspace"
  }
}
```

### Grafana Dashboard Configuration

#### 1. Custom Dashboard JSON
```json
{
  "dashboard": {
    "title": "AKS Application Dashboard",
    "uid": "aks-app-dashboard",
    "tags": ["aks", "production"],
    "timezone": "browser",
    "schemaVersion": 16,
    "version": 0,
    "refresh": "30s",
    "panels": [
      {
        "id": 1,
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total{job=\"myapp\"}[5m])",
            "legendFormat": "{{status}}"
          }
        ]
      },
      {
        "id": 2,
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total{job=\"myapp\",status=~\"5..\"}[5m])",
            "legendFormat": "5xx errors"
          }
        ]
      },
      {
        "id": 3,
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job=\"myapp\"}[5m]))",
            "legendFormat": "95th percentile"
          }
        ]
      }
    ]
  }
}
```

---

## Network Configuration

### NGINX Ingress Controller

#### 1. Installation
```yaml
# nginx-ingress-values.yaml
controller:
  replicaCount: 3
  
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  
  service:
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "false"
    loadBalancerIP: ""  # Leave empty for dynamic IP
  
  # TLS configuration
  extraArgs:
    default-ssl-certificate: "ingress-nginx/default-tls"
  
  # Metrics
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
  
  # ConfigMap for nginx.conf
  config:
    use-forwarded-headers: "true"
    compute-full-forwarded-for: "true"
    use-proxy-protocol: "true"
    
  # Admission Webhooks
  admissionWebhooks:
    enabled: true
    patch:
      enabled: true
```

#### 2. Ingress Configuration
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/limit-rps: "100"
    nginx.ingress.kubernetes.io/limit-connections: "50"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.com
    secretName: myapp-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 8080
```

---

## Security Implementation

### Azure Key Vault Integration
```hcl
resource "azurerm_key_vault" "kv" {
  name                = "aks-poc-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  
  enabled_for_deployment     = true
  enabled_for_disk_encryption = true
  enabled_for_template_deployment = true
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    
    key_permissions = [
      "Get", "List", "Create", "Delete", "Update"
    ]
    
    secret_permissions = [
      "Get", "List", "Set", "Delete"
    ]
    
    certificate_permissions = [
      "Get", "List", "Create", "Delete"
    ]
  }
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "database-password"
  value        = var.db_admin_password
  key_vault_id = azurerm_key_vault.kv.id
}
```

### Kubernetes Secrets Store CSI Driver
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: azure-keyvault-provider
  namespace: production
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "${USER_ASSIGNED_IDENTITY_ID}"
    keyvaultName: "aks-poc-kv"
    objects: |
      array:
        - |
          objectName: database-password
          objectType: secret
          objectVersion: ""
    tenantId: "${TENANT_ID}"
  secretObjects:
  - secretName: db-secret
    type: Opaque
    data:
    - objectName: database-password
      key: password
```

### Pod Security Policies
```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
  - ALL
  volumes:
  - 'configMap'
  - 'emptyDir'
  - 'projected'
  - 'secret'
  - 'downwardAPI'
  - 'persistentVolumeClaim'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'RunAsAny'
  readOnlyRootFilesystem: false
```

---

## Storage Configuration

### Storage Classes
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-disk-standard
provisioner: kubernetes.io/azure-disk
parameters:
  storageaccounttype: Standard_LRS
  kind: Managed
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-disk-premium
provisioner: kubernetes.io/azure-disk
parameters:
  storageaccounttype: Premium_LRS
  kind: Managed
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-files-premium
provisioner: kubernetes.io/azure-file
parameters:
  storageaccounttype: Premium_LRS
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

### Persistent Volume Claims
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-data
  namespace: production
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: azure-disk-premium
  resources:
    requests:
      storage: 10Gi
```

---

## GPU Workload Configuration

### GPU Node Pool Setup
```hcl
# Cost-effective GPU configuration
resource "azurerm_kubernetes_cluster_node_pool" "gpu" {
  name                = "gpu"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  node_count          = 0  # Start with 0 nodes
  vm_size             = "Standard_NC4as_T4_v3"  # NVIDIA T4 GPU
  os_disk_size_gb     = 100
  os_disk_type        = "Premium_LRS"
  vnet_subnet_id      = azurerm_subnet.aks-gpu.id
  
  enable_auto_scaling = true
  min_count           = 0
  max_count           = 2
  
  priority            = "Spot"  # Use spot instances for cost savings
  eviction_policy     = "Delete"
  spot_max_price      = -1
  
  node_labels = {
    "accelerator" = "nvidia-tesla-t4"
    "gpu-node"     = "true"
  }
  
  node_taints = [
    "nvidia.com/gpu=true:NoSchedule"
  ]
}
```

### NVIDIA Device Plugin
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: nvidia-device-plugin-ds
  template:
    metadata:
      labels:
        name: nvidia-device-plugin-ds
    spec:
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - image: nvcr.io/nvidia/k8s-device-plugin:v0.14.0
        name: nvidia-device-plugin
        resources:
          limits:
            nvidia.com/gpu: 1
        volumeMounts:
        - name: device-plugin
          mountPath: /var/lib/kubelet/pods
      volumes:
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/pods
      nodeSelector:
        accelerator: nvidia-tesla-t4
```

### GPU Monitoring
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nvidia-dcgm-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: nvidia-dcgm-exporter
  namespaceSelector:
    matchNames:
    - kube-system
  endpoints:
  - port: metrics
    interval: 15s
```

### Sample GPU Application
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tensorflow-gpu
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tensorflow-gpu
  template:
    metadata:
      labels:
        app: tensorflow-gpu
    spec:
      containers:
      - name: tensorflow
        image: tensorflow/tensorflow:latest-gpu
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: "8Gi"
            cpu: "4"
          requests:
            nvidia.com/gpu: 1
            memory: "4Gi"
            cpu: "2"
        command: ["python"]
        args: ["-c", "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"]
      nodeSelector:
        gpu-node: "true"
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
```

### Cost-Effective GPU Alternatives

#### Option 1: Azure Spot Instances
- Use `Standard_NC4as_T4_v3` spot instances
- Up to 90% cost savings compared to on-demand
- Suitable for batch processing and training jobs

#### Option 2: Local GPU Testing
```bash
# Install kind with GPU support
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create cluster with GPU support
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
  extraMounts:
  - containerPath: /dev/nvidiactl
    hostPath: /dev/nvidiactl
  - containerPath: /dev/nvidia-uvm
    hostPath: /dev/nvidia-uvm
  - containerPath: /dev/nvidia-uvm-tools
    hostPath: /dev/nvidia-uvm-tools
  - containerPath: /dev/nvidia-modeset
    hostPath: /dev/nvidia-modeset
  - containerPath: /dev/nvidia
    hostPath: /dev/nvidia
EOF

kind create cluster --config=kind-config.yaml
```

#### Option 3: Smaller GPU Instances
```hcl
# Use smaller GPU VM for development
resource "azurerm_kubernetes_cluster_node_pool" "gpu-dev" {
  vm_size = "Standard_NC4as_T4_v3"  # 1x T4 GPU
  node_count = 1
  # Reduced specs for cost savings
}
```

---

## Application Deployment Architecture

### Sample Application Structure
```
applications/myapp/
├── Dockerfile
├── requirements.txt
├── app.py
├── tests/
│   └── test_app.py
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
└── config/
    └── config.yaml
```

### Dockerfile
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .
COPY config/ ./config/

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Run application
CMD ["python", "app.py"]
```

### Sample Python Application
```python
from flask import Flask, jsonify
import os
import psycopg2
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)
metrics = PrometheusMetrics(app)

# Database configuration
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_NAME = os.getenv('DB_NAME', 'appdb')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASSWORD = os.getenv('DB_PASSWORD', '')

def get_db_connection():
    conn = psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )
    return conn

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'}), 200

@app.route('/api/data')
def get_data():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT * FROM data LIMIT 10')
        results = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify({'data': results}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/metrics')
def metrics():
    return metrics.generate_latest()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

### Requirements.txt
```
flask==3.0.0
psycopg2-binary==2.9.9
prometheus-flask-exporter==0.22.4
gunicorn==21.2.0
```

### Helm Chart Structure
```
helm-charts/myapp/
├── Chart.yaml
├── values.yaml
├── values-prod.yaml
├── values-dev.yaml
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── hpa.yaml
    ├── pdb.yaml
    └── serviceaccount.yaml
```

### Helm Chart Values
```yaml
# values.yaml
replicaCount: 2

image:
  repository: esarathmails/aks-poc-app
  pullPolicy: IfNotPresent
  tag: "latest"

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations: {}
  name: ""

podAnnotations: {}

podSecurityContext: {}
securityContext: {}

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: false
  className: "nginx"
  annotations: {}
  hosts: []
  tls: []

resources: {}
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity: {}
```

---

## Deployment Procedures

### Initial Infrastructure Setup
```bash
# 1. Initialize Terraform
cd terraform
terraform init

# 2. Validate configuration
terraform validate

# 3. Plan infrastructure
terraform plan -out=tfplan

# 4. Apply infrastructure
terraform apply tfplan

# 5. Get AKS credentials
az aks get-credentials --resource-group rg-aks-poc --name aks-poc-cluster --admin

# 6. Verify cluster
kubectl get nodes
kubectl get namespaces
```

### Application Deployment
```bash
# 1. Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# 2. Install ingress controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  -f nginx-ingress-values.yaml -n ingress-nginx --create-namespace

# 3. Install monitoring stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  -f prometheus-values.yaml -n monitoring --create-namespace

# 4. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 5. Deploy application via Helm
helm install myapp ./helm-charts/myapp -f ./helm-charts/myapp/values-prod.yaml -n production

# 6. Verify deployment
kubectl get pods -n production
kubectl get services -n production
```

---

## Monitoring and Troubleshooting

### Common Issues and Solutions

#### 1. Pod Not Starting
```bash
# Check pod status
kubectl describe pod <pod-name> -n production

# Check logs
kubectl logs <pod-name> -n production

# Check events
kubectl get events -n production --sort-by='.lastTimestamp'
```

#### 2. Image Pull Errors
```bash
# Check image pull secrets
kubectl get secrets -n production

# Create image pull secret if needed
kubectl create secret docker-registry regcred \
  --docker-server=docker.io \
  --docker-username=esarathmails \
  --docker-password=<password> \
  -n production
```

#### 3. Network Connectivity
```bash
# Test pod connectivity
kubectl exec -it <pod-name> -n production -- ping google.com

# Check service endpoints
kubectl get endpoints -n production

# Check network policies
kubectl get networkpolicies -n production
```

### Performance Tuning

#### 1. Cluster Autoscaling
```yaml
# Enable cluster autoscaler
az aks update \
  --resource-group rg-aks-poc \
  --name aks-poc-cluster \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 10
```

#### 2. Pod Resource Optimization
```yaml
# Adjust resource requests/limits
resources:
  requests:
    cpu: "100m"    # Adjust based on actual usage
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

---

## Cost Management

### Cost Optimization Strategies

#### 1. Right-Sizing
```bash
# Monitor resource utilization
kubectl top nodes
kubectl top pods -n production

# Adjust node sizes accordingly
```

#### 2. Schedules
```yaml
# Scale down during off-hours
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

#### 3. Reserved Instances
```bash
# Purchase reserved instances for long-running workloads
az reservation order create \
  --reservation-order-name aks-poc-reservation \
  --reserved-type VirtualMachines \
  --sku Standard_DS3_v2 \
  --location eastus \
  --quantity 2 \
  --billing-scope /subscriptions/7908ea24-a708-4291-be15-98426e3e9ca5 \
  --term P1Y  # 1-year term
```

---

## Appendix

### A. Environment Variables
```bash
# Azure Configuration
export AZURE_SUBSCRIPTION_ID="7908ea24-a708-4291-be15-98426e3e9ca5"
export AZURE_RESOURCE_GROUP="rg-aks-poc"
export AZURE_LOCATION="eastus"
export AKS_CLUSTER_NAME="aks-poc-cluster"

# Docker Configuration
export DOCKER_REGISTRY="docker.io"
export DOCKER_USERNAME="esarathmails"

# GitHub Configuration
export GITHUB_REPO="esarath/aks-poc-setup"
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
```

### B. Useful Commands
```bash
# Terraform
terraform fmt -recursive
terraform init -upgrade
terraform plan -destroy

# Kubernetes
kubectl get all -n production
kubectl describe deployment myapp -n production
kubectl rollout status deployment/myapp -n production
kubectl rollout undo deployment/myapp -n production

# ArgoCD
argocd app list
argocd app get myapp
argocd app sync myapp

# Azure
az aks list --resource-group rg-aks-poc
az monitor metrics list --resource /subscriptions/.../resourceGroups/.../providers/Microsoft.ContainerService/managedClusters/aks-poc-cluster
```

---
**Document Status**: Draft
**Last Updated**: 2026-05-31
**Next Review**: After infrastructure deployment