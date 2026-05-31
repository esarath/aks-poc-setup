# Load Balancer and Ingress Configuration Guide

## Overview
This document provides detailed instructions for configuring load balancers and ingress controllers for the AKS POC environment, including NGINX Ingress Controller, SSL/TLS configuration, and traffic routing.

## Architecture
```
Internet → Azure Load Balancer → NGINX Ingress Controller → Kubernetes Services → Pods
```

## Components
- **Azure Load Balancer**: External traffic distribution
- **NGINX Ingress Controller**: Layer 7 routing, SSL termination
- **Cert-Manager**: Automatic SSL certificate management
- **Application Gateway** (optional): WAF protection and advanced routing

## Installation Steps

### 1. Create Ingress Namespace
```bash
kubectl create namespace ingress-nginx
```

### 2. Add NGINX Ingress Repository
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

### 3. Install NGINX Ingress Controller
```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --values observability/nginx-ingress-values.yaml \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal"="false"
```

### 4. Verify Installation
```bash
# Check ingress controller pods
kubectl get pods -n ingress-nginx

# Check services
kubectl get svc -n ingress-nginx

# Get external IP
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

## Configuration Files

### NGINX Ingress Values
```yaml
# observability/nginx-ingress-values.yaml
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
      service.beta.kubernetes.io/azure-load-balancer-ipv4: "true"
    loadBalancerIP: ""  # Leave empty for dynamic IP
  
  # NGINX configuration
  config:
    use-forwarded-headers: "true"
    compute-full-forwarded-for: "true"
    use-proxy-protocol: "true"
    hide-headers: "X-Powered-By,Server"
    server-tokens: "false"
    
  # Admission Webhooks
  admissionWebhooks:
    enabled: true
    patch:
      enabled: true
  
  # Metrics
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      namespace: monitoring
  
  # Pod security context
  podSecurityContext:
    runAsUser: 101
    fsGroup: 101
  
  # Liveness and readiness probes
  livenessProbe:
    failureThreshold: 5
    initialDelaySeconds: 30
    periodSeconds: 10
    successThreshold: 1
    timeoutSeconds: 5
  
  readinessProbe:
    failureThreshold: 3
    initialDelaySeconds: 10
    periodSeconds: 10
    successThreshold: 1
    timeoutSeconds: 1

# RBAC
rbac:
  create: true

# Service account
serviceAccount:
  create: true
```

### Custom Ingress Configuration
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
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "15"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "15"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "15"
    nginx.ingress.kubernetes.io/proxy-buffer-size: "16k"
    nginx.ingress.kubernetes.io/proxy-buffers-number: "4"
    nginx.ingress.kubernetes.io/client-body-buffer-size: "128k"
    nginx.ingress.kubernetes.io/from-to-www-redirect: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-headers: "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization"
    nginx.ingress.kubernetes.io/cors-max-age: "3600"
    nginx.ingress.kubernetes.io/enable-modsecurity: "true"
    nginx.ingress.kubernetes.io/modsecurity-snippet: |
      SecRuleEngine On
      SecAuditEngine RelevantOnly
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
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 8080
```

## SSL/TLS Configuration with Cert-Manager

### 1. Install Cert-Manager
```bash
# Add Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.1 \
  --set installCRDs=true

# Verify installation
kubectl get pods -n cert-manager
kubectl get crds | grep cert-manager
```

### 2. Create Let's Encrypt Cluster Issuer
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-staging-private-key
    solvers:
    - http01:
        ingress:
          class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-private-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

### 3. Test SSL Configuration
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-certificate
  namespace: production
spec:
  secretName: test-tls
  dnsNames:
  - test.example.com
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
```

## Application Gateway Integration (Optional)

### 1. Enable Application Gateway
```hcl
# Add to main.tf
resource "azurerm_application_gateway" "main" {
  name                = "aks-poc-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }
  
  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.app_gateway.id
  }
  
  frontend_port {
    name = "http-port"
    port = 80
  }
  
  frontend_port {
    name = "https-port"
    port = 443
  }
  
  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.app_gateway.id
  }
  
  backend_address_pool {
    name = "aks-backend-pool"
  }
  
  backend_http_settings {
    name                  = "aks-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }
  
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }
  
  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "aks-backend-pool"
    backend_http_settings_name = "aks-http-settings"
  }
  
  tags = var.tags
}
```

### 2. Configure AGIC (Application Gateway Ingress Controller)
```bash
# Install AGIC
helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update

