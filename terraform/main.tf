provider "azurerm" {
  version = "=1.28.0"
}

provider "azuread" {
  version = "=0.3.0"
}

locals {
  region_codes = {
    "East US" = "eus"
  }

  app_service_name = "${var.app_name}-${lookup(local.region_codes, var.location)}-as"
  client_secret    = "${uuid}"
}

# Create grafana password
resource "random_string" "grafana_password" {
  length = 16
}

resource "azuread_application" "main" {
  name            = "Grafana"
  homepage        = "http://${locals.app_service_name}"
  identifier_uris = ["http://Grafana"]
  reply_urls      = ["https://${locals.app_service_name}/login/generic_oauth"]
}

resource "azuread_application_password" "main" {
  application_id = "${azuread_application.main.id}"
  value          = "${locals.client_secret}"
  end_date       = "2020-01-01T01:02:03Z"
}

resource "azurerm_resource_group" "main" {
  name     = "${var.app_name}-${lookup(local.region_codes, var.location)}-rg"
  location = "${var.location}"
}

resource "azurerm_storage_account" "main" {
  name                     = "${var.app_name}${lookup(local.region_codes, var.location)}st"
  resource_group_name      = "${azurerm_resource_group.main.name}"
  location                 = "${azurerm_resource_group.main.location}"
  access_tier              = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "main" {
  name                  = "grafana"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  storage_account_name  = "${azurerm_storage_account.main.name}"
  container_access_type = "private"
}

resource "azurerm_app_service_plan" "main" {
  name                = "${var.app_name}-${lookup(local.region_codes, var.location)}-ap"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Basic"
    size = "B1"
  }
}

resource "azurerm_app_service" "main" {
  name                = "${local.app_service_name}"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  app_service_plan_id = "${azurerm_app_service_plan.main.id}"

  site_config {
    linux_fx_versoin = "DOCKER|grafana/grafana"
  }

  app_settings = {
    "GF_SERVER_ROOT_URL"                          = "https://${local.app_service_name}.azurewebsites.net"
    "GF_SECURITY_ADMIN_PASSWORD"                  = "${random_string.grafana_password}"
    "GF_INSTALL_PLUGINS"                          = "grafana-clock-panel,grafana-simple-json-datasource,grafana-azure-monitor-datasource"
    "GF_AUTH_GENERIC_OAUTH_ENABLED"               = "true"
    "GF_AUTH_GENERIC_OAUTH_CLIENT_ID"             = "${azuread_application.main.id}"
    "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET"         = "${local.client_secret}"
    "GF_AUTH_GENERIC_OAUTH_SCOPES"                = "openid email name"
    "GF_AUTH_GENERIC_OAUTH_AUTH_URL"              = "https://login.microsoftonline.com/$tenantId/oauth2/authorize"
    "GF_AUTH_GENERIC_OAUTH_TOKEN_URL"             = "https://login.microsoftonline.com/$tenantId/oauth2/token"
    "GF_AUTH_GENERIC_OAUTH_API_URL"               = ""
    "GF_AUTH_GENERIC_OAUTH_TEAM_IDS"              = ""
    "GF_AUTH_GENERIC_OAUTH_ALLOWED_ORGANIZATIONS" = ""
  }

  provisioner "local-exec" {
    command = ""
  }
}
