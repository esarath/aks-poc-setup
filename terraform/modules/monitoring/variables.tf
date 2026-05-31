variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "enable_monitoring" {
  description = "Enable Azure Monitor and Log Analytics"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  type        = string
}

variable "log_analytics_retention_days" {
  description = "Retention period in days for Log Analytics"
  type        = number
  default     = 30
}

variable "log_analytics_sku" {
  description = "SKU tier for Log Analytics Workspace"
  type        = string
  default     = "PerGB2018"
}

variable "enable_application_insights" {
  description = "Enable Application Insights"
  type        = bool
  default     = true
}

variable "application_insights_name" {
  description = "Name of the Application Insights instance"
  type        = string
  default     = "aks-poc-appinsights"
}

variable "application_insights_type" {
  description = "Type of Application Insights"
  type        = string
  default     = "web"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
