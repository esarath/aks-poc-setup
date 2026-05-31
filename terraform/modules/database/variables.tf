variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "database_subnet_id" {
  description = "ID of the database subnet"
  type        = string
}

variable "enable_postgresql" {
  description = "Enable PostgreSQL database"
  type        = bool
  default     = true
}

variable "postgresql_server_name" {
  description = "Name of the PostgreSQL server"
  type        = string
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

variable "aks_user_subnet_cidr" {
  description = "CIDR block for AKS user subnet for firewall rules"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
