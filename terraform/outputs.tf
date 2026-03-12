output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "FHS"
}

output "aks_cluster_name" {
  value       = azurerm_kubernetes_cluster.main.name
  description = "FHS"
}

output "aks_cluster_host" {
  value       = azurerm_kubernetes_cluster.main.kube_config[0].host
  description = "FHS-API server endpoint"
  sensitive   = true
}

output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "ACR login server URL (use as REGISTRY in CI/CD)"
}

output "acr_admin_username" {
  value       = azurerm_container_registry.acr.admin_username
  description = "ACR admin username"
  sensitive   = true
}

output "acr_admin_password" {
  value       = azurerm_container_registry.acr.admin_password
  description = "ACR admin password"
  sensitive   = true
}

output "key_vault_uri" {
  value       = azurerm_key_vault.main.vault_uri
  description = "Azure Key Vault URI"
}

output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.main.id
  description = "Log Analytics Workspace ID"
}

output "kubeconfig_command" {
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
  description = "Command to configure kubectl"
}
