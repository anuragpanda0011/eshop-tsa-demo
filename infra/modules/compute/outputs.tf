output "web_app_id" {
  value = azurerm_linux_web_app.web.id
}

output "web_app_name" {
  value = azurerm_linux_web_app.web.name
}

output "web_app_default_hostname" {
  value = azurerm_linux_web_app.web.default_hostname
}

output "web_app_principal_id" {
  value = azurerm_linux_web_app.web.identity[0].principal_id
}

output "web_staging_principal_id" {
  value = azurerm_linux_web_app_slot.web_staging.identity[0].principal_id
}

output "api_app_id" {
  value = azurerm_linux_web_app.api.id
}

output "api_app_name" {
  value = azurerm_linux_web_app.api.name
}

output "api_app_default_hostname" {
  value = azurerm_linux_web_app.api.default_hostname
}

output "api_app_principal_id" {
  value = azurerm_linux_web_app.api.identity[0].principal_id
}

output "api_staging_principal_id" {
  value = azurerm_linux_web_app_slot.api_staging.identity[0].principal_id
}

output "storage_account_id" {
  value = azurerm_storage_account.images.id
}

output "storage_account_name" {
  value = azurerm_storage_account.images.name
}

output "product_images_container_name" {
  value = azurerm_storage_container.product_images.name
}

output "web_service_plan_id" {
  value = azurerm_service_plan.web.id
}

output "api_service_plan_id" {
  value = azurerm_service_plan.api.id
}
