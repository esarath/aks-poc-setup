output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.main[0].id : null
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.main[0].name : null
}

output "log_analytics_workspace_location" {
  description = "Location of the Log Analytics Workspace"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.main[0].location : null
}

output "log_analytics_workspace_guid" {
  description = "GUID of the Log Analytics Workspace"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.main[0].workspace_id : null
}

output "log_analytics_primary_shared_key" {
  description = "Primary shared key for Log Analytics"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.main[0].primary_shared_key : null
  sensitive   = true
}

output "log_analytics_secondary_shared_key" {
  description = "Secondary shared key for Log Analytics"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.main[0].secondary_shared_key : null
  sensitive   = true
}

output "application_insights_id" {
  description = "ID of the Application Insights"
  value       = var.enable_application_insights ? azurerm_application_insights.main[0].id : null
}

output "application_insights_name" {
  description = "Name of the Application Insights"
  value       = var.enable_application_insights ? azurerm_application_insights.main[0].name : null
}

output "application_insights_app_id" {
  description = "App ID of the Application Insights"
  value       = var.enable_application_insights ? azurerm_application_insights.main[0].app_id : null
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key of the Application Insights"
  value       = var.enable_application_insights ? azurerm_application_insights.main[0].instrumentation_key : null
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string of the Application Insights"
  value       = var.enable_application_insights ? azurerm_application_insights.main[0].connection_string : null
  sensitive   = true
}

output "monitor_private_link_scope_id" {
  description = "ID of the Azure Monitor Private Link Scope"
  value       = var.enable_monitoring ? azurerm_monitor_private_link_scope.main[0].id : null
}

output "action_group_id" {
  description = "ID of the Action Group"
  value       = var.enable_monitoring ? azurerm_monitor_action_group.main[0].id : null
}
