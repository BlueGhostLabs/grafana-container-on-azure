output "grafana_password" {
  value = "${local.grafana_password}"
}

output "grafana_address" {
  value = "${azurerm_app_service.main.default_site_hostname}"
}

output "client_secret" {
  value = "${local.client_secret}"
}
