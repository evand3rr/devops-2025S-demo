# outputs.tf
# Values printed after `terraform apply` (and by `terraform output`).

output "instance_public_ip" {
  description = "App server address from the internet (SSH and browser)"
  value       = azurerm_public_ip.app.ip_address
}

output "instance_private_ip" {
  description = "App server address inside the Azure network"
  value       = azurerm_network_interface.app.private_ip_address
}

output "ssh_user" {
  description = "Username to log in with"
  value       = var.admin_username
}

output "app_port" {
  description = "Port the Campus Event Notifier is served on"
  value       = var.app_port
}

output "db_public_ip" {
  description = "Database server address from the internet (SSH only)"
  value       = azurerm_public_ip.db.ip_address
}

output "db_private_ip" {
  description = "Database server address inside Azure - use this as POSTGRES_HOST"
  value       = azurerm_network_interface.db.private_ip_address
}

output "db_ssh_port" {
  description = "Port to SSH into the database server"
  value       = 22
}