helm install ingress-azure application-gateway-kubernetes-ingress/ingress-azure \
  --namespace ingress-azure \
  --set appgw.name=aks-poc-appgw \
  --set appgw.resourceGroup=rg-aks-poc \
  --set appgw.subscriptionId=7908ea24-a708-4291-be15-98426e3e9ca5 \
  --set appgw.shared=true
```

## Ingress Controllers Comparison

### NGINX Ingress Controller
**Pros:**
- Open source and community-driven
- Extensive documentation and community support
- Rich feature set and customization options
- High performance and stability
- Wide adoption and proven track record

**Cons:**
- Limited built-in WAF capabilities
- Requires additional components for advanced features

### Azure Application Gateway
**Pros:**
- Native Azure integration
- Built-in WAF protection
- Global load balancing
- Automatic SSL certificate management
- Centralized management

**Cons:**
- Higher cost
- Limited customization options
- Azure-specific features only

## Load Balancing Strategies

### 1. Round Robin (Default)
```yaml
nginx.ingress.kubernetes.io/upstream-hash-by: "$remote_addr"
```

### 2. IP Hash
```yaml
nginx.ingress.kubernetes.io/upstream-hash-by: "$binary_remote_addr"
```

### 3. Least Connections
```yaml
nginx.ingress.kubernetes.io/load-balance: "least_conn"
```

## Rate Limiting Configuration

### Per-IP Rate Limiting
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "50"
    nginx.ingress.kubernetes.io/limit-connections: "20"
    nginx.ingress.kubernetes.io/limit-burst: "10"
```

### Global Rate Limiting
```yaml
# In NGINX Ingress Controller values.yaml
controller:
  config:
    limit-req-status-code: "429"
    limit-connections-status-code: "429"
```

## Security Configuration

### WAF Rules
```yaml
nginx.ingress.kubernetes.io/modsecurity-enable: "true"
nginx.ingress.kubernetes.io/modsecurity-snippet: |
  SecRuleEngine On
  SecRuleRemoveById 911100
  SecRuleRemoveById 910000
  SecRuleRemoveById 950109
```

### IP Whitelisting/Blacklisting
```yaml
nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
nginx.ingress.kubernetes.io/denylist-source-range: "192.0.2.0/24"
```

### Authentication
```yaml
nginx.ingress.kubernetes.io/auth-type: "basic"
nginx.ingress.kubernetes.io/auth-secret: "basic-auth"
nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
```

## Monitoring and Telemetry

### NGINX Metrics Exporter
```bash
# Enable metrics in values.yaml
controller:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      namespace: monitoring
```

### Prometheus ServiceMonitor
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nginx-ingress
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
  namespaceSelector:
    matchNames:
    - ingress-nginx
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

## Performance Optimization

### 1. Connection Pooling
```yaml
nginx.ingress.kubernetes.io/proxy-connect-timeout: "15"
nginx.ingress.kubernetes.io/proxy-send-timeout: "15"
nginx.ingress.kubernetes.io/proxy-read-timeout: "15"
```

### 2. Buffering Configuration
```yaml
nginx.ingress.kubernetes.io/proxy-buffer-size: "16k"
nginx.ingress.kubernetes.io/proxy-buffers-number: "4"
```

### 3. HTTP/2 Support
```yaml
nginx.ingress.kubernetes.io/use-http2: "true"
```

## Troubleshooting

### Check Ingress Controller Logs
```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100
```

### Test Ingress Configuration
```bash
# Describe ingress
kubectl describe ingress myapp-ingress -n production

# Check nginx config
kubectl exec -it -n ingress-nginx nginx-ingress-controller-xxx -- /nginx-ingress-controller --version
```

### Verify SSL Certificate
```bash
# Check certificate
kubectl describe certificate myapp-tls -n production

# Check secret
kubectl get secret myapp-tls -n production -o yaml
```

### Test Connectivity
```bash
# Port forward to test
kubectl port-forward -n production svc/myapp 8080:8080

# Test with curl
curl -v http://app.example.com/health
```

## Best Practices

1. **SSL/TLS**: Always use HTTPS in production
2. **Security**: Enable WAF and rate limiting
3. **Monitoring**: Monitor ingress controller metrics
4. **High Availability**: Use at least 3 replicas
5. **Resource Limits**: Set appropriate CPU/memory limits
6. **Documentation**: Document ingress rules and configurations
7. **Testing**: Test configuration changes in staging first
8. **Backup**: Keep backups of ingress configurations
9. **Version Control**: Store ingress configs in Git
10. **Regular Updates**: Keep ingress controller updated

---
**Document Status**: Draft
**Last Updated**: 2026-05-31
**Next Review**: After initial deployment