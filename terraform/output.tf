output "grafana_password" {
  value = random_string.grafana_password.result
}

output "grafana_address" {
  value = "https://${azurerm_app_service.main.default_site_hostname}"
}

output "client_secret" {
  value = random_uuid.client_secret.result
}
