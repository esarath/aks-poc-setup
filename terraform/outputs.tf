# Resource Group Outputs
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

# Virtual Network Outputs
output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.vnet.vnet_id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.vnet.vnet_name
}

output "aks_system_subnet_id" {
  description = "ID of the AKS system subnet"
  value       = module.vnet.aks_system_subnet_id
}

output "aks_user_subnet_id" {
  description = "ID of the AKS user subnet"
  value       = module.vnet.aks_user_subnet_id
}

output "aks_gpu_subnet_id" {
  description = "ID of the AKS GPU subnet"
  value       = module.vnet.aks_gpu_subnet_id
}

output "database_subnet_id" {
  description = "ID of the database subnet"
  value       = module.vnet.database_subnet_id
}

# AKS Cluster Outputs
output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = module.aks.aks_cluster_id
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.aks_cluster_name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = module.aks.aks_cluster_fqdn
}

output "aks_host" {
  description = "Kubernetes API server host"
  value       = module.aks.host
}

output "aks_client_certificate" {
  description = "Kubernetes client certificate"
  value       = module.aks.client_certificate
  sensitive   = true
}

output "aks_client_key" {
  description = "Kubernetes client key"
  value       = module.aks.client_key
  sensitive   = true
}

output "aks_cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  value       = module.aks.cluster_ca_certificate
  sensitive   = true
}

output "aks_kube_config" {
  description = "Kubernetes kubeconfig"
  value       = module.aks.kube_config
  sensitive   = true
}

output "aks_node_resource_group" {
  description = "Node resource group for AKS"
  value       = module.aks.node_resource_group
}

# Azure Container Registry Outputs
output "acr_id" {
  description = "ID of the Azure Container Registry"
  value       = module.acr.acr_id
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = module.acr.acr_name
}

output "acr_login_server" {
  description = "Login server for the Azure Container Registry"
  value       = module.acr.acr_login_server
}

output "acr_admin_username" {
  description = "Admin username for the Azure Container Registry"
  value       = module.acr.acr_admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "Admin password for the Azure Container Registry"
  value       = module.acr.acr_admin_password
  sensitive   = true
}

# Database Outputs
output "postgresql_server_id" {
  description = "ID of the PostgreSQL server"
  value       = module.database.postgresql_server_id
}

output "postgresql_server_name" {
  description = "Name of the PostgreSQL server"
  value       = module.database.postgresql_server_name
}

output "postgresql_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = module.database.postgresql_fqdn
}

output "postgresql_admin_username" {
  description = "Admin username for PostgreSQL"
  value       = module.database.postgresql_admin_username
  sensitive   = true
}

output "postgresql_database_name" {
  description = "Name of the PostgreSQL database"
  value       = module.database.postgresql_database_name
}

# Key Vault Outputs
output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault.main[0].id : null
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault.main[0].name : null
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = var.enable_key_vault ? azurerm_key_vault.main[0].vault_uri : null
}

# Monitoring Outputs
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = module.monitoring.log_analytics_workspace_id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = module.monitoring.log_analytics_workspace_name
}

output "log_analytics_primary_shared_key" {
  description = "Primary shared key for Log Analytics"
  value       = module.monitoring.log_analytics_primary_shared_key
  sensitive   = true
}

# Application Gateway Outputs (if enabled)
output "app_gateway_id" {
  description = "ID of the Application Gateway"
  value       = null
}

# Kubernetes Commands
output "configure_kubectl_command" {
  description = "Command to configure kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${module.aks.aks_cluster_name} --admin"
}

# Docker Commands
output "docker_login_command" {
  description = "Command to login to ACR"
  value       = "az acr login --name ${module.acr.acr_name}"
}

# Cost Management Outputs
output "cost_budget_id" {
  description = "ID of the cost budget"
  value       = var.enable_cost_analysis ? azurerm_consumption_budget_resource_group.main[0].id : null
}

# Miscellaneous Outputs
output "unique_suffix" {
  description = "Random unique suffix for resource naming"
  value       = random_string.unique_suffix.result
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "location" {
  description = "Azure location"
  value       = var.location
}

output "subscription_id" {
  description = "Azure Subscription ID"
  value       = var.subscription_id
}

output "tenant_id" {
  description = "Azure Tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "client_object_id" {
  description = "Client Object ID"
  value       = data.azurerm_client_config.current.object_id
}
