output "grafana_password" {
  value = "${random_string.grafana_password}"
}

output "grafana_address" {
  value = "${azurerm_app_service.main.default_site_hostname}"
}

output "client_secret" {
  value = "${random_uuid.client_secret.result}"
}
