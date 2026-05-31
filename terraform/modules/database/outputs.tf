output "postgresql_server_id" {
  description = "ID of the PostgreSQL server"
  value       = var.enable_postgresql ? azurerm_postgresql_server.postgres[0].id : null
}

output "postgresql_server_name" {
  description = "Name of the PostgreSQL server"
  value       = var.enable_postgresql ? azurerm_postgresql_server.postgres[0].name : null
}

output "postgresql_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = var.enable_postgresql ? azurerm_postgresql_server.postgres[0].fqdn : null
}

output "postgresql_admin_username" {
  description = "Admin username for PostgreSQL"
  value       = var.enable_postgresql ? azurerm_postgresql_server.postgres[0].administrator_login : null
  sensitive   = true
}

output "postgresql_database_name" {
  description = "Name of the PostgreSQL database"
  value       = var.enable_postgresql ? azurerm_postgresql_database.appdb[0].name : null
}

output "postgresql_database_id" {
  description = "ID of the PostgreSQL database"
  value       = var.enable_postgresql ? azurerm_postgresql_database.appdb[0].id : null
}

output "postgresql_private_endpoint_id" {
  description = "ID of the PostgreSQL private endpoint"
  value       = var.enable_postgresql ? azurerm_private_endpoint.postgresql[0].id : null
}

output "postgresql_private_endpoint_ip" {
  description = "Private IP address of the PostgreSQL endpoint"
  value       = var.enable_postgresql ? azurerm_private_endpoint.postgresql[0].private_service_connection[0].private_ip_address : null
}

output "postgresql_connection_string" {
  description = "PostgreSQL connection string"
  value       = var.enable_postgresql ? "host=${azurerm_postgresql_server.postgres[0].fqdn} dbname=${azurerm_postgresql_database.appdb[0].name} user=${azurerm_postgresql_server.postgres[0].administrator_login}@${azurerm_postgresql_server.postgres[0].name} password=${var.postgresql_admin_password} sslmode=require" : null
  sensitive   = true
}
