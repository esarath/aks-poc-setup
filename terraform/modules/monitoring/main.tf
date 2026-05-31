# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  count               = var.enable_monitoring ? 1 : 0
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_days
  
  # Data collection and ingestion
  daily_quota_gb       = -1  # Unlimited
  internet_ingestion_enabled = true
  
  # Feature flags
  features {
    enable_log_search_using_purged_categories = true
  }
  
  tags = var.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  count               = var.enable_application_insights ? 1 : 0
  name                = var.application_insights_name
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = var.application_insights_type
  
  # Workspace-based Application Insights
  workspace_id        = var.enable_monitoring ? azurerm_log_analytics_workspace.main[0].id : null
  
  # Daily data cap
  daily_data_cap_in_gb = 100
  daily_data_cap_notification_disabled = false
  
  # Sampling
  sampling_percentage = 100.0
  
  # Disable IP masking (set to true for security)
  disable_ip_masking = false
  
  tags = var.tags
}

# Azure Monitor - Private Link Scope (optional for security)
resource "azurerm_monitor_private_link_scope" "main" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "aks-poc-monitor-pls"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  tags = var.tags
}

# Private Link Scope Association with Log Analytics Workspace
resource "azurerm_monitor_private_link_scope_association" "log_analytics" {
  count                     = var.enable_monitoring ? 1 : 0
  name                      = "log-analytics-association"
  resource_group_name       = var.resource_group_name
  monitor_private_link_scope_id = azurerm_monitor_private_link_scope.main[0].id
  linked_resource_id        = azurerm_log_analytics_workspace.main[0].id
}

# Private Link Scope Association with Application Insights
resource "azurerm_monitor_private_link_scope_association" "app_insights" {
  count                     = var.enable_monitoring && var.enable_application_insights ? 1 : 0
  name                      = "app-insights-association"
  resource_group_name       = var.resource_group_name
  monitor_private_link_scope_id = azurerm_monitor_private_link_scope.main[0].id
  linked_resource_id        = azurerm_application_insights.main[0].id
}

# Diagnostic Settings for Log Analytics
resource "azurerm_monitor_diagnostic_setting" "log_analytics_diagnostic" {
  count                      = var.enable_monitoring ? 1 : 0
  name                       = "log-analytics-diagnostic"
  target_resource_id         = azurerm_log_analytics_workspace.main[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id
  
  # Log categories
  log {
    category = "Audit"
    enabled  = true
  }
  
  log {
    category = "DataPlaneRequests"
    enabled  = true
  }
  
  # Metrics
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Action Group for Alerts
resource "azurerm_monitor_action_group" "main" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "aks-poc-action-group"
  resource_group_name = var.resource_group_name
  short_name          = "akspocag"
  location            = var.location
  
  email_receiver {
    name          = "Admin"
    email_address = "admin@example.com"
  }
  
  # SMS receiver (optional)
  # sms_receiver {
  #   name          = "AdminSMS"
  #   country_code  = "1"
  #   phone_number  = "+1234567890"
  # }
  
  tags = var.tags
}

# Alert Rule for CPU Usage
resource "azurerm_monitor_metric_alert" "cpu_alert" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "aks-cpu-usage-alert"
  resource_group_name = var.resource_group_name
  location            = var.location
  scopes              = [azurerm_log_analytics_workspace.main[0].id]
  
  description = "Alert when CPU usage exceeds 80%"
  
  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }
  
  frequency  = "PT5M"
  severity   = 2
  window_size = "PT15M"
  
  tags = var.tags
}
