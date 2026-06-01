# Azure Configuration Variables
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  default     = "7908ea24-a708-4291-be15-98426e3e9ca5"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-aks-poc"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "POC"
    Project     = "AKS-POC"
    ManagedBy   = "Terraform"
  }
}

# Network Configuration Variables
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_system_subnet_cidr" {
  description = "CIDR block for AKS system node subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "aks_user_subnet_cidr" {
  description = "CIDR block for AKS user node subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "aks_gpu_subnet_cidr" {
  description = "CIDR block for AKS GPU node subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "database_subnet_cidr" {
  description = "CIDR block for database subnet"
  type        = string
  default     = "10.0.4.0/24"
}

variable "app_gateway_subnet_cidr" {
  description = "CIDR block for application gateway subnet"
  type        = string
  default     = "10.0.5.0/24"
}

variable "bastion_subnet_cidr" {
  description = "CIDR block for Azure Bastion subnet"
  type        = string
  default     = "10.0.6.0/24"
}

# AKS Configuration Variables
variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-poc-cluster"
}

variable "aks_dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "aks-poc"
}

variable "kubernetes_version" {
  description = "Kubernetes version to deploy"
  type        = string
  default     = "1.28.3"
}

variable "system_node_pool_vm_size" {
  description = "VM size for system node pool"
  type        = string
  default     = "Standard_DS2_v2"
}

variable "system_node_pool_count" {
  description = "Number of nodes in system node pool"
  type        = number
  default     = 2
}

variable "user_node_pool_vm_size" {
  description = "VM size for user node pool"
  type        = string
  default     = "Standard_DS3_v2"
}

variable "user_node_pool_count" {
  description = "Number of nodes in user node pool"
  type        = number
  default     = 2
}

variable "enable_gpu_node_pool" {
  description = "Enable GPU node pool for ML/AI workloads (disabled for cost efficiency)"
  type        = bool
  default     = false
}

variable "gpu_node_pool_vm_size" {
  description = "VM size for GPU node pool (if enabled)"
  type        = string
  default     = "Standard_NC4as_T4_v3"
}

variable "gpu_node_pool_count" {
  description = "Number of nodes in GPU node pool (if enabled)"
  type        = number
  default     = 0
}

variable "enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler"
  type        = bool
  default     = true
}

# Azure Container Registry Variables
variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
  default     = "akspocregistry"
}

variable "acr_sku" {
  description = "SKU tier for Azure Container Registry"
  type        = string
  default     = "Standard"
}

# Database Configuration Variables
variable "enable_postgresql" {
  description = "Enable PostgreSQL database"
  type        = bool
  default     = true
}

variable "postgresql_server_name" {
  description = "Name of the PostgreSQL server"
  type        = string
  default     = "aks-poc-postgres"
}

variable "postgresql_admin_username" {
  description = "Admin username for PostgreSQL"
  type        = string
  sensitive   = true
}

variable "postgresql_admin_password" {
  description = "Admin password for PostgreSQL"
  type        = string
  sensitive   = true
}

variable "postgresql_sku_name" {
  description = "SKU name for PostgreSQL"
  type        = string
  default     = "GP_Gen5_2"
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "13"
}

variable "postgresql_storage_mb" {
  description = "Storage size for PostgreSQL in MB"
  type        = number
  default     = 51200
}

# Key Vault Configuration Variables
variable "enable_key_vault" {
  description = "Enable Azure Key Vault"
  type        = bool
  default     = true
}

variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string
  default     = "aks-poc-kv"
}

# Monitoring Configuration Variables
variable "enable_monitoring" {
  description = "Enable Azure Monitor and Log Analytics"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  type        = string
  default     = "aks-poc-log-analytics"
}

variable "log_analytics_retention_days" {
  description = "Retention period in days for Log Analytics"
  type        = number
  default     = 30
}

# Azure AD Configuration Variables
variable "enable_azure_ad_integration" {
  description = "Enable Azure AD integration"
  type        = bool
  default     = true
}

variable "azure_ad_admin_group_id" {
  description = "Azure AD admin group object ID"
  type        = string
  default     = ""
}

# Network Security Configuration Variables
variable "authorized_ip_ranges" {
  description = "Authorized IP ranges for AKS API server"
  type        = list(string)
  default     = []
}

variable "enable_private_cluster" {
  description = "Enable private AKS cluster"
  type        = bool
  default     = false
}

# Cost Management Variables
variable "enable_cost_analysis" {
  description = "Enable cost analysis and budget alerts"
  type        = bool
  default     = true
}

variable "cost_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 500
}

# Docker Hub Configuration Variables
variable "docker_hub_username" {
  description = "Docker Hub username"
  type        = string
  default     = "esarathmails"
}

variable "docker_hub_password" {
  description = "Docker Hub password"
  type        = string
  sensitive   = true
}

# GitHub Configuration Variables
variable "github_repo" {
  description = "GitHub repository URL"
  type        = string
  default     = "https://github.com/esarath/aks-poc-setup"
}

variable "github_token" {
  description = "GitHub token for authentication"
  type        = string
  sensitive   = true
}

# Environment-specific Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "poc"
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for node pools"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum number of nodes for auto-scaling"
  type        = number
  default     = 2
}

variable "max_node_count" {
  description = "Maximum number of nodes for auto-scaling"
  type        = number
  default     = 10
}
