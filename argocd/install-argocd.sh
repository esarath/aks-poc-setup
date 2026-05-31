#!/bin/bash

# ArgoCD Installation Script for AKS
# This script installs ArgoCD on an AKS cluster

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    echo -e "ℹ $1"
}

# Check if kubectl is installed
check_kubectl() {
    print_info "Checking kubectl installation..."
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    print_success "kubectl is installed"
}

# Check if cluster is accessible
check_cluster() {
    print_info "Checking cluster connectivity..."
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    print_success "Cluster is accessible"
}

# Create ArgoCD namespace
create_namespace() {
    print_info "Creating ArgoCD namespace..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    print_success "ArgoCD namespace created"
}

# Install ArgoCD
install_argocd() {
    print_info "Installing ArgoCD..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    print_success "ArgoCD installed"
}

# Wait for ArgoCD pods to be ready
wait_for_pods() {
    print_info "Waiting for ArgoCD pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    print_success "ArgoCD pods are ready"
}

# Apply custom configuration
apply_custom_config() {
    print_info "Applying custom ArgoCD configuration..."
    
    # Apply custom ConfigMaps
    if [ -f "argocd-cm.yaml" ]; then
        kubectl apply -f argocd-cm.yaml
        print_success "Applied argocd-cm"
    fi
    
    if [ -f "argocd-rbac-cm.yaml" ]; then
        kubectl apply -f argocd-rbac-cm.yaml
        print_success "Applied argocd-rbac-cm"
    fi
    
    if [ -f "argocd-ingress.yaml" ]; then
        kubectl apply -f argocd-ingress.yaml
        print_success "Applied argocd-ingress"
    fi
}

# Apply application and project
apply_application() {
    print_info "Applying ArgoCD application..."
    
    if [ -f "argocd-project.yaml" ]; then
        kubectl apply -f argocd-project.yaml
        print_success "Applied ArgoCD project"
    fi
    
    if [ -f "argocd-application.yaml" ]; then
        kubectl apply -f argocd-application.yaml
        print_success "Applied ArgoCD application"
    fi
}

# Get initial admin password
get_admin_password() {
    print_info "Getting initial admin password..."
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    print_success "Initial admin password retrieved"
    print_warning "Change the default password immediately after first login!"
    print_info "Username: admin"
    print_info "Password: $ARGOCD_PASSWORD"
}

# Port-forward ArgoCD UI
port_forward() {
    print_info "Setting up port-forward for ArgoCD UI..."
    print_warning "To access ArgoCD UI, run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    print_info "Then open http://localhost:8080 in your browser"
}

# Main installation function
main() {
    print_info "Starting ArgoCD installation on AKS..."
    echo ""
    
    check_kubectl
    check_cluster
    create_namespace
    install_argocd
    wait_for_pods
    apply_custom_config
    apply_application
    get_admin_password
    port_forward
    
    echo ""
    print_success "ArgoCD installation completed successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  2. Open browser: http://localhost:8080"
    echo "  3. Login with admin credentials"
    echo "  4. Change default password"
    echo "  5. Configure repositories and applications"
}

# Run main function
main