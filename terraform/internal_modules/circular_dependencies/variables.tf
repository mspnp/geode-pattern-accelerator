variable "resource_group_name" {
  type        = string
  description = "The name of the Resource Group in which to deploy API resources."
}

variable "function_app_name" {
  type        = string
  description = "The name of the Azure Function app."
}

variable "api_management_name" {
  type        = string
  description = "The name of the API Management Instance."
}

variable "instrumentation_key" {
  type        = string
  description = "The Application Insights instrumentation key."
}

variable "cosmos_connection_string_key_vault_secret_id" {
  type        = string
  description = "The ID for the Key Vault secret which stores the connection string for the Cosmos DB instance."
}

variable "front_door_header_id" {
  type        = string
  description = "The unique Header ID of the Front Door."
}

variable "entra_application_client_id" {
  type        = string
  description = "The Client ID of the Microsoft Entra ID Application."
}
