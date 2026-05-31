# PostgreSQL Server
resource "azurerm_postgresql_server" "postgres" {
  count               = var.enable_postgresql ? 1 : 0
  name                = var.postgresql_server_name
  location            = var.location
  resource_group_name = var.resource_group_name
  
  administrator_login          = var.postgresql_admin_username
  administrator_login_password = var.postgresql_admin_password
  
  sku_name = var.postgresql_sku_name
  version  = var.postgresql_version
  storage_mb = var.postgresql_storage_mb
  
  # Network configuration
  public_network_access_enabled    = false
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version          = "TLS1_2"
  
  # Backup configuration
  backup_retention_days = 7
  geo_redundant_backup  = false
  
  # High availability
  create_mode                = "Default"
  point_in_time_restore_enabled = false
  
  # Auto-tuning and performance
  auto_grow_enabled        = true
  auto_grow_storage_limit  = 0
  
  tags = var.tags
}

# PostgreSQL Database
resource "azurerm_postgresql_database" "appdb" {
  count               = var.enable_postgresql ? 1 : 0
  name                = "appdb"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.postgres[0].name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

# Virtual Network Service Endpoint for PostgreSQL
resource "azurerm_postgresql_virtual_network_rule" "aks_user" {
  count               = var.enable_postgresql ? 1 : 0
  name                = "aks-user-vnet-rule"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.postgres[0].name
  subnet_id           = var.database_subnet_id
}

# Private Endpoint for PostgreSQL
resource "azurerm_private_endpoint" "postgresql" {
  count               = var.enable_postgresql ? 1 : 0
  name                = "pe-postgresql-${var.postgresql_server_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.database_subnet_id
  
  private_service_connection {
    name                           = "postgres-private-connection"
    private_connection_resource_id = azurerm_postgresql_server.postgres[0].id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }
  
  tags = var.tags
}

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgresql" {
  count               = var.enable_postgresql ? 1 : 0
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# DNS Zone Virtual Network Link
resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  count                 = var.enable_postgresql ? 1 : 0
  name                  = "postgresql-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql[0].name
  virtual_network_id    = data.azurerm_virtual_network.selected.id
}

# DNS A Record for PostgreSQL
resource "azurerm_private_dns_a_record" "postgresql" {
  count               = var.enable_postgresql ? 1 : 0
  name                = var.postgresql_server_name
  zone_name           = azurerm_private_dns_zone.postgresql[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.postgresql[0].private_service_connection[0].private_ip_address]
}

# Get the virtual network for DNS zone linking
data "azurerm_virtual_network" "selected" {
  name                = "vnet-aks-poc"
  resource_group_name = var.resource_group_name
  depends_on          = [azurerm_postgresql_server.postgres]
}

# Firewall rule to allow AKS subnet (if needed for backup)
resource "azurerm_postgresql_firewall_rule" "aks_user" {
  count               = var.enable_postgresql ? 1 : 0
  name                = "allow-aks-user-subnet"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.postgres[0].name
  start_ip_address    = var.aks_user_subnet_cidr
  end_ip_address      = var.aks_user_subnet_cidr
}
