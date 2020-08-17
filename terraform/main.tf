provider "azurerm" {
  version = "=1.34.0"
  skip_provider_registration = true
}

provider "azuread" {
  version = "0.6.0"
}

provider "random" {
  version = "2.2.1"
}

locals {
  region_codes = {
    "East US" = "eus"
  }

  app_service_name = "${var.app_name}-${lookup(local.region_codes, var.location)}-as"
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

resource "azurerm_storage_account" "main" {
  name                     = "${var.app_name}${lookup(local.region_codes, var.location)}st"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "LRS"
  enable_blob_encryption    = true
  enable_https_traffic_only = true
}

resource "azurerm_storage_container" "main" {
  name                  = var.app_name
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
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
  value          = random_uuid.client_secret.result
  end_date       = "2020-01-01T01:02:03Z"
}

resource "azurerm_app_service" "main" {
  name                = "${local.app_service_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  app_service_plan_id = azurerm_app_service_plan.main.id
  https_only = true

  site_config {
    linux_fx_version = "DOCKER|grafana/grafana"
  }

  storage_account {
      name = var.app_name
      type = "AzureBlob"
      account_name = azurerm_storage_account.main.name
      share_name = var.app_name
      access_key = azurerm_storage_account.main.primary_access_key
      mount_path = "/var/lib/grafana"
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
