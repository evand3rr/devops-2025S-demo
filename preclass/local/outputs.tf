output "app_url" {
  description = "Address to open in a browser to reach the running app"
  value       = "http://localhost:${var.external_port}"
}