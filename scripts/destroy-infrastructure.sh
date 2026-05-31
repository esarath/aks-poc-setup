#!/bin/bash

# AKS POC Infrastructure Destruction Script
# This script destroys all infrastructure created by the deployment script

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SUBSCRIPTION_ID="7908ea24-a708-4291-be15-98426e3e9ca5"
RESOURCE_GROUP="rg-aks-poc"

# Functions for colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        exit 1
    fi
    print_success "Azure CLI is installed"
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    print_success "Terraform is installed"
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    print_success "kubectl is installed"
    
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed"
        exit 1
    fi
    print_success "Helm is installed"
    
    echo ""
}

# Confirm destruction
confirm_destruction() {
    print_header "DANGER ZONE - Infrastructure Destruction"
    
    print_warning "This will permanently destroy all resources in resource group: $RESOURCE_GROUP"
    print_warning "This action cannot be undone!"
    echo ""
    
    read -p "Are you sure you want to proceed? Type 'DESTROY' to confirm: " confirmation
    if [ "$confirmation" != "DESTROY" ]; then
        print_error "Destruction cancelled"
        exit 1
    fi
    
    echo ""
}

# Login to Azure
azure_login() {
    print_header "Azure Authentication"
    
    print_info "Logging in to Azure..."
    az login
    print_success "Logged in to Azure"
    
    print_info "Setting subscription..."
    az account set --subscription $SUBSCRIPTION_ID
    print_success "Subscription set to $SUBSCRIPTION_ID"
    
    echo ""
}

# Destroy Kubernetes resources
destroy_kubernetes_resources() {
    print_header "Destroying Kubernetes Resources"
    
    if kubectl cluster-info &> /dev/null; then
        # Get AKS credentials
        print_info "Getting AKS credentials..."
        az aks get-credentials \
            --resource-group $RESOURCE_GROUP \
            --name aks-poc-cluster \
            --admin
        print_success "AKS credentials retrieved"
        
        # Delete ArgoCD
        print_info "Deleting ArgoCD..."
        kubectl delete namespace argocd --ignore-not-found=true
        print_success "ArgoCD deleted"
        
        # Delete monitoring stack
        print_info "Deleting monitoring stack..."
        helm uninstall prometheus -n monitoring --ignore-not-found=true
        kubectl delete namespace monitoring --ignore-not-found=true
        print_success "Monitoring stack deleted"
        
        # Delete ingress controller
        print_info "Deleting ingress controller..."
        helm uninstall ingress-nginx -n ingress-nginx --ignore-not-found=true
        kubectl delete namespace ingress-nginx --ignore-not-found=true
        print_success "Ingress controller deleted"
        
        # Delete application
        print_info "Deleting sample application..."
        helm uninstall myapp -n production --ignore-not-found=true
        kubectl delete namespace production --ignore-not-found=true
        print_success "Sample application deleted"
    else
        print_warning "Cluster not accessible, skipping Kubernetes resource deletion"
    fi
    
    echo ""
}

# Destroy Terraform infrastructure
destroy_terraform() {
    print_header "Destroying Terraform Infrastructure"
    
    cd terraform
    
    # Check if storage account env file exists
    if [ -f "../storage-account.env" ]; then
        STORAGE_ACCOUNT_NAME=$(cat ../storage-account.env | cut -d'=' -f2)
        
        # Update backend configuration
        cat > backend.tf <<EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "$RESOURCE_GROUP"
    storage_account_name = "$STORAGE_ACCOUNT_NAME"
    container_name       = "tfstate"
    key                  = "aks-poc.tfstate"
  }
}
EOF
    fi
    
    # Initialize Terraform
    print_info "Initializing Terraform..."
    terraform init
    print_success "Terraform initialized"
    
    # Destroy infrastructure
    print_warning "Destroying all Terraform-managed resources..."
    terraform destroy \
        -var="environment=poc" \
        -var="subscription_id=$SUBSCRIPTION_ID" \
        -var="resource_group_name=$RESOURCE_GROUP" \
        -var="location=eastus" \
        -auto-approve
    
    print_success "Terraform infrastructure destroyed"
    
    cd ..
    echo ""
}

# Delete resource group
delete_resource_group() {
    print_header "Deleting Resource Group"
    
    print_warning "Deleting entire resource group: $RESOURCE_GROUP"
    read -p "Are you sure you want to delete the entire resource group? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deleting resource group..."
        az group delete --name $RESOURCE_GROUP --yes --no-wait
        print_success "Resource group deletion initiated"
        print_info "This may take several minutes to complete"
    else
        print_warning "Resource group deletion cancelled"
    fi
    
    echo ""
}

# Clean up local files
cleanup_local_files() {
    print_header "Cleaning Up Local Files"
    
    print_info "Removing temporary files..."
    rm -f storage-account.env
    print_success "Temporary files removed"
    
    echo ""
}

# Final verification
verify_destruction() {
    print_header "Final Verification"
    
    print_info "Checking if resource group still exists..."
    if az group show --name $RESOURCE_GROUP &> /dev/null; then
        print_warning "Resource group still exists - deletion may be in progress"
    else
        print_success "Resource group has been deleted"
    fi
    
    echo ""
}

# Print destruction summary
print_summary() {
    print_header "Destruction Summary"
    
    print_success "AKS POC infrastructure destruction completed!"
    echo ""
    print_info "Important Information:"
    echo "  - Resource Group: $RESOURCE_GROUP"
    echo "  - Most resources have been destroyed"
    echo "  - Some resources may still be deleting in the background"
    echo ""
    print_warning "Remaining Actions:"
    echo "  - Check Azure Portal for any remaining resources"
    echo "  - Delete any manually created resources"
    echo "  - Remove any DNS records for your domain"
    echo "  - Remove any secrets from Azure Key Vault"
    echo ""
}

# Main execution function
main() {
    print_header "AKS POC Infrastructure Destruction"
    print_info "Starting destruction process..."
    echo ""
    
    check_prerequisites
    confirm_destruction
    azure_login
    destroy_kubernetes_resources
    destroy_terraform
    delete_resource_group
    cleanup_local_files
    verify_destruction
    print_summary
    
    print_success "Destruction completed successfully!"
}

# Run main function
main