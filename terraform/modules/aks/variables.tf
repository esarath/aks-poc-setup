variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "aks_dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to deploy"
  type        = string
}

# Network Configuration
variable "vnet_id" {
  description = "ID of the virtual network"
  type        = string
}

variable "aks_system_subnet_id" {
  description = "ID of the AKS system subnet"
  type        = string
}

variable "aks_user_subnet_id" {
  description = "ID of the AKS user subnet"
  type        = string
}

variable "aks_gpu_subnet_id" {
  description = "ID of the AKS GPU subnet"
  type        = string
}

# Node Pool Configuration
variable "system_node_pool_vm_size" {
  description = "VM size for system node pool"
  type        = string
}

variable "system_node_pool_count" {
  description = "Number of nodes in system node pool"
  type        = number
}

variable "user_node_pool_vm_size" {
  description = "VM size for user node pool"
  type        = string
}

variable "user_node_pool_count" {
  description = "Number of nodes in user node pool"
  type        = number
}

# Auto-scaling Configuration
variable "enable_auto_scaling" {
  description = "Enable cluster autoscaler"
  type        = bool
}

variable "min_node_count" {
  description = "Minimum number of nodes for auto-scaling"
  type        = number
}

variable "max_node_count" {
  description = "Maximum number of nodes for auto-scaling"
  type        = number
}

# GPU Configuration
variable "enable_gpu_node_pool" {
  description = "Enable GPU node pool"
  type        = bool
}

variable "gpu_node_pool_vm_size" {
  description = "VM size for GPU node pool"
  type        = string
}

variable "gpu_node_pool_count" {
  description = "Number of nodes in GPU node pool"
  type        = number
}

# Azure AD Integration
variable "enable_azure_ad_integration" {
  description = "Enable Azure AD integration"
  type        = bool
}

variable "azure_ad_admin_group_id" {
  description = "Azure AD admin group object ID"
  type        = string
}

# Monitoring Integration
variable "enable_monitoring" {
  description = "Enable Azure Monitor integration"
  type        = bool
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  type        = string
}

# ACR Integration
variable "acr_id" {
  description = "ID of the Azure Container Registry"
  type        = string
}

# Network Configuration
variable "authorized_ip_ranges" {
  description = "Authorized IP ranges for AKS API server"
  type        = list(string)
  default     = []
}

variable "enable_private_cluster" {
  description = "Enable private AKS cluster"
  type        = bool
}

variable "api_server_authorized_ip_ranges" {
  description = "IP ranges authorized to access the Kubernetes API server"
  type        = list(string)
  default     = []
}

# Network Policy
variable "network_policy" {
  description = "Network policy plugin to use"
  type        = string
  default     = "calico"
}

variable "network_plugin" {
  description = "Network plugin to use"
  type        = string
  default     = "azure"
}

variable "load_balancer_sku" {
  description = "SKU tier for load balancer"
  type        = string
  default     = "Standard"
}

variable "service_cidr" {
  description = "CIDR range for Kubernetes services"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_service_ip" {
  description = "DNS service IP address"
  type        = string
  default     = "10.0.0.10"
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
