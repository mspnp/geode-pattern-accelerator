variable "resourceGroupName" {
  type        = string
  description = "The name of the Resource Group in which to deploy API resources."
}

variable "functionAppName" {
  type        = string
  description = "The name of the Azure Function app"
}

variable "apiManagementName" {
  type        = string
  description = "The name of the API Management Instance"
}

variable "instrumentationKey" {
  type        = string
  description = "The Application Insights instrumentation key"
}

variable "cosmosConnectionStringKeyVaultSecretId" {
  type        = string
  description = "The ID for the Key Vault secret which stores the connection string for the Cosmos DB instance"
}

variable "frontDoorHeaderId" {
  type        = string
  description = "The unique Header ID of the Front Door."
}

variable "azureADApplicationId" {
  type        = string
  description = "The ID of the Azure AD Application."
}
