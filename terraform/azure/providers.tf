# providers.tf
# Tells Terraform which version to use, where to keep state (HCP Terraform),
# and which cloud provider plugin to download (Azure).

terraform {
  # Any Terraform from 1.5 upwards. (A hard pin like "1.17.1" fails if your
  # installed version is even slightly different.)
  required_version = ">= 1.5.0"

  # Store state in HCP Terraform. The organization and workspace come from the
  # environment variables you export before running:
  #   export TF_CLOUD_ORGANIZATION=alu-devops-YOUR_NAME
  #   export TF_WORKSPACE=campus-notifier-infra
  # so nobody else's organization name is hard-coded here.
  cloud {}

  required_providers {
    # The Azure plugin. The registry name is "azurerm" (not "azure").
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Connects Terraform to Azure.
# - features {} is required (it can be empty).
# - subscription_id is required by azurerm 4.x. If var.subscription_id is null,
#   the provider falls back to the ARM_SUBSCRIPTION_ID environment variable.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
