#Set the terraform backend
terraform {
  # Backend variables are initialized by Azure DevOps
  backend "azurerm" {}
  required_version = "0.13.5"
}
