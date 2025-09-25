#!/bin/bash

# JustEnoughForAGame Infrastructure Restart Script
# Graceful restart of services with health checks

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
    echo "Usage: $0 [OPTIONS] [SERVICE]"
    echo ""
    echo "Restart JustEnoughForAGame infrastructure services"
    echo ""
    echo "ARGUMENTS:"
    echo "  SERVICE             Specific service to restart (optional)"
    echo ""
    echo "OPTIONS:"
    echo "  -p, --platform      Platform (docker|k8s|aws) [default: docker]"
    echo "  -e, --environment   Environment (local|dev|staging|prod) [default: local]"
    echo "  -w, --wait          Wait for services to be healthy [default: true]"
    echo "  -t, --timeout       Health check timeout in seconds [default: 300]"
    echo "  -f, --force         Force restart without graceful shutdown [default: false]"
    echo "  -r, --rolling       Rolling restart (K8s only) [default: false]"
    echo "  --no-deps           Don't restart dependencies (Docker only) [default: false]"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                                   # Restart all Docker services"
    echo "  $0 redis                            # Restart only Redis service"
    echo "  $0 -p k8s -r                       # Rolling restart on Kubernetes"
    echo "  $0 -f --no-deps postgres           # Force restart PostgreSQL only"
    echo "  $0 -e staging -t 600               # Restart staging with 10min timeout"
    echo ""
}

# Default values
PLATFORM="docker"
ENVIRONMENT="local"
SERVICE=""
WAIT_FOR_HEALTH=true
TIMEOUT=300
FORCE=false
ROLLING=false
NO_DEPS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform|-p)
            PLATFORM="$2"
            shift 2
            ;;
        --environment|-e)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --wait|-w)
            WAIT_FOR_HEALTH=true
            shift
            ;;
        --no-wait)
            WAIT_FOR_HEALTH=false
            shift
            ;;
        --timeout|-t)
            TIMEOUT="$2"
            shift 2
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --rolling|-r)
            ROLLING=true
            shift
            ;;
        --no-deps)
            NO_DEPS=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$SERVICE" ]]; then
                SERVICE="$1"
            else
                log_error "Multiple services specified: $SERVICE and $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

log_info "🔄 Restarting JustEnoughForAGame Infrastructure"
log_info "Platform: $PLATFORM"
log_info "Environment: $ENVIRONMENT"
if [[ -n "$SERVICE" ]]; then
    log_info "Service: $SERVICE"
fi

# Function to wait for service to be healthy
wait_for_service() {
    local service_name=$1
    local platform=$2
    local max_attempts=$((TIMEOUT / 5))
    local attempt=1
    
    log_info "⏳ Waiting for $service_name to be healthy..."
    
    while [ $attempt -le $max_attempts ]; do
        local is_healthy=false
        
        case $platform in
            docker)
                if docker-compose ps "$service_name" 2>/dev/null | grep -q "healthy\|Up"; then
                    is_healthy=true
                fi
                ;;
            k8s)
                if kubectl get pods -l app="$service_name" -n game-namespace 2>/dev/null | grep -q "Running"; then
                    local ready_pods=$(kubectl get pods -l app="$service_name" -n game-namespace -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o "True" | wc -l)
                    local total_pods=$(kubectl get pods -l app="$service_name" -n game-namespace --no-headers 2>/dev/null | wc -l)
                    if [[ $ready_pods -gt 0 && $ready_pods -eq $total_pods ]]; then
                        is_healthy=true
                    fi
                fi
                ;;
        esac
        
        if [[ $is_healthy == true ]]; then
            log_info "✅ $service_name is healthy!"
            return 0
        fi
        
        echo -n "🔄 Attempt $attempt/$max_attempts - $service_name not ready yet..."
        sleep 5
        attempt=$((attempt + 1))
        echo " retrying"
    done
    
    log_warn "⚠️  $service_name failed to become healthy within ${TIMEOUT}s"
    return 1
}

