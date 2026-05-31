# GPU Workloads Setup Guide - Cost-Effective Alternatives

## Overview
This document provides detailed guidance for setting up GPU workloads on AKS with cost-effective alternatives, as the free Azure subscription tier has limitations. The guide covers GPU node pool configuration, alternative approaches, and optimization strategies.

## Why GPU Workloads?
GPU workloads are essential for:
- Machine Learning and AI model training
- Deep learning inference
- Data processing and analytics
- Computer vision tasks
- High-performance computing (HPC)

## Cost-Effective GPU Alternatives

### 1. Azure Spot Instances (Recommended)
**Description**: Azure Spot Instances allow you to use spare Azure capacity at significant discounts (up to 90% off).

**Pros**:
- Massive cost savings (up to 90%)
- No upfront commitment
- Suitable for batch processing and training jobs

**Cons**:
- Instances can be preempted with short notice
- Not suitable for latency-sensitive workloads
- Requires checkpointing and fault tolerance

**Implementation**:
```hcl
resource "azurerm_kubernetes_cluster_node_pool" "gpu_spot" {
  name                = "gpu-spot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  node_count          = 0  # Start with 0 nodes
  vm_size             = "Standard_NC4as_T4_v3"  # NVIDIA T4 GPU
  os_disk_size_gb     = 100
  os_disk_type        = "Premium_LRS"
  vnet_subnet_id      = azurerm_subnet.aks-gpu.id
  
  enable_auto_scaling = true
  min_count           = 0
  max_count           = 2
  
  # Spot instance configuration
  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1  # Maximum price = on-demand price
  
  node_labels = {
    "accelerator" = "nvidia-tesla-t4"
    "gpu-node"     = "true"
    "spot"         = "true"
  }
  
  node_taints = [
    "nvidia.com/gpu=true:NoSchedule",
    "spot=true:NoSchedule"
  ]
}
```

### 2. Azure VM Scale Sets with Flexible Orchestration
**Description**: Use VM Scale Sets with flexible orchestration for GPU VMs, allowing more control over individual VMs.

**Pros**:
- Individual VM management
- Better control over placement
- Supports both spot and regular instances
- Custom scaling policies

**Cons**:
- More complex setup
- Manual AKS integration
- Higher management overhead

**Implementation**:
```hcl
resource "azurerm_linux_virtual_machine_scale_set" "gpu_vmss" {
  name                = "gpu-vmss"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard_NC4as_T4_v3"
  instances           = 1
  admin_username      = "azureuser"
  
  network_interface {
    name    = "gpu-vmss-nic"
    subnet_id = azurerm_subnet.aks-gpu.id
  }
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-DataCenter-smalldisk"
    version   = "latest"
  }
  
  # Spot instance configuration
  priority           = "Spot"
  eviction_policy     = "Delete"
  max_bid_price       = -1
  
  # Auto-scaling
  automatic_os_upgrade_policy {
    disable_automatic_rollback  = true
    enable_automatic_os_upgrade = true
  }
}
```

### 3. Cost-Effective GPU VM Options

#### NVIDIA T4 (Most Cost-Effective)
**VM Size**: `Standard_NC4as_T4_v3`
- **GPU**: 1x NVIDIA T4 (16GB)
- **vCPUs**: 4
- **RAM**: 28GB
- **Cost**: ~$0.50/hour on-demand, ~$0.05/hour spot

**Best For**: Inference, small-scale training, data processing

#### NVIDIA V100 (High Performance)
**VM Size**: `Standard_NC6s_v3`
- **GPU**: 1x NVIDIA V100 (16GB)
- **vCPUs**: 6
- **RAM**: 112GB
- **Cost**: ~$3.06/hour on-demand, ~$0.30/hour spot

**Best For**: Medium-scale training, demanding inference

#### NVIDIA A100 (Enterprise)
**VM Size**: `Standard_ND96amsr_A100_v4`
- **GPU**: 8x NVIDIA A100 (40GB each)
- **vCPUs**: 96
- **RAM**: 900GB
- **Cost**: ~$27.00/hour on-demand

**Best For**: Large-scale training, enterprise workloads

### 4. Local GPU Testing (Free Option)
**Description**: Use local GPU hardware for testing and development before cloud deployment.

**Pros**:
- Completely free if hardware is available
- Fast development iteration
- No cloud latency
- Full control over environment

**Cons**:
- Limited to available hardware
- Not production-ready
- Requires manual environment setup
- Scaling limitations

