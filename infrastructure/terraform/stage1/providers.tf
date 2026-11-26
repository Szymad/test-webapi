terraform {

  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true

    tenant_id            = "663e9d65-8459-46ae-9360-fd3933eefea3"
    client_id            = "e01f0406-d7eb-434b-a161-07450465202d"
    storage_account_name = "sttfstate1795708006"
    container_name       = "tfstate"
    key                  = "stage1.tfstate"
  }

  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }

  }
}

provider "azurerm" {
  features {}
  subscription_id = "8040e115-3fa1-4ec5-988f-1fc4e10a4237"
}

provider "azuread" {}
