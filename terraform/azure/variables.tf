# variables.tf
# The settings you can change without editing main.tf.

variable "location" {
  description = "Azure region to build the servers in"
  type        = string
  default     = "swedencentral" # if your subscription blocks it, try northeurope or uksouth
}

variable "resource_group_name" {
  description = "Name of the resource group that holds everything"
  type        = string
  default     = "campus-notifier-rg"
}

variable "subscription_id" {
  description = "Azure subscription ID. Leave null to use the ARM_SUBSCRIPTION_ID environment variable."
  type        = string
  default     = null
}

# No default: you must provide it (terraform.tfvars does this, see the echo command in the task).
variable "my_ip_cidr" {
  description = "Your laptop's public IPv4 address with /32, e.g. 41.186.0.10/32"
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0))
    error_message = "my_ip_cidr must look like 41.186.0.10/32."
  }
}

variable "vm_size" {
  description = "Size of each server (how much CPU and memory)"
  type        = string
  default     = "Standard_B2s_v2" # 2 vCPU, 4 GB. Try Standard_B1s if your subscription limits sizes.
}

variable "admin_username" {
  description = "Linux username created on both servers"
  type        = string
  default     = "azureuser"
}

variable "public_key_path" {
  description = "Path to the SSH public key that will be allowed to log into both servers"
  type        = string
  default     = "~/.ssh/alu-devops.pub"
}

variable "app_port" {
  description = "Port the Campus Event Notifier is exposed on"
  type        = number
  default     = 8000
}