# Function to restart Docker services
restart_docker_services() {
    local compose_dir="$PROJECT_ROOT/docker-compose"
    cd "$compose_dir" || {
        log_error "Docker compose directory not found: $compose_dir"
        exit 1
    }
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found"
        exit 1
    fi
    
    log_info "🐳 Restarting Docker services..."
    
    if [[ -n "$SERVICE" ]]; then
        # Restart specific service
        log_info "Restarting service: $SERVICE"
        
        if [[ $FORCE == true ]]; then
            log_info "Force killing service..."
            docker-compose kill "$SERVICE" || true
            docker-compose rm -f "$SERVICE" || true
        else
            log_info "Gracefully stopping service..."
            docker-compose stop "$SERVICE" || true
        fi
        
        # Start service
        local start_cmd="docker-compose up -d"
        if [[ $NO_DEPS == true ]]; then
            start_cmd="$start_cmd --no-deps"
        fi
        start_cmd="$start_cmd $SERVICE"
        
        log_info "Starting service..."
        eval "$start_cmd"
        
        # Wait for health check
        if [[ $WAIT_FOR_HEALTH == true ]]; then
            wait_for_service "$SERVICE" "docker"
        fi
    else
        # Restart all services
        log_info "Restarting all services..."
        
        if [[ $FORCE == true ]]; then
            log_info "Force stopping all services..."
            docker-compose kill || true
            docker-compose down --remove-orphans || true
        else
            log_info "Gracefully stopping services..."
            docker-compose down || true
        fi
        
        # Restart based on environment
        log_info "Starting services for environment: $ENVIRONMENT"
        
        if [[ "$ENVIRONMENT" == "local" || "$ENVIRONMENT" == "dev" ]]; then
            docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
        else
            docker-compose up -d
        fi
        
        # Wait for key services to be healthy
        if [[ $WAIT_FOR_HEALTH == true ]]; then
            local key_services=("redis" "postgres" "kafka")
            for service in "${key_services[@]}"; do
                if docker-compose ps "$service" &>/dev/null; then
                    wait_for_service "$service" "docker" || log_warn "Service $service may not be fully ready"
                fi
            done
        fi
    fi
}

