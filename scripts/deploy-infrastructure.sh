#!/bin/bash

# AKS POC Infrastructure Deployment Script
# This script automates the deployment of the complete AKS infrastructure
# Usage: ./deploy-infrastructure.sh (run from project root or scripts directory)

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root for consistent execution
cd "$PROJECT_ROOT"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SUBSCRIPTION_ID="7908ea24-a708-4291-be15-98426e3e9ca5"
RESOURCE_GROUP="rg-aks-poc"
LOCATION="eastus"
ENVIRONMENT="poc"

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
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        print_info "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    print_success "Azure CLI is installed"
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        print_info "Install from: https://www.terraform.io/downloads.html"
        exit 1
    fi
    print_success "Terraform is installed"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        print_info "Install from: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    print_success "kubectl is installed"
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed"
        print_info "Install from: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    print_success "Helm is installed"
    
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

# Create resource group
create_resource_group() {
    print_header "Creating Resource Group"
    
    if az group show --name $RESOURCE_GROUP &> /dev/null; then
        print_warning "Resource group '$RESOURCE_GROUP' already exists"
    else
        print_info "Creating resource group: $RESOURCE_GROUP"
        az group create --name $RESOURCE_GROUP --location $LOCATION
        print_success "Resource group created"
    fi
    
    echo ""
}

# Create storage account for Terraform state
create_storage_account() {
    print_header "Creating Storage Account for Terraform State"
    
    STORAGE_ACCOUNT_NAME="tfstateakspoc$(echo $RANDOM | md5sum | head -c 8)"
    
    print_info "Creating storage account: $STORAGE_ACCOUNT_NAME"
    az storage account create \
        --name $STORAGE_ACCOUNT_NAME \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --sku Standard_LRS \
        --kind StorageV2 \
        --allow-blob-public-access false \
        --auth-mode login
    
    print_success "Storage account created"
    
    print_info "Creating storage container..."
    az storage container create \
        --name tfstate \
        --account-name $STORAGE_ACCOUNT_NAME \
        --auth-mode login
    
    print_success "Storage container created"
    
    print_info "Storage account name: $STORAGE_ACCOUNT_NAME"
    echo "STORAGE_ACCOUNT_NAME=$STORAGE_ACCOUNT_NAME" > "$SCRIPT_DIR/storage-account.env"
    
    echo ""
}

# Deploy Terraform infrastructure
deploy_terraform() {
    print_header "Deploying Terraform Infrastructure"
    
    cd "$PROJECT_ROOT/terraform"
    
    # Update backend configuration
    print_info "Updating Terraform backend configuration..."
    STORAGE_ACCOUNT_NAME=$(cat "$SCRIPT_DIR/storage-account.env" | cut -d'=' -f2)
    
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
    
    # Initialize Terraform
    print_info "Initializing Terraform..."
    terraform init -upgrade
    print_success "Terraform initialized"
    
    # Validate configuration
    print_info "Validating Terraform configuration..."
    terraform validate
    print_success "Terraform configuration validated"
    
    # Plan infrastructure
    print_info "Planning infrastructure changes..."
    terraform plan -out=tfplan \
        -var="environment=$ENVIRONMENT" \
        -var="subscription_id=$SUBSCRIPTION_ID" \
        -var="resource_group_name=$RESOURCE_GROUP" \
        -var="location=$LOCATION"
    
    print_success "Terraform plan completed"
    print_warning "Review the plan above before proceeding"
    read -p "Do you want to apply the plan? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Apply infrastructure
        print_info "Applying infrastructure changes..."
        terraform apply tfplan
        print_success "Infrastructure deployed successfully"
    else
        print_warning "Infrastructure deployment cancelled"
        exit 0
    fi
    
    cd "$PROJECT_ROOT"
    echo ""
}

# Get AKS credentials
get_aks_credentials() {
    print_header "Getting AKS Credentials"
    
    print_info "Getting AKS credentials..."
    az aks get-credentials \
        --resource-group $RESOURCE_GROUP \
        --name aks-poc-cluster \
        --admin
    
    print_success "AKS credentials retrieved"
    
    # Verify cluster access
    print_info "Verifying cluster access..."
    kubectl get nodes
    print_success "Cluster access verified"
    
    echo ""
}

