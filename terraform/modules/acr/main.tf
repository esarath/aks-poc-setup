# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.acr_sku
  admin_enabled       = var.admin_enabled
  
  # Network rule set for security
  network_rule_set {
    default_action = "Allow"
  }
  
  # Retention policy
  retention_policy {
    days    = 30
    enabled = true
  }
  
  # Trust policy for image signing
  trust_policy {
    enabled = true
  }
  
  # Anonymous pull (disabled by default for security)
  anonymous_pull_enabled = var.anonymous_pull_enabled
  
  # Georeplication list (optional)
  georeplications = []
  
  tags = var.tags
}

# ACR Agent Pool (optional, for build tasks)
# Uncomment if you want to use ACR Tasks
# resource "azurerm_container_registry_agent_pool" "buildpool" {
#   name                    = "buildpool"
#   location                = var.location
#   resource_group_name     = var.resource_group_name
#   container_registry_name = azurerm_container_registry.acr.name
#   tier                    = "S1"
#   count                   = 1
# }

# Webhook for image push events
resource "azurerm_container_registry_webhook" "image_push" {
  name                = "image-push-webhook"
  location            = var.location
  resource_group_name = var.resource_group_name
  registry_name       = azurerm_container_registry.acr.name
  
  service_uri = "https://your-webhook-endpoint.com/acr-push"
  status      = "enabled"
  scope       = "myapp:*"
  actions     = ["push"]
  custom_headers = {
    "Content-Type" = "application/json"
  }
  
  depends_on = [azurerm_container_registry.acr]
}
