# Terraform Backend Configuration
# This is a placeholder - actual backend configuration should be created before first run

# Azure Storage Account for Terraform State
# Create with: 
# az storage account create --name <storage-account-name> --resource-group <resource-group> --location <location> --sku Standard_LRS
# az storage container create --name tfstate --account-name <storage-account-name>

terraform {
  # Uncomment and configure for production use
  # backend "azurerm" {
  #   resource_group_name  = "tf-state-rg"
  #   storage_account_name = "tfstateakspoc123"
  #   container_name       = "tfstate"
  #   key                  = "aks-poc.tfstate"
  #   use_azuread_auth     = true
  #   subscription_id      = "7908ea24-a708-4291-be15-98426e3e9ca5"
  #   tenant_id            = "<your-tenant-id>"
  # }
  
  # For local development, terraform will use local state
  # To use remote state, uncomment the backend block above
}

# Alternative: Use Azure CLI authentication
# Run: az login before running terraform init