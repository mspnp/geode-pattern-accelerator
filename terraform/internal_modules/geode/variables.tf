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

variable "app_service_plan_tier" {
  type        = string
  description = "Specifies the Azure Functions App Service plan pricing tier."
  default     = "Dynamic"
}

variable "app_service_plan_size" {
  type        = string
  description = "Specifies the Azure Functions App Service plan instance size tier."
  default     = "Y1"
}