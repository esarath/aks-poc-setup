output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = azurerm_virtual_network.main.address_space
}

output "aks_system_subnet_id" {
  description = "ID of the AKS system subnet"
  value       = azurerm_subnet.aks_system.id
}

output "aks_system_subnet_cidr" {
  description = "CIDR block of the AKS system subnet"
  value       = azurerm_subnet.aks_system.address_prefixes[0]
}

output "aks_user_subnet_id" {
  description = "ID of the AKS user subnet"
  value       = azurerm_subnet.aks_user.id
}

output "aks_user_subnet_cidr" {
  description = "CIDR block of the AKS user subnet"
  value       = azurerm_subnet.aks_user.address_prefixes[0]
}

output "aks_gpu_subnet_id" {
  description = "ID of the AKS GPU subnet (disabled for cost efficiency)"
  value       = var.enable_gpu_subnet ? azurerm_subnet.aks_gpu[0].id : null
}

output "aks_gpu_subnet_cidr" {
  description = "CIDR block of the AKS GPU subnet (disabled for cost efficiency)"
  value       = var.enable_gpu_subnet ? azurerm_subnet.aks_gpu[0].address_prefixes[0] : null
}

output "database_subnet_id" {
  description = "ID of the database subnet"
  value       = azurerm_subnet.database.id
}

output "database_subnet_cidr" {
  description = "CIDR block of the database subnet"
  value       = azurerm_subnet.database.address_prefixes[0]
}

output "app_gateway_subnet_id" {
  description = "ID of the application gateway subnet"
  value       = azurerm_subnet.app_gateway.id
}

output "bastion_subnet_id" {
  description = "ID of the Azure Bastion subnet"
  value       = azurerm_subnet.bastion.id
}

output "aks_system_nsg_id" {
  description = "ID of the AKS system network security group"
  value       = azurerm_network_security_group.aks_system.id
}

output "aks_user_nsg_id" {
  description = "ID of the AKS user network security group"
  value       = azurerm_network_security_group.aks_user.id
}

output "database_nsg_id" {
  description = "ID of the database network security group"
  value       = azurerm_network_security_group.database.id
}

output "app_gateway_public_ip_id" {
  description = "ID of the Application Gateway public IP"
  value       = azurerm_public_ip.app_gateway.id
}

output "app_gateway_public_ip_address" {
  description = "IP address of the Application Gateway"
  value       = azurerm_public_ip.app_gateway.ip_address
}