**Implementation**:
```bash
# Install Kubernetes with GPU support (using kind)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create GPU-enabled kind cluster
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

### 5. Hybrid Cloud Approach
**Description**: Use cloud GPU resources for peak demand and local resources for baseline workloads.

**Pros**:
- Optimal cost efficiency
- Flexible resource allocation
- Redundancy and disaster recovery
- Compliance with data residency

**Cons**:
- Complex architecture
- Network connectivity challenges
- Management overhead

## GPU Node Pool Setup on AKS

### Terraform Configuration
```hcl
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
  
  priority        = "Spot"  # Use spot instances
  eviction_policy = "Delete"
  spot_max_price  = -1
  
  node_labels = {
    "accelerator" = "nvidia-tesla-t4"
    "gpu-node"     = "true"
    "workload"     = "ml"
  }
  
  node_taints = [
    "nvidia.com/gpu=true:NoSchedule"
  ]
}
```

### NVIDIA Device Plugin Installation
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

## Sample GPU Workload Deployments

### 1. TensorFlow GPU Application
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
        command: ["python"]
        args: ["-c", "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"]
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: "8Gi"
            cpu: "4"
          requests:
            nvidia.com/gpu: 1
            memory: "4Gi"
            cpu: "2"
        volumeMounts:
        - name: dshm
          mountPath: /dev/shm
      nodeSelector:
        gpu-node: "true"
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      - key: spot
        operator: Exists
        effect: NoSchedule
      volumes:
      - name: dshm
        emptyDir:
          medium: Memory
```

### 2. PyTorch Training Job
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pytorch-training
  namespace: production
spec:
  template:
    spec:
      containers:
      - name: pytorch
        image: pytorch/pytorch:latest
        command: ["python", "-u", "train.py"]
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: "16Gi"
            cpu: "8"
          requests:
            nvidia.com/gpu: 1
            memory: "8Gi"
            cpu: "4"
        env:
        - name: PYTHONUNBUFFERED
          value: "1"
        - name: CUDA_VISIBLE_DEVICES
          value: "0"
      restartPolicy: OnFailure
      nodeSelector:
        gpu-node: "true"
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
```

### 3. GPU Monitoring Pod
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-dcgm-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: nvidia-dcgm-exporter
  template:
    metadata:
      labels:
        app: nvidia-dcgm-exporter
    spec:
      containers:
      - name: dcgm-exporter
        image: nvidia/dcgm-exporter:3.1.8-3.1.5-ubuntu20.04
        resources:
          limits:
            memory: "128Mi"
            cpu: "100m"
          requests:
            memory: "64Mi"
            cpu: "50m"
        ports:
        - containerPort: 9400
          name: metrics
      nodeSelector:
        gpu-node: "true"
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
```

## GPU Monitoring

### DCGM Exporter ServiceMonitor
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
    - monitoring
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
```

### Grafana Dashboard for GPU Metrics
```json
{
  "dashboard": {
    "title": "GPU Workload Dashboard",
    "uid": "gpu-dashboard",
    "tags": ["gpu", "nvidia", "ml"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "GPU Utilization",
        "type": "graph",
        "targets": [
          {
            "expr": "DCGM_FI_DEV_GPU_UTIL",
            "legendFormat": "{{gpu}}"
          }
        ]
      },
      {
        "id": 2,
        "title": "GPU Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "DCGM_FI_DEV_FB_USED",
            "legendFormat": "{{gpu}}"
          }
        ]
      },
      {
        "id": 3,
        "title": "GPU Temperature",
        "type": "graph",
        "targets": [
          {
            "expr": "DCGM_FI_DEV_GPU_TEMP",
            "legendFormat": "{{gpu}}"
          }
        ]
      }
    ]
  }
}
```

## Cost Optimization Strategies

### 1. Scaling Policies
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: gpu-workloads-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: gpu-workload
  minReplicas: 0
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: nvidia.com/gpu
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
```

### 2. Scheduled Scaling
```yaml
apiVersion: autoscaling/v2
kind: CronHorizontalPodAutoscaler
metadata:
  name: gpu-scheduled-scaler
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: gpu-workload
  jobs:
  - name: "scale-up-during-business-hours"
    schedule: "0 9 * * 1-5"
    targetSize: 2
  - name: "scale-down-after-hours"
    schedule: "0 18 * * 1-5"
    targetSize: 0
  - name: "scale-down-weekend"
    schedule: "0 0 * * 0,6"
    targetSize: 0
```

