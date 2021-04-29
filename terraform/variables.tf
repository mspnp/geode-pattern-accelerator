

variable "baseName" {
  type        = string
  description = "The base name for created resources, used for tagging as a group."
}

variable "primaryLocation" {
  type        = string
  description = "The Azure region in which to deploy the Resource Group as well as Cosmos DB, API, and Key Vault resources."
}

variable "additionalLocations" {
  type        = list(string)
  description = "The additional Azure regions in which to deploy API resources."
}

variable "databaseMaxThroughput" {
  type        = number
  description = "The maximum throughput of the SQL database (RU/s). Must be between 100,000 and 1,000,000. Must be set in increments of 1,000."
  default     = 10000
  validation {
    condition     = var.databaseMaxThroughput >= 10000 && var.databaseMaxThroughput <= 1000000
    error_message = "Variable databaseMaxThroughput must be between 10,000 and 1,000,000."
  }
}

variable "containerMaxThroughput" {
  type        = number
  description = "The maximum throughput of the SQL container (RU/s). Must be between 10,000 and 100,000. Must be set in increments of 1,000."
  default     = 4000
  validation {
    condition     = var.containerMaxThroughput >= 4000
    error_message = "Variable containerMaxThroughput must be greater than 4,000."
  }
}

variable "availabilityZones" {
  type        = bool
  description = "Should zone redundancy be enabled for the Cosmos DB regions?"
  default     = false
}

variable "multiRegionWrite" {
  type        = bool
  description = "Enable multi-master support for the Cosmos DB account."
  default     = false
}

variable "consistencyLevel" {
  type        = string
  description = "The Consistency Level to use for the CosmosDB Account - can be either BoundedStaleness, Eventual, Session, Strong or ConsistentPrefix."
  default     = "Session"
  validation {
    condition     = var.consistencyLevel == "Session" || var.consistencyLevel == "BoundedStaleness" || var.consistencyLevel == "Eventual" || var.consistencyLevel == "Strong" || var.consistencyLevel == "ConsistentPrefix"
    error_message = "Variable consistencyLevel must be either BoundedStaleness, Eventual, Session, Strong or ConsistentPrefix."
  }
}

variable "appServicePlanTier" {
  type        = string
  description = "Specifies the Azure Function's App Service plan pricing tier."
  default     = "Dynamic"
}

variable "appServicePlanSize" {
  type        = string
  description = "Specifies the Azure Function's App Service plan instance size tier."
  default     = "Y1"
}