

variable "base_name" {
  type        = string
  description = "The base name for created resources, used for tagging as a group."
}

variable "primary_location" {
  type        = string
  description = "The Azure region in which to deploy the Resource Group as well as Cosmos DB, API, and Key Vault resources."
}

variable "additional_locations" {
  type        = list(string)
  description = "The additional Azure regions in which to deploy API resources."
}

variable "database_max_throughput" {
  type        = number
  description = "The maximum throughput of the SQL database (RU/s). Must be between 100,000 and 1,000,000. Must be set in increments of 1,000."
  default     = 10000
  validation {
    condition     = var.database_max_throughput >= 10000 && var.database_max_throughput <= 1000000
    error_message = "Variable database_max_throughput must be between 10,000 and 1,000,000."
  }
}

variable "container_max_throughput" {
  type        = number
  description = "The maximum throughput of the SQL container (RU/s). Must be between 10,000 and 100,000. Must be set in increments of 1,000."
  default     = 4000
  validation {
    condition     = var.container_max_throughput >= 4000
    error_message = "Variable container_max_throughput must be greater than 4,000."
  }
}

variable "availability_zones" {
  type        = bool
  description = "Should zone redundancy be enabled for the Cosmos DB regions?"
  default     = false
}

variable "multi_region_write" {
  type        = bool
  description = "Enable multi-master support for the Cosmos DB account."
  default     = false
}

variable "consistency_level" {
  type        = string
  description = "The Consistency Level to use for the CosmosDB Account - can be either BoundedStaleness, Eventual, Session, Strong or ConsistentPrefix."
  default     = "Session"
  validation {
    condition     = var.consistency_level == "Session" || var.consistency_level == "BoundedStaleness" || var.consistency_level == "Eventual" || var.consistency_level == "Strong" || var.consistency_level == "ConsistentPrefix"
    error_message = "Variable consistency_level must be either BoundedStaleness, Eventual, Session, Strong or ConsistentPrefix."
  }
}

variable "app_service_sku" {
  type        = string
  description = "Specifies the Azure Functions App Service SKU."
  default     = "Y1"
}

variable "front_door_sku" {
  type        = string
  description = "Specifies the Azure Front Door SKU."
  default     = "Standard_AzureFrontDoor"
}
