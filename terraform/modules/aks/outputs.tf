output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "host" {
  description = "Kubernetes API server host"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].host
}

output "client_certificate" {
  description = "Kubernetes client certificate"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Kubernetes client key"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "kube_config" {
  description = "Kubernetes kubeconfig"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "node_resource_group" {
  description = "Node resource group for AKS"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "system_node_pool_id" {
  description = "ID of the system node pool"
  value       = azurerm_kubernetes_cluster.aks.default_node_pool[0].id
}

output "user_node_pool_id" {
  description = "ID of the user node pool"
  value       = azurerm_kubernetes_cluster_node_pool.userpool.id
}

output "gpu_node_pool_id" {
  description = "ID of the GPU node pool"
  value       = var.enable_gpu_node_pool ? azurerm_kubernetes_cluster_node_pool.gpupool[0].id : null
}

output "aks_identity_principal_id" {
  description = "Principal ID of the AKS managed identity"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "aks_kubelet_identity" {
  description = "Kubelet identity for AKS"
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

output "aks_portal_fqdn" {
  description = "Azure portal FQDN for the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.portal_fqdn
}

output "kubernetes_version" {
  description = "Kubernetes version of the cluster"
  value       = azurerm_kubernetes_cluster.aks.kubernetes_version
}
