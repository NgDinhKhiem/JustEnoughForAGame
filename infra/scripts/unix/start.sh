#!/bin/bash

# JustEnoughForAGame Infrastructure Start Script
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

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Start JustEnoughForAGame infrastructure services"
    echo ""
    echo "OPTIONS:"
    echo "  -e, --environment    Environment (local|dev|staging|prod) [default: local]"
    echo "  -p, --platform      Platform (docker|k8s|aws) [default: docker]"
    echo "  -s, --services      Specific services to start (comma-separated)"
    echo "  -m, --monitoring    Include monitoring stack [default: false]"
    echo "  -w, --wait         Wait for services to be healthy [default: true]"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                                   # Start local development environment"
    echo "  $0 -e dev -p k8s                   # Start dev environment on Kubernetes"
    echo "  $0 -s redis,postgres               # Start only Redis and PostgreSQL"
    echo "  $0 -m                              # Start with monitoring stack"
    echo ""
}

# Default values
ENVIRONMENT="local"
PLATFORM="docker"
SERVICES=""
MONITORING=false
WAIT_FOR_HEALTH=true

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
        --monitoring|-m)
            MONITORING=true
            shift
            ;;
        --no-wait)
            WAIT_FOR_HEALTH=false
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

log_info "🎮 Starting JustEnoughForAGame Infrastructure"
log_info "Environment: $ENVIRONMENT"
log_info "Platform: $PLATFORM"
log_info "Monitoring: $MONITORING"

# Function to start Docker Compose services
start_docker_services() {
    local compose_dir="$PROJECT_ROOT/docker-compose"
    cd "$compose_dir"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found in $compose_dir"
        exit 1
    fi
    
    log_info "🐳 Starting Docker Compose services..."
    
    if [[ -n "$SERVICES" ]]; then
        log_info "Starting specific services: $SERVICES"
        IFS=',' read -ra SERVICE_ARRAY <<< "$SERVICES"
        docker-compose up -d "${SERVICE_ARRAY[@]}"
    else
        # Start core services first
        log_info "Starting core infrastructure services..."
        docker-compose up -d redis postgres zookeeper kafka
        
        if [[ $WAIT_FOR_HEALTH == true ]]; then
            wait_for_service "redis"
            wait_for_service "postgres"
            wait_for_service "kafka"
        fi
        
        # Start application services
        log_info "Starting analytics and monitoring services..."
        docker-compose up -d clickhouse dynamodb-local localstack
        
        # Start development tools if in local/dev environment
        if [[ "$ENVIRONMENT" == "local" || "$ENVIRONMENT" == "dev" ]]; then
            log_info "Starting development tools..."
            docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d \
                kafka-ui redis-commander pgadmin
        fi
        
        # Start monitoring stack if requested
        if [[ $MONITORING == true ]]; then
            log_info "Starting monitoring stack..."
            docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d \
                prometheus grafana jaeger
        fi
    fi
}

# Function to start Kubernetes services
start_k8s_services() {
    local k8s_dir="$PROJECT_ROOT/deployment/kubernetes"
    
    if [[ ! -d "$k8s_dir" ]]; then
        log_error "Kubernetes deployment directory not found: $k8s_dir"
        exit 1
    fi
    
    log_info "☸️  Deploying to Kubernetes..."
    
    # Apply namespace first
    kubectl apply -f "$k8s_dir/namespace.yaml"
    
    # Apply configurations
    kubectl apply -f "$k8s_dir/configmap.yaml"
    
    # Apply services
    if [[ -n "$SERVICES" ]]; then
        IFS=',' read -ra SERVICE_ARRAY <<< "$SERVICES"
        for service in "${SERVICE_ARRAY[@]}"; do
            if [[ -f "$k8s_dir/${service}-service.yaml" ]]; then
                kubectl apply -f "$k8s_dir/${service}-service.yaml"
            fi
        done
    else
        kubectl apply -f "$k8s_dir/"
    fi
    
    # Wait for deployments if requested
    if [[ $WAIT_FOR_HEALTH == true ]]; then
        log_info "Waiting for deployments to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment --all -n game-namespace
    fi
}

# Function to start AWS services
start_aws_services() {
    local aws_dir="$PROJECT_ROOT/deployment/aws"
    
    if [[ ! -f "$aws_dir/deploy.sh" ]]; then
        log_error "AWS deployment script not found: $aws_dir/deploy.sh"
        exit 1
    fi
    
    log_info "☁️  Deploying to AWS..."
    cd "$aws_dir"
    ./deploy.sh --environment "$ENVIRONMENT"
}

# Function to wait for service to be healthy (Docker only)
wait_for_service() {
    local service_name=$1
    local max_attempts=30
    local attempt=1
    
    log_info "⏳ Waiting for $service_name to be healthy..."
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose ps "$service_name" 2>/dev/null | grep -q "healthy\|Up"; then
            log_info "✅ $service_name is ready!"
            return 0
        fi
        
        log_debug "🔄 Attempt $attempt/$max_attempts - $service_name not ready yet..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    log_warn "⚠️  $service_name failed to become healthy within expected time"
    return 1
}

# Validate prerequisites
validate_prerequisites() {
    case $PLATFORM in
        docker)
            if ! command -v docker &> /dev/null; then
                log_error "Docker is not installed"
                exit 1
            fi
            if ! docker info > /dev/null 2>&1; then
                log_error "Docker is not running"
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
            if ! aws sts get-caller-identity &> /dev/null; then
                log_error "AWS credentials are not configured"
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
            start_docker_services
            ;;
        k8s)
            start_k8s_services
            ;;
        aws)
            start_aws_services
            ;;
        *)
            log_error "Unsupported platform: $PLATFORM"
            exit 1
            ;;
    esac
    
    log_info "🎉 Infrastructure started successfully!"
    
    # Show service information
    if [[ $PLATFORM == "docker" ]]; then
        log_info ""
        log_info "📋 Service URLs:"
        log_info "   🔴 Redis Commander:    http://localhost:8081"
        log_info "   🐘 pgAdmin:           http://localhost:8082"
        log_info "   📨 Kafka UI:          http://localhost:8080"
        log_info "   🔍 ClickHouse:        http://localhost:8123"
        log_info "   🏠 LocalStack:        http://localhost:4566"
        log_info "   📊 DynamoDB Local:    http://localhost:8000"
        
        if [[ $MONITORING == true ]]; then
            log_info "   📈 Prometheus:        http://localhost:9090"
            log_info "   📊 Grafana:          http://localhost:3000"
            log_info "   🔍 Jaeger:           http://localhost:16686"
        fi
    fi
    
    log_info ""
    log_info "🛑 To stop: ./stop.sh"
    log_info "📊 To check status: ./status.sh"
    log_info "📝 To view logs: ./logs.sh"
}

# Execute main function
main