# Function to restart Kubernetes services
restart_k8s_services() {
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl not found"
        exit 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_info "☸️  Restarting Kubernetes services..."
    
    local namespace="game-namespace"
    
    if [[ -n "$SERVICE" ]]; then
        # Restart specific service
        log_info "Restarting deployment: $SERVICE"
        
        if [[ $ROLLING == true ]]; then
            log_info "Performing rolling restart..."
            kubectl rollout restart deployment/"$SERVICE" -n "$namespace"
            
            if [[ $WAIT_FOR_HEALTH == true ]]; then
                log_info "Waiting for rollout to complete..."
                kubectl rollout status deployment/"$SERVICE" -n "$namespace" --timeout="${TIMEOUT}s"
            fi
        else
            if [[ $FORCE == true ]]; then
                log_info "Force deleting pods..."
                kubectl delete pods -l app="$SERVICE" -n "$namespace" --force --grace-period=0
            else
                log_info "Scaling down deployment..."
                kubectl scale deployment "$SERVICE" --replicas=0 -n "$namespace"
                
                log_info "Waiting for pods to terminate..."
                kubectl wait --for=delete pods -l app="$SERVICE" -n "$namespace" --timeout=60s
                
                log_info "Scaling up deployment..."
                kubectl scale deployment "$SERVICE" --replicas=1 -n "$namespace"
            fi
            
            if [[ $WAIT_FOR_HEALTH == true ]]; then
                wait_for_service "$SERVICE" "k8s"
            fi
        fi
    else
        # Restart all deployments
        log_info "Restarting all deployments in namespace: $namespace"
        
        local deployments=($(kubectl get deployments -n "$namespace" -o name 2>/dev/null | sed 's/deployment.apps\///'))
        
        if [[ ${#deployments[@]} -eq 0 ]]; then
            log_warn "No deployments found in namespace $namespace"
            return
        fi
        
        if [[ $ROLLING == true ]]; then
            log_info "Performing rolling restart of all deployments..."
            for deployment in "${deployments[@]}"; do
                log_info "Rolling restart: $deployment"
                kubectl rollout restart deployment/"$deployment" -n "$namespace"
            done
            
            if [[ $WAIT_FOR_HEALTH == true ]]; then
                for deployment in "${deployments[@]}"; do
                    log_info "Waiting for $deployment rollout..."
                    kubectl rollout status deployment/"$deployment" -n "$namespace" --timeout="${TIMEOUT}s" || log_warn "Rollout may not have completed for $deployment"
                done
            fi
        else
            for deployment in "${deployments[@]}"; do
                log_info "Restarting deployment: $deployment"
                
                if [[ $FORCE == true ]]; then
                    kubectl delete pods -l app="$deployment" -n "$namespace" --force --grace-period=0
                else
                    kubectl scale deployment "$deployment" --replicas=0 -n "$namespace"
                    kubectl wait --for=delete pods -l app="$deployment" -n "$namespace" --timeout=60s
                    kubectl scale deployment "$deployment" --replicas=1 -n "$namespace"
                fi
                
                if [[ $WAIT_FOR_HEALTH == true ]]; then
                    wait_for_service "$deployment" "k8s" || log_warn "Service $deployment may not be fully ready"
                fi
            done
        fi
    fi
}

# Function to restart AWS services
restart_aws_services() {
    log_info "☁️  AWS service restart..."
    
    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI not found"
        exit 1
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    log_warn "⚠️  AWS services require specific restart procedures"
    
    # ECS Services
    local cluster_name="justenoughforagame-cluster"
    local ecs_services=($(aws ecs list-services --cluster "$cluster_name" --query 'serviceArns[*]' --output text 2>/dev/null | sed 's/.*\///' || true))
    
    if [[ ${#ecs_services[@]} -gt 0 ]]; then
        log_info "Found ECS services: ${ecs_services[*]}"
        
        if [[ -n "$SERVICE" ]]; then
            # Check if service exists in ECS
            local found_service=""
            for ecs_service in "${ecs_services[@]}"; do
                if [[ "$ecs_service" == *"$SERVICE"* ]]; then
                    found_service="$ecs_service"
                    break
                fi
            done
            
            if [[ -n "$found_service" ]]; then
                log_info "Restarting ECS service: $found_service"
                
                if [[ $FORCE == true ]]; then
                    log_info "Forcing new deployment..."
                    aws ecs update-service --cluster "$cluster_name" --service "$found_service" --force-new-deployment
                else
                    log_info "Updating service with new task definition..."
                    aws ecs update-service --cluster "$cluster_name" --service "$found_service" --force-new-deployment
                fi
                
                if [[ $WAIT_FOR_HEALTH == true ]]; then
                    log_info "Waiting for service to stabilize..."
                    aws ecs wait services-stable --cluster "$cluster_name" --services "$found_service"
                fi
            else
                log_warn "ECS service not found for: $SERVICE"
            fi
        else
            log_info "To restart all ECS services:"
            for ecs_service in "${ecs_services[@]}"; do
                log_info "  aws ecs update-service --cluster $cluster_name --service $ecs_service --force-new-deployment"
            done
        fi
    fi
    
    # Lambda Functions
    local lambda_functions=($(aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `justenoughforagame`)].FunctionName' --output text 2>/dev/null || true))
    
    if [[ ${#lambda_functions[@]} -gt 0 ]]; then
        log_info "Found Lambda functions: ${lambda_functions[*]}"
        log_info "Lambda functions restart automatically on code updates"
        log_info "To update Lambda function code, use AWS Console or CLI deployment"
    fi
    
    log_info ""
    log_info "📋 Manual steps for AWS restart:"
    log_info "1. ECS Services: Use force new deployment"
    log_info "2. Lambda Functions: Deploy new code versions"
    log_info "3. DynamoDB: No restart needed (managed service)"
    log_info "4. ElastiCache: Restart through AWS Console if needed"
}

# Validate prerequisites
validate_prerequisites() {
    case $PLATFORM in
        docker)
            if ! command -v docker >/dev/null 2>&1; then
                log_error "Docker not found"
                exit 1
            fi
            if ! command -v docker-compose >/dev/null 2>&1; then
                log_error "Docker Compose not found"
                exit 1
            fi
            ;;
        k8s)
            if ! command -v kubectl >/dev/null 2>&1; then
                log_error "kubectl not found"
                exit 1
            fi
            ;;
        aws)
            if ! command -v aws >/dev/null 2>&1; then
                log_error "AWS CLI not found"
                exit 1
            fi
            ;;
        *)
            log_error "Unsupported platform: $PLATFORM"
            exit 1
            ;;
    esac
}

# Main execution
main() {
    validate_prerequisites
    
    case $PLATFORM in
        docker)
            restart_docker_services
            ;;
        k8s)
            restart_k8s_services
            ;;
        aws)
            restart_aws_services
            ;;
        *)
            log_error "Unsupported platform: $PLATFORM"
            exit 1
            ;;
    esac
    
    log_info "🎉 Restart completed successfully!"
    log_info ""
    log_info "📊 To check status: ./status.sh"
    log_info "📝 To view logs: ./logs.sh"
}

# Handle Ctrl+C
trap 'log_info "Restart interrupted..."; exit 0' INT

# Execute main function
main
