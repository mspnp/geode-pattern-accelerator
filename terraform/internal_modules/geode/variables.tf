variable "base_name" {
  type        = string
  description = "The base name for created resources, used for tagging as a group."
}

variable "location" {
  type        = string
  description = "The Azure region in which to deploy API resources."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the Resource Group in which to deploy API resources."
}

variable "app_service_sku" {
  type        = string
  description = "Specifies the Azure Functions App Service SKU."
  default     = "Y1"
}

variable "tenant_id" {
  type        = string
  description = "The ID of the tenant to which the Azure Function's Entra authentication should be associated."
}