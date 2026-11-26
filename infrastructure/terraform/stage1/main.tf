# Stage 1: infrastructure and database
# --------------------------------------------------
# Variables
# --------------------------------------------------

variable "github_actions_client_id" {
  description = "Client ID of the github-actions-saveapi application"
  type        = string
}

variable "external_api_key" {
  description = "External API key stored in Key Vault"
  type        = string
  sensitive   = true
}

variable "terraform_client_ip" {
  description = "Public IP address allowed to connect to Azure SQL"
  type        = string
}

# --------------------------------------------------
# Current Azure identities
# --------------------------------------------------

data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

# Resolve the GitHub Actions service principal by its Client ID.
data "azuread_service_principal" "github_actions" {
  client_id = var.github_actions_client_id
}

# --------------------------------------------------
# SQL administrators group
# --------------------------------------------------

resource "azuread_group" "sql_admins" {
  display_name     = "SQL-Production-Administrators"
  security_enabled = true
  mail_enabled     = false
}

# Add identity executing Terraform.
resource "azuread_group_member" "current_user" {
  group_object_id  = azuread_group.sql_admins.object_id
  member_object_id = data.azuread_client_config.current.object_id
}

# Add GitHub Actions service principal.
resource "azuread_group_member" "github_actions" {
  group_object_id  = azuread_group.sql_admins.object_id
  member_object_id = data.azuread_service_principal.github_actions.object_id
}

# --------------------------------------------------
# Resource Group
# --------------------------------------------------

resource "azurerm_resource_group" "learning" {
  name     = "rg-terraform-learning"
  location = "West US 3"

  tags = {
    environment = "learning"
    managed_by  = "terraform"
  }
}

# --------------------------------------------------
# App Service Plan
# --------------------------------------------------

resource "azurerm_service_plan" "api_plan" {
  name                = "asp-terraform-learning"
  resource_group_name = azurerm_resource_group.learning.name
  location            = azurerm_resource_group.learning.location

  os_type  = "Linux"
  sku_name = "B1"
}

# --------------------------------------------------
# Key Vault
# --------------------------------------------------

resource "azurerm_key_vault" "learning" {
  name                = "kv-tf-20261113"
  location            = azurerm_resource_group.learning.location
  resource_group_name = azurerm_resource_group.learning.name

  tenant_id = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"

  rbac_authorization_enabled = true

  soft_delete_retention_days = 7
  purge_protection_enabled   = true
}

# Terraform identity can manage Key Vault secrets and read from the Key Vault.
resource "azurerm_role_assignment" "terraform_secrets_officer" {
  scope                = azurerm_key_vault.learning.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "github_keyvault_secrets" {
  scope                = azurerm_key_vault.learning.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# --------------------------------------------------
# App Service
# --------------------------------------------------

resource "azurerm_linux_web_app" "api_app" {
  name                = "web-terraform-learning-20261113"
  resource_group_name = azurerm_resource_group.learning.name
  location            = azurerm_resource_group.learning.location
  service_plan_id     = azurerm_service_plan.api_plan.id

  app_settings = {
    "KeyVault__Uri" = azurerm_key_vault.learning.vault_uri
  }

  site_config {
    application_stack {
      dotnet_version = "10.0"
    }
  }

  # App Service gets its own Service Principal in Entra ID.
  identity {
    type = "SystemAssigned"
  }
}

# App Service Managed Identity can read Key Vault secrets.
resource "azurerm_role_assignment" "webapp_key_vault_access" {
  scope                = azurerm_key_vault.learning.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.api_app.identity[0].principal_id
}

resource "azurerm_key_vault_secret" "api_key" {
  name         = "ExternalApiKey"
  value        = var.external_api_key
  key_vault_id = azurerm_key_vault.learning.id

  depends_on = [
    azurerm_role_assignment.terraform_secrets_officer
  ]
}

# --------------------------------------------------
# Azure SQL Server
# --------------------------------------------------

resource "azurerm_mssql_server" "learning" {
  name                          = "sql-tf-learning-20261116"
  resource_group_name           = azurerm_resource_group.learning.name
  location                      = azurerm_resource_group.learning.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = true

  # Entra ID group is the SQL Server administrator.
  azuread_administrator {
    login_username              = azuread_group.sql_admins.display_name
    object_id                   = azuread_group.sql_admins.object_id
    azuread_authentication_only = true
  }
}

# --------------------------------------------------
# Azure SQL Firewall
# --------------------------------------------------

resource "azurerm_mssql_firewall_rule" "terraform_client" {
  name      = "Allow-Terraform-Client"
  server_id = azurerm_mssql_server.learning.id

  start_ip_address = var.terraform_client_ip
  end_ip_address   = var.terraform_client_ip
}

# --------------------------------------------------
# Azure SQL Database
# --------------------------------------------------

resource "azurerm_mssql_database" "learning" {
  name      = "db-terraform-learning"
  server_id = azurerm_mssql_server.learning.id

  sku_name    = "Basic"
  max_size_gb = 2
}

output "sql_server_name" {
  description = "Azure SQL server name consumed by the managed-identity stage"
  value       = azurerm_mssql_server.learning.name
}

output "sql_database_name" {
  description = "Azure SQL database name consumed by the managed-identity stage"
  value       = azurerm_mssql_database.learning.name
}

output "app_service_name" {
  description = "App Service name used as the SQL managed identity's display name"
  value       = azurerm_linux_web_app.api_app.name
}

output "app_service_principal_id" {
  description = "System-assigned managed identity object ID"
  value       = azurerm_linux_web_app.api_app.identity[0].principal_id
}