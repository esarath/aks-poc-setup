variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
