output "function_apps" {
  value = module.geode.*.api_app_name
}

output "resource_group" {
  value = azurerm_resource_group.rg.name
}

output "frontdoor_hostname" {
  value = azurerm_cdn_frontdoor_endpoint.frontdoor_endpoint.host_name
}