### 3. Resource Management
```yaml
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  name: gpu-workload-pdb
  namespace: production
spec:
  minAvailable: 0
  selector:
    matchLabels:
      app: gpu-workload
```

## Best Practices

### 1. Checkpointing and Fault Tolerance
```python
# Example: PyTorch checkpointing
import torch
import os

def save_checkpoint(model, optimizer, epoch, filename):
    torch.save({
        'epoch': epoch,
        'model_state_dict': model.state_dict(),
        'optimizer_state_dict': optimizer.state_dict(),
    }, filename)

def load_checkpoint(filename, model, optimizer):
    checkpoint = torch.load(filename)
    model.load_state_dict(checkpoint['model_state_dict'])
    optimizer.load_state_dict(checkpoint['optimizer_state_dict'])
    epoch = checkpoint['epoch']
    return epoch
```

### 2. Resource Limits and Requests
```yaml
# Conservative resource requests for spot instances
resources:
  requests:
    nvidia.com/gpu: 1
    memory: "4Gi"
    cpu: "2"
  limits:
    nvidia.com/gpu: 1
    memory: "8Gi"
    cpu: "4"
```

### 3. Spot Instance Preemption Handling
```bash
# Add preemption handling script
#!/bin/bash
# Graceful shutdown on spot preemption

trap "echo 'Received termination signal'; exit 0" SIGTERM

while true; do
  # Check for spot termination notice
  if [ -f "/tmp/spot-termination" ]; then
    echo "Spot instance termination detected"
    # Save checkpoint
    python save_checkpoint.py
    exit 0
  fi
  sleep 5
done
```

## Cost Estimation

### Monthly Cost Comparison (24/7 usage)
| VM Size | On-Demand | Spot (90% savings) | Monthly On-Demand | Monthly Spot |
|---------|-----------|---------------------|-------------------|--------------|
| NC4as_T4_v3 | $0.50/hour | $0.05/hour | $360 | $36 |
| NC6s_v3 | $3.06/hour | $0.30/hour | $2,203 | $220 |
| ND96amsr_A100_v4 | $27.00/hour | $2.70/hour | $19,440 | $1,944 |

### Usage-Based Cost Optimization
- **Development**: Use spot instances (interruptible)
- **Testing**: Use smaller GPU instances
- **Training**: Use spot instances with checkpointing
- **Inference**: Use cost-effective T4 GPUs
- **Production**: Consider reserved instances for baseline load

## Troubleshooting

### GPU Not Detected
```bash
# Check GPU availability on node
kubectl exec -it <gpu-pod> -- nvidia-smi

# Verify NVIDIA device plugin
kubectl logs -n kube-system -l app=nvidia-device-plugin

# Check node labels
kubectl get nodes -L accelerator
```

### Pod Pending State
```bash
# Describe pod to see scheduling issues
kubectl describe pod <gpu-pod>

# Check if GPU nodes are available
kubectl get nodes -L gpu-node

# Verify taints and tolerations
kubectl describe node <gpu-node>
```

### Performance Issues
```bash
# Monitor GPU metrics
kubectl exec -it <gpu-pod> -- nvidia-smi dmon -s u -d 1

# Check for GPU memory leaks
kubectl exec -it <gpu-pod> -- nvidia-smi --query-gpu=memory.used,memory.total --format=csv
```

## Alternative Cloud Providers

If Azure costs are prohibitive, consider:

### 1. RunPod.io
- Pay-per-hour GPU instances
- Support for various GPU types
- No minimum commitment
- Quick spin-up time

### 2. Lambda Labs
- Low-cost GPU instances
- Pre-configured ML environments
- Flexible billing options
- Good for experimentation

### 3. Google Cloud Platform
- Competitive GPU pricing
- TPUs for TensorFlow workloads
- Preemptible instances (similar to spot)
- Discounts for sustained use

## Conclusion

For this AKS POC environment, the recommended approach is:

1. **Primary**: Azure Spot Instances with NVIDIA T4 GPUs
2. **Development**: Local GPU testing with kind
3. **Testing**: Small GPU instances or alternative cloud providers
4. **Production**: Reserved instances for baseline load + spot for peak demand

This approach provides maximum cost-effectiveness while maintaining flexibility for various workload requirements.

---
**Document Status**: Draft
**Last Updated**: 2026-05-31
**Next Review**: After GPU workload testing