# Deploy observability stack
deploy_observability() {
    print_header "Deploying Observability Stack"
    
    # Create monitoring namespace
    print_info "Creating monitoring namespace..."
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    print_success "Monitoring namespace created"
    
    # Add Helm repositories
    print_info "Adding Helm repositories..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    print_success "Helm repositories added"
    
    # Install kube-prometheus-stack
    print_info "Installing kube-prometheus-stack..."
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --timeout 10m
    print_success "kube-prometheus-stack installed"
    
    # Enable Azure Monitor
    print_info "Enabling Azure Monitor..."
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name aks-poc-cluster \
        --enable-container-insights
    print_success "Azure Monitor enabled"
    
    echo ""
}

# Deploy ingress controller
deploy_ingress() {
    print_header "Deploying Ingress Controller"
    
    # Create ingress namespace
    print_info "Creating ingress namespace..."
    kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
    print_success "Ingress namespace created"
    
    # Install NGINX ingress controller
    print_info "Installing NGINX ingress controller..."
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --set controller.replicaCount=3 \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal"="false"
    print_success "NGINX ingress controller installed"
    
    # Get external IP
    print_info "Waiting for external IP..."
    sleep 30
    EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    print_success "External IP: $EXTERNAL_IP"
    
    echo ""
}

# Deploy ArgoCD
deploy_argocd() {
    print_header "Deploying ArgoCD"
    
    # Create ArgoCD namespace
    print_info "Creating ArgoCD namespace..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    print_success "ArgoCD namespace created"
    
    # Install ArgoCD
    print_info "Installing ArgoCD..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    print_success "ArgoCD installed"
    
    # Wait for ArgoCD pods
    print_info "Waiting for ArgoCD pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    print_success "ArgoCD pods are ready"
    
    # Get ArgoCD password
    print_info "Getting ArgoCD admin password..."
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    print_success "ArgoCD admin password: $ARGOCD_PASSWORD"
    print_warning "Change the default password immediately!"
    
    # Apply custom ArgoCD configuration
    if [ -f "argocd/argocd-application.yaml" ]; then
        print_info "Applying ArgoCD application configuration..."
        kubectl apply -f argocd/argocd-application.yaml
        kubectl apply -f argocd/argocd-project.yaml
        print_success "ArgoCD configuration applied"
    fi
    
    echo ""
}

# Deploy sample application
deploy_application() {
    print_header "Deploying Sample Application"
    
    # Create production namespace
    print_info "Creating production namespace..."
    kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
    print_success "Production namespace created"
    
    # Install application using Helm
    print_info "Installing sample application..."
    helm install myapp helm-charts/myapp \
        --namespace production \
        --create-namespace \
        --values helm-charts/myapp/values-prod.yaml \
        --set image.tag=latest
    print_success "Sample application installed"
    
    # Wait for deployment
    print_info "Waiting for application to be ready..."
    kubectl rollout status deployment/myapp -n production --timeout=300s
    print_success "Application is ready"
    
    echo ""
}

# Final verification
verify_deployment() {
    print_header "Final Verification"
    
    print_info "Checking all deployments..."
    kubectl get pods -A
    
    print_info "Checking services..."
    kubectl get svc -A
    
    print_info "Checking ingress..."
    kubectl get ingress -A
    
    print_success "All components verified successfully"
    
    echo ""
}

# Print deployment summary
print_summary() {
    print_header "Deployment Summary"
    
    print_success "AKS POC infrastructure deployment completed!"
    echo ""
    print_info "Important Information:"
    echo "  - Resource Group: $RESOURCE_GROUP"
    echo "  - Location: $LOCATION"
    echo "  - AKS Cluster: aks-poc-cluster"
    echo ""
    print_info "Next Steps:"
    echo "  1. Configure DNS for your domain"
    echo "  2. Set up SSL certificates"
    echo "  3. Configure ArgoCD repositories"
    echo "  4. Deploy additional applications"
    echo "  5. Set up monitoring and alerts"
    echo ""
    print_warning "Important:"
    echo "  - Change default passwords immediately"
    echo "  - Review security configurations"
    echo "  - Set up backup and disaster recovery"
    echo "  - Configure cost monitoring and alerts"
    echo ""
}

# Main execution function
main() {
    print_header "AKS POC Infrastructure Deployment"
    print_info "Starting deployment process..."
    echo ""
    
    check_prerequisites
    azure_login
    create_resource_group
    create_storage_account
    deploy_terraform
    get_aks_credentials
    deploy_observability
    deploy_ingress
    deploy_argocd
    deploy_application
    verify_deployment
    print_summary
    
    print_success "Deployment completed successfully!"
}

# Run main function
main