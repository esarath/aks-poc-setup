# Data Sources
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# Azure AD Group for AKS Admin
resource "azuread_group" "aks_admins" {
  count        = var.enable_azure_ad_integration && var.azure_ad_admin_group_id == "" ? 1 : 0
  display_name = "aks-poc-admins"
  description  = "AKS Cluster Administrators"
  mail_enabled = false
  security_enabled = true
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.aks_dns_prefix
  kubernetes_version  = var.kubernetes_version
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  # Network Profile
  network_profile {
    network_plugin     = var.network_plugin
    network_policy     = var.network_policy
    load_balancer_sku = var.load_balancer_sku
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
    pod_cidr           = "10.244.0.0/16"
    
    # CNI specific settings
    dns_service_ip = var.dns_service_ip
    docker_bridge_cidr = "172.17.0.1/16"
    
    # Outbound type
    outbound_type = "loadBalancer"
  }
  
  # Default Node Pool (System)
  default_node_pool {
    name                = "systempool"
    node_count          = var.system_node_pool_count
    vm_size             = var.system_node_pool_vm_size
    os_disk_size_gb     = 30
    os_disk_type        = "Premium_LRS"
    vnet_subnet_id      = var.aks_system_subnet_id
    enable_auto_scaling = var.enable_auto_scaling
    min_count           = var.min_node_count
    max_count           = var.max_node_count
    max_pods            = 110
    os_type             = "Linux"
    orchestrator_version = var.kubernetes_version
    
    # Labels and taints for system nodes
    node_labels = {
      "nodepool-type" = "system"
      "kubernetes.io/role" = "system"
    }
    taints = [
      "CriticalAddonsOnly=true:NoSchedule"
    ]
    
    # Upgrade settings
    upgrade_settings {
      max_surge = "1"
    }
  }
  
  # Azure AD Integration
  aad_profile {
    managed = true
    admin_group_object_ids = var.azure_ad_admin_group_id == "" ? (var.enable_azure_ad_integration ? [azuread_group.aks_admins[0].object_id] : []) : [var.azure_ad_admin_group_id]
    tenant_id              = data.azurerm_client_config.current.tenant_id
  }
  
  # RBAC
  role_based_access_control {
    enabled = true
    azure_rbac_enabled = true
  }
  
  # Add-on Profiles
  addon_profile {
    azure_policy {
      enabled = true
    }
    
    http_application_routing {
      enabled = false
    }
    
    kube_dashboard {
      enabled = false
    }
    
    oms_agent {
      enabled = var.enable_monitoring
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }
  
  # API Server access
  api_server_access_profile {
    authorized_ip_ranges     = var.api_server_authorized_ip_ranges
    enable_private_cluster   = var.enable_private_cluster
    private_dns_zone_id      = var.enable_private_cluster ? null : null
    enable_private_cluster_public_fqdn = false
  }
  
  # Windows Profile (disabled for Linux-only cluster)
  windows_profile {
    admin_username = "azureuser"
    admin_password = "P@ssw0rd1234!"
  }
  
  # Auto-scaler profile
  auto_scaler_profile {
    balance_similar_node_groups      = true
    expander                         = "random"
    max_graceful_termination_sec     = 600
    max_node_provisioning_time       = "15m"
    max_unhealthy_percentage         = 33
    max_unhealthy_percentage         = 33
    new_pod_scale_up_delay           = "0s"
    ok_total_unhealthy_count         = 3
    scale_down_delay_after_add       = "10m"
    scale_down_delay_after_delete    = "10s"
    scale_down_delay_after_failure   = "3m"
    scale_down_unneeded              = true
    scale_down_unready               = true
    scale_down_utilization_threshold = 0.5
    scan_interval                   = "10s"
    skip_nodes_with_system_pods     = true
    skip_nodes_with_local_storage    = true
  }
  
  # Tags
  tags = var.tags
}

# User Node Pool
resource "azurerm_kubernetes_cluster_node_pool" "userpool" {
  name                  = "userpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  node_count            = var.user_node_pool_count
  vm_size               = var.user_node_pool_vm_size
  os_disk_size_gb       = 50
  os_disk_type          = "Premium_LRS"
  vnet_subnet_id        = var.aks_user_subnet_id
  enable_auto_scaling   = var.enable_auto_scaling
  min_count             = var.min_node_count
  max_count             = var.max_node_count
  max_pods              = 110
  os_type               = "Linux"
  orchestrator_version  = var.kubernetes_version
  
  # Labels
  node_labels = {
    "nodepool-type" = "user"
    "kubernetes.io/role" = "worker"
  }
  
  # No taints for regular workloads
  node_taints = []
  
  # Upgrade settings
  upgrade_settings {
    max_surge = "1"
  }
}

# GPU Node Pool (Disabled for Cost Efficiency)
# GPU workloads are expensive. This configuration focuses on cost-effective CPU-based workloads.
# To enable GPU workloads later, set enable_gpu_node_pool = true in variables.tf
# resource "azurerm_kubernetes_cluster_node_pool" "gpupool" {
#   count                 = var.enable_gpu_node_pool ? 1 : 0
#   name                  = "gpupool"
#   kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
#   node_count            = var.gpu_node_pool_count
#   vm_size               = var.gpu_node_pool_vm_size
#   os_disk_size_gb       = 100
#   os_disk_type          = "Premium_LRS"
#   vnet_subnet_id        = var.aks_gpu_subnet_id
#   enable_auto_scaling   = var.enable_auto_scaling
#   min_count             = 0
#   max_count             = 2
#   max_pods              = 110
#   os_type               = "Linux"
#   orchestrator_version  = var.kubernetes_version
#   
#   # GPU-specific labels
#   node_labels = {
#     "nodepool-type" = "gpu"
#     "accelerator"   = "nvidia-tesla-t4"
#     "kubernetes.io/role" = "worker"
#   }
#   
#   # GPU taint to schedule GPU workloads only
#   node_taints = [
#     "nvidia.com/gpu=true:NoSchedule"
#   ]
#   
#   # Use spot instances for cost savings
  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1
  
  # Upgrade settings
  upgrade_settings {
    max_surge = "1"
  }
}

