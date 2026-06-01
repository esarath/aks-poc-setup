# Data Sources
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Virtual Network Module
module "vnet" {
  source              = "./modules/vnet"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vnet_address_space  = var.vnet_address_space
  
  aks_system_subnet_cidr    = var.aks_system_subnet_cidr
  aks_user_subnet_cidr      = var.aks_user_subnet_cidr
  aks_gpu_subnet_cidr       = var.aks_gpu_subnet_cidr
  database_subnet_cidr      = var.database_subnet_cidr
  app_gateway_subnet_cidr   = var.app_gateway_subnet_cidr
  bastion_subnet_cidr       = var.bastion_subnet_cidr
  
  tags = var.tags
}

# Azure Container Registry Module
module "acr" {
  source              = "./modules/acr"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  acr_name            = var.acr_name
  acr_sku             = var.acr_sku
  
  tags = var.tags
}

# Database Module
module "database" {
  source              = "./modules/database"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  database_subnet_id  = module.vnet.database_subnet_id
  
  enable_postgresql           = var.enable_postgresql
  postgresql_server_name      = var.postgresql_server_name
  postgresql_admin_username   = var.postgresql_admin_username
  postgresql_admin_password   = var.postgresql_admin_password
  postgresql_sku_name         = var.postgresql_sku_name
  postgresql_version          = var.postgresql_version
  postgresql_storage_mb       = var.postgresql_storage_mb
  
  aks_user_subnet_cidr        = var.aks_user_subnet_cidr
  
  tags = var.tags
  
  depends_on = [module.vnet]
}

# Monitoring Module
module "monitoring" {
  source              = "./modules/monitoring"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  enable_monitoring              = var.enable_monitoring
  log_analytics_workspace_name   = var.log_analytics_workspace_name
  log_analytics_retention_days   = var.log_analytics_retention_days
  
  tags = var.tags
}

# Key Vault
resource "azurerm_key_vault" "main" {
  count                   = var.enable_key_vault ? 1 : 0
  name                    = var.key_vault_name
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  tenant_id               = data.azurerm_client_config.current.tenant_id
  sku_name                = "standard"
  
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    
    key_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Recover", "Purge"
    ]
    
    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Purge"
    ]
    
    certificate_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Recover", "Purge"
    ]
  }
  
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
  
  tags = var.tags
}

# Store Database Password in Key Vault
resource "azurerm_key_vault_secret" "db_password" {
  count        = var.enable_key_vault && var.enable_postgresql ? 1 : 0
  name         = "database-password"
  value        = var.postgresql_admin_password
  key_vault_id = azurerm_key_vault.main[0].id
}

# AKS Cluster Module
module "aks" {
  source              = "./modules/aks"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  aks_cluster_name      = var.aks_cluster_name
  aks_dns_prefix        = var.aks_dns_prefix
  kubernetes_version    = var.kubernetes_version
  
  # Network Configuration
  vnet_id                    = module.vnet.vnet_id
  aks_system_subnet_id       = module.vnet.aks_system_subnet_id
  aks_user_subnet_id         = module.vnet.aks_user_subnet_id
  aks_gpu_subnet_id          = var.enable_gpu_node_pool ? module.vnet.aks_gpu_subnet_id : null
  
  # Node Pool Configuration
  system_node_pool_vm_size    = var.system_node_pool_vm_size
  system_node_pool_count      = var.system_node_pool_count
  user_node_pool_vm_size      = var.user_node_pool_vm_size
  user_node_pool_count        = var.user_node_pool_count
  
  # Auto-scaling Configuration
  enable_auto_scaling         = var.enable_auto_scaling
  min_node_count              = var.min_node_count
  max_node_count              = var.max_node_count
  
  # GPU Configuration
  enable_gpu_node_pool        = var.enable_gpu_node_pool
  gpu_node_pool_vm_size       = var.gpu_node_pool_vm_size
  gpu_node_pool_count         = var.gpu_node_pool_count
  
  # Azure AD Integration
  enable_azure_ad_integration = var.enable_azure_ad_integration
  azure_ad_admin_group_id     = var.azure_ad_admin_group_id
  
  # Monitoring Integration
  enable_monitoring           = var.enable_monitoring
  log_analytics_workspace_id  = module.monitoring.log_analytics_workspace_id
  
  # ACR Integration
  acr_id                      = module.acr.acr_id
  
  # Network Configuration
  authorized_ip_ranges        = var.authorized_ip_ranges
  enable_private_cluster      = var.enable_private_cluster
  
  tags = var.tags
  
  depends_on = [
    module.vnet,
    module.acr,
    module.monitoring
  ]
}

# Cost Management
resource "azurerm_consumption_budget_resource_group" "main" {
  count              = var.enable_cost_analysis ? 1 : 0
  name              = "aks-poc-budget"
  resource_group_id = azurerm_resource_group.main.id
  
  amount     = var.cost_budget_amount
  time_grain = "Monthly"
  
  notification {
    enabled = true
    threshold = 80.0
    contact_emails = ["admin@example.com"]
    
    operator = "GreaterThan"
  }
  
  notification {
    enabled = true
    threshold = 100.0
    contact_emails = ["admin@example.com"]
    
    operator = "GreaterThan"
  }
}

# Azure Policy for AKS
resource "azurerm_kubernetes_cluster_policy" "restrict_images" {
  count              = var.enable_policy ? 1 : 0
  name              = "restrict-images"
  category          = "Container"
  display_name      = "Restrict container images"
  description       = "Policy to restrict container images to approved registries only"
  mode              = "Microsoft.Kubernetes.Configuration"
  
  metadata = jsonencode({
    version = "1.0.0"
    category = "Container"
  })
  
  parameters = jsonencode({
    allowedImageRegistries = {
      type = "Array"
      metadata = {
        displayName = "Allowed Image Registries"
        description = "The list of allowed container image registries"
      }
      defaultValue = [
        "docker.io",
        "azurecr.io"
      ]
    }
  })
  
  policy_rule = jsonencode({
    if = {
      field = "type"
      equals = "Microsoft.Kubernetes.Configuration"
    }
    then = {
      effect = "deny"
      details = {
        templateInfo = {
          templateType = "ConstraintTemplate"
          templateName = "k8sazurecontainernoallowedimages"
        }
        constraint = {
          name = "container-no-allowed-images"
        }
      }
    }
  })
}

variable "enable_policy" {
  description = "Enable Azure Policy for AKS"
  type        = bool
  default     = true
}

# Random Suffix for Unique Resource Names
resource "random_string" "unique_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Docker Hub Image Pull Secret
resource "kubectl_secret" "docker_hub" {
  metadata {
    name      = "docker-hub-secret"
    namespace = "default"
  }
  
  type = "kubernetes.io/dockerconfigjson"
  
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "https://index.docker.io/v1/" = {
          auth = base64encode("${var.docker_hub_username}:${var.docker_hub_password}")
        }
      }
    })
  }
  
  depends_on = [module.aks]
}
