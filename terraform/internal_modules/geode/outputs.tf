output "api_app_name" {
  value = azurerm_windows_function_app.fxnapp.name
}

output "api_management_name" {
  value = local.service_name
}

output "api_app_possible_ip_addresses" {
  value = azurerm_windows_function_app.fxnapp.possible_outbound_ip_addresses
}

output "api_management_gateway_url" {
  value = "https://${local.service_name}.azure-api.net"
}

output "app_insights_instrumentation_key" {
  value     = azurerm_application_insights.fxnappinsights.instrumentation_key
  sensitive = true
}

output "api_tenant_id" {
  value     = azurerm_windows_function_app.fxnapp.identity[0].tenant_id
  sensitive = true
}

output "api_principal_id" {
  value     = azurerm_windows_function_app.fxnapp.identity[0].principal_id
  sensitive = true
}

output "entraid_application_id" {
  value     = azuread_application.entraid.client_id
  sensitive = true
}