# Assign ACR Pull Role to AKS Identity
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# Assign Network Contributor Role to AKS Identity
resource "azurerm_role_assignment" "network_contributor" {
  scope                = var.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

# Assign Monitor Contributor Role to AKS Identity
resource "azurerm_role_assignment" "monitor_contributor" {
  count                = var.enable_monitoring ? 1 : 0
  scope                = var.log_analytics_workspace_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

# Azure Policy for AKS (optional)
resource "azurerm_kubernetes_cluster_extension" "azure_policy" {
  count              = var.azure_ad_admin_group_id != "" ? 1 : 0
  name              = "azure-policy"
  cluster_name      = azurerm_kubernetes_cluster.aks.name
  resource_group_name = var.resource_group_name
  extension_type    = "Microsoft.PolicyInsights"
  
  configuration_settings = {
    "logAnalyticsWorkspaceId" = var.enable_monitoring ? var.log_analytics_workspace_id : ""
  }
}

# Azure Monitor Container Insights Extension
resource "azurerm_kubernetes_cluster_extension" "container_insights" {
  count              = var.enable_monitoring ? 1 : 0
  name              = "container-insights"
  cluster_name      = azurerm_kubernetes_cluster.aks.name
  resource_group_name = var.resource_group_name
  extension_type    = "Microsoft.AzureMonitor.Containers"
  
  configuration_settings = {
    "logAnalyticsWorkspaceId" = var.log_analytics_workspace_id
    "enableMicrosoftAzureMonitorReceiver" = "true"
  }
}

# Azure Key Vault Secrets Provider Extension
resource "azurerm_kubernetes_cluster_extension" "keyvault_provider" {
  count              = var.azure_ad_admin_group_id != "" ? 1 : 0
  name              = "keyvault-provider"
  cluster_name      = azurerm_kubernetes_cluster.aks.name
  resource_group_name = var.resource_group_name
  extension_type    = "Microsoft.AzureKeyVaultSecretsProvider"
  
  configuration_settings = {
    "secrets-mount-crt-secret-name" = "aks-akv-secrets-csi"
  }
}
