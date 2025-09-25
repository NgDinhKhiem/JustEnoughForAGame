#!/bin/bash

# JustEnoughForAGame Infrastructure Stop Script
# Supports local development, AWS, and Kubernetes deployments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Stop JustEnoughForAGame infrastructure services"
    echo ""
    echo "OPTIONS:"
    echo "  -e, --environment    Environment (local|dev|staging|prod) [default: local]"
    echo "  -p, --platform      Platform (docker|k8s|aws) [default: docker]"
    echo "  -s, --services      Specific services to stop (comma-separated)"
    echo "  -v, --volumes       Remove volumes (docker only) [default: false]"
    echo "  -n, --networks      Remove networks (docker only) [default: false]"
    echo "  -f, --force         Force stop without confirmation [default: false]"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                                   # Stop local development environment"
    echo "  $0 -v -n                           # Stop and clean volumes and networks"
    echo "  $0 -s redis,postgres               # Stop only Redis and PostgreSQL"
    echo "  $0 -p k8s -f                       # Force stop Kubernetes services"
    echo ""
}

# Default values
ENVIRONMENT="local"
PLATFORM="docker"
SERVICES=""
REMOVE_VOLUMES=false
REMOVE_NETWORKS=false
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment|-e)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --platform|-p)
            PLATFORM="$2"
            shift 2
            ;;
        --services|-s)
            SERVICES="$2"
            shift 2
            ;;
        --volumes|-v)
            REMOVE_VOLUMES=true
            shift
            ;;
        --networks|-n)
            REMOVE_NETWORKS=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

log_info "🛑 Stopping JustEnoughForAGame Infrastructure"
log_info "Environment: $ENVIRONMENT"
log_info "Platform: $PLATFORM"

# Function to stop Docker Compose services
stop_docker_services() {
    local compose_dir="$PROJECT_ROOT/docker-compose"
    cd "$compose_dir"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found in $compose_dir"
        exit 1
    fi
    
    log_info "🐳 Stopping Docker Compose services..."
    
    if [[ -n "$SERVICES" ]]; then
        log_info "Stopping specific services: $SERVICES"
        IFS=',' read -ra SERVICE_ARRAY <<< "$SERVICES"
        docker-compose stop "${SERVICE_ARRAY[@]}"
    else
        # Stop all services
        log_info "Stopping all services..."
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml down
    fi
    
    # Handle volumes cleanup
    if [[ $REMOVE_VOLUMES == true ]]; then
        if [[ $FORCE == false ]]; then
            read -p "🗑️  Are you sure you want to remove all data volumes? (y/N): " confirm_volumes
            if [[ ! $confirm_volumes =~ ^[Yy]$ ]]; then
                REMOVE_VOLUMES=false
            fi
        fi
        
        if [[ $REMOVE_VOLUMES == true ]]; then
            log_info "🧹 Removing volumes..."
            docker-compose -f docker-compose.yml -f docker-compose.dev.yml down -v
            docker volume prune -f
            log_info "✅ Volumes removed"
        fi
    fi
    
    # Handle networks cleanup
    if [[ $REMOVE_NETWORKS == true ]]; then
        if [[ $FORCE == false ]]; then
            read -p "🌐 Are you sure you want to remove networks? (y/N): " confirm_networks
            if [[ ! $confirm_networks =~ ^[Yy]$ ]]; then
                REMOVE_NETWORKS=false
            fi
        fi
        
        if [[ $REMOVE_NETWORKS == true ]]; then
            log_info "🧹 Removing networks..."
            docker network prune -f
            log_info "✅ Networks removed"
        fi
    fi
}

# Function to stop Kubernetes services
stop_k8s_services() {
    local k8s_dir="$PROJECT_ROOT/deployment/kubernetes"
    
    if [[ ! -d "$k8s_dir" ]]; then
        log_error "Kubernetes deployment directory not found: $k8s_dir"
        exit 1
    fi
    
    log_info "☸️  Stopping Kubernetes services..."
    
    if [[ -n "$SERVICES" ]]; then
        IFS=',' read -ra SERVICE_ARRAY <<< "$SERVICES"
        for service in "${SERVICE_ARRAY[@]}"; do
            if [[ -f "$k8s_dir/${service}-service.yaml" ]]; then
                log_info "Deleting $service..."
                kubectl delete -f "$k8s_dir/${service}-service.yaml" --ignore-not-found=true
            fi
        done
    else
        if [[ $FORCE == false ]]; then
            read -p "🗑️  Are you sure you want to delete all Kubernetes resources? (y/N): " confirm_k8s
            if [[ ! $confirm_k8s =~ ^[Yy]$ ]]; then
                log_info "Operation cancelled"
                exit 0
            fi
        fi
        
        log_info "Deleting all resources..."
        kubectl delete -f "$k8s_dir/" --ignore-not-found=true
    fi
}

# Function to stop AWS services (warning only)
stop_aws_services() {
    log_warn "⚠️  AWS service termination requires manual intervention"
    log_info "To stop AWS services:"
    log_info "1. Go to AWS Console"
    log_info "2. Navigate to CloudFormation"
    log_info "3. Delete the stack: justenoughforagame-$ENVIRONMENT-infrastructure"
    log_info "4. Or use AWS CLI:"
    log_info "   aws cloudformation delete-stack --stack-name justenoughforagame-$ENVIRONMENT-infrastructure"
    
    if [[ $FORCE == false ]]; then
        read -p "Do you want to attempt automatic stack deletion? (y/N): " confirm_aws
        if [[ $confirm_aws =~ ^[Yy]$ ]]; then
            log_info "Attempting to delete CloudFormation stack..."
            aws cloudformation delete-stack --stack-name "justenoughforagame-$ENVIRONMENT-infrastructure"
            log_info "Stack deletion initiated. Check AWS Console for progress."
        fi
    fi
}

# Validate prerequisites
validate_prerequisites() {
    case $PLATFORM in
        docker)
            if ! command -v docker &> /dev/null; then
                log_error "Docker is not installed"
                exit 1
            fi
            ;;
        k8s)
            if ! command -v kubectl &> /dev/null; then
                log_error "kubectl is not installed"
                exit 1
            fi
            if ! kubectl cluster-info &> /dev/null; then
                log_error "kubectl cannot connect to cluster"
                exit 1
            fi
            ;;
        aws)
            if ! command -v aws &> /dev/null; then
                log_error "AWS CLI is not installed"
                exit 1
            fi
            ;;
    esac
}

# Main execution
main() {
    validate_prerequisites
    
    case $PLATFORM in
        docker)
            stop_docker_services
            ;;
        k8s)
            stop_k8s_services
            ;;
        aws)
            stop_aws_services
            ;;
        *)
            log_error "Unsupported platform: $PLATFORM"
            exit 1
            ;;
    esac
    
    log_info "✅ Infrastructure stopped successfully!"
    log_info ""
    log_info "🚀 To start again: ./start.sh"
}

# Execute main function
main
