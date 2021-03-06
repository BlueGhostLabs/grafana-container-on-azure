terraform {
  required_version = ">=0.13.2"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.27.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "1.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "2.3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create random code to tack on to names.
resource "random_string" "random_code" {
  length  = 4
  upper   = false
  special = false
}

locals {
  region_codes = {
    "East US" = "eus"
  }

  end_date         = "2022-01-01T01:02:03Z"
  app_service_name = "${var.app_name}${random_string.random_code.result}-${lookup(local.region_codes, var.location)}-as"
}

# Create Client Secret
resource "random_uuid" "client_secret" {}

# Create grafana password
resource "random_string" "grafana_password" {
  length = 16
}

resource "azurerm_resource_group" "main" {
  name     = "${var.app_name}-${lookup(local.region_codes, var.location)}-rg"
  location = var.location
}

resource "azurerm_app_service_plan" "main" {
  name                = "${var.app_name}-${lookup(local.region_codes, var.location)}-ap"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Basic"
    size = "B1"
  }
}

resource "azuread_application" "main" {
  name            = "Grafana"
  homepage        = "https://${local.app_service_name}.azurewebsites.net"
  identifier_uris = ["https://Grafana"]
  reply_urls      = ["https://${local.app_service_name}.azurewebsites.net/login/generic_oauth"]
}

resource "azuread_application_password" "main" {
  application_object_id = azuread_application.main.id
  value                 = random_uuid.client_secret.result
  end_date              = local.end_date
}

resource "azurerm_app_service" "main" {
  name                = local.app_service_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  app_service_plan_id = azurerm_app_service_plan.main.id
  https_only          = true

  site_config {
    linux_fx_version = "DOCKER|grafana/grafana"
  }

  app_settings = {
    GF_SERVER_ROOT_URL                          = "https://${local.app_service_name}.azurewebsites.net"
    GF_SECURITY_ADMIN_PASSWORD                  = random_string.grafana_password.result
    GF_INSTALL_PLUGINS                          = "grafana-clock-panel,grafana-simple-json-datasource,grafana-azure-monitor-datasource"
    GF_AUTH_GENERIC_OAUTH_NAME                  = "Azure AD"
    GF_AUTH_GENERIC_OAUTH_ENABLED               = "true"
    GF_AUTH_GENERIC_OAUTH_CLIENT_ID             = azuread_application.main.application_id
    GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET         = random_uuid.client_secret.result
    GF_AUTH_GENERIC_OAUTH_SCOPES                = "openid"
    GF_AUTH_GENERIC_OAUTH_AUTH_URL              = "https://login.windows.net/<tenantID>/oauth2/authorize"
    GF_AUTH_GENERIC_OAUTH_TOKEN_URL             = "https://login.windows.net/<tenantID>/oauth2/token"
    GF_AUTH_GENERIC_OAUTH_API_URL               = ""
    GF_AUTH_GENERIC_OAUTH_TEAM_IDS              = ""
    GF_AUTH_GENERIC_OAUTH_ALLOWED_ORGANIZATIONS = ""
  }
}
