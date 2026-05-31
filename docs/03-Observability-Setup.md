# Observability Stack Setup Guide

## Overview
This document provides detailed instructions for setting up the complete observability stack including Prometheus, Grafana, Azure Monitor, and related components for the AKS POC environment.

## Components
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Azure Monitor**: Cloud-native monitoring
- **Loki**: Log aggregation (optional)
- **Tempo**: Distributed tracing (optional)
- **Alertmanager**: Alert management

## Prerequisites
- AKS cluster deployed and accessible
- kubectl configured
- Helm 3.x installed
- Sufficient cluster resources (minimum 2 CPUs, 4GB RAM for monitoring stack)

## Installation Steps

### 1. Create Monitoring Namespace
```bash
kubectl create namespace monitoring
```

### 2. Add Helm Repositories
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### 3. Install kube-prometheus-stack
The kube-prometheus-stack includes Prometheus, Grafana, Alertmanager, and default dashboards.

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values observability/prometheus-values.yaml \
  --timeout 10m
```

### 4. Verify Installation
```bash
# Check pods
kubectl get pods -n monitoring

# Check services
kubectl get svc -n monitoring

# Check Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090

# Check Grafana
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
```

### 5. Configure Azure Monitor Integration
```bash
# Enable Azure Monitor for containers
az aks update \
  --resource-group rg-aks-poc \
  --name aks-poc-cluster \
  --enable-container-insights \
  --workspace-resource-id /subscriptions/7908ea24-a708-4291-be15-98426e3e9ca5/resourceGroups/rg-aks-poc/providers/Microsoft.OperationalInsights/workspaces/aks-poc-log-analytics
```

### 6. Access Grafana
```bash
# Get Grafana admin password
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Port forward to access Grafana
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
```

Default credentials:
- Username: `admin`
- Password: Retrieved from secret

## Configuration Files

### Prometheus Values Configuration
```yaml
# observability/prometheus-values.yaml
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
    
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: azure-disk
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

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

grafana:
  enabled: true
  adminPassword: "change-me-in-production"
  
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

kube-state-metrics:
  enabled: true
```

## ServiceMonitor Configuration

### Application ServiceMonitor
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

### Prometheus Alerting Rules
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: myapp-alerts
  namespace: monitoring
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

## Azure Monitor Configuration

### Enable Container Insights
```bash
az aks update \
  --resource-group rg-aks-poc \
  --name aks-poc-cluster \
  --enable-container-insights
```

### Configure Azure Monitor Alerts
```bash
# Create an action group for alerts
az monitor action-group create \
  --name "aks-poc-action-group" \
  --resource-group rg-aks-poc \
  --short-name "akspocag" \
  --email admin@example.com

# Create an alert rule for CPU usage
az monitor metrics alert create \
  --name "high-cpu-usage" \
  --resource /subscriptions/7908ea24-a708-4291-be15-98426e3e9ca5/resourceGroups/rg-aks-poc/providers/Microsoft.ContainerService/managedClusters/aks-poc-cluster \
  --resource-type Microsoft.ContainerService/managedClusters \
  --condition "percentageCpu > 80" \
  --description "Alert when CPU usage exceeds 80%" \
  --action-group /subscriptions/7908ea24-a708-4291-be15-98426e3e9ca5/resourceGroups/rg-aks-poc/providers/microsoft.insights/actionGroups/aks-poc-action-group
```

## Grafana Dashboard Configuration

### Import Custom Dashboard
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
      }
    ]
  }
}
```

## Log Aggregation (Optional - Loki)

### Install Loki
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=20Gi \
  --set promtail.enabled=true
```

## Distributed Tracing (Optional - Tempo)

### Install Tempo
```bash
helm install tempo grafana/tempo \
  --namespace monitoring \
  --values observability/tempo-values.yaml
```

## Telemetry and Metrics Collection

### Application Metrics Export
```python
# Add to your application
from prometheus_client import start_http_server, Counter, Histogram

# Define metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'HTTP request latency')

# Expose metrics endpoint
start_http_server(8000)
```

## Monitoring Best Practices

### 1. Resource Limits
- Set appropriate resource requests and limits for monitoring components
- Use dedicated node pools for monitoring workloads
- Monitor the monitoring stack itself

### 2. Data Retention
- Configure appropriate retention periods based on requirements
- Implement data archiving for long-term storage
- Clean up old metrics and logs regularly

### 3. Alert Management
- Configure alert thresholds carefully to avoid fatigue
- Use alert severity levels (critical, warning, info)
- Implement on-call rotation and escalation policies

### 4. Dashboard Management
- Create role-specific dashboards
- Document dashboard purpose and usage
- Regular dashboard review and maintenance

### 5. Security
- Enable authentication for Grafana
- Use RBAC for access control
- Secure Prometheus endpoints
- Implement network policies

## Troubleshooting

### Prometheus Not Scraping Metrics
```bash
# Check ServiceMonitor configuration
kubectl get servicemonitor -A

# Check Prometheus targets
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090
# Open http://localhost:9090/targets
```

### Grafana Not Showing Data
```bash
# Check datasource configuration
kubectl get configmap -n monitoring prometheus-grafana -o yaml

# Verify Prometheus connection
kubectl exec -it -n monitoring prometheus-kube-prometheus-prometheus-0 -- prometheus-cli check-config
```

### High Memory Usage
```bash
# Check resource usage
kubectl top pods -n monitoring

# Adjust resource limits in values.yaml
# Restart deployment
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values observability/prometheus-values.yaml
```

## Next Steps
1. Configure custom dashboards for specific applications
2. Set up alert notifications (Slack, Teams, PagerDuty)
3. Implement log aggregation with Loki
4. Set up distributed tracing with Tempo
5. Configure automatic cleanup and retention policies
6. Integrate with Azure Security Center for advanced security monitoring

---
**Document Status**: Draft
**Last Updated**: 2026-05-31
**Next Review**: After initial deployment