#!/bin/bash

# JustEnoughForAGame Infrastructure Health Check Script
# Performs comprehensive health checks across all platforms

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

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Perform health checks on JustEnoughForAGame infrastructure"
    echo ""
    echo "OPTIONS:"
    echo "  -p, --platform      Platform to check (docker|k8s|aws|all) [default: docker]"
    echo "  -s, --services      Specific services to check (comma-separated)"
    echo "  -d, --detailed      Show detailed output [default: false]"
    echo "  -w, --watch         Continuous monitoring mode [default: false]"
    echo "  -i, --interval      Watch interval in seconds [default: 5]"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                                   # Check Docker services"
    echo "  $0 -p all -d                       # Detailed check of all platforms"
    echo "  $0 -s redis,postgres               # Check specific services"
    echo "  $0 -w -i 10                        # Watch mode with 10s interval"
    echo ""
}

# Default values
PLATFORM="docker"
SERVICES=""
DETAILED=false
WATCH=false
INTERVAL=5

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform|-p)
            PLATFORM="$2"
            shift 2
            ;;
        --services|-s)
            SERVICES="$2"
            shift 2
            ;;
        --detailed|-d)
            DETAILED=true
            shift
            ;;
        --watch|-w)
            WATCH=true
            shift
            ;;
        --interval|-i)
            INTERVAL="$2"
            shift 2
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

# Health check results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to perform a health check
perform_check() {
    local check_name="$1"
    local check_command="$2"
    local expected_output="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ $DETAILED == true ]]; then
        echo -n "🔍 Checking $check_name... "
    fi
    
    if eval "$check_command" > /dev/null 2>&1; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        if [[ $DETAILED == true ]]; then
            log_success "✅ PASS"
        fi
        return 0
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        if [[ $DETAILED == true ]]; then
            log_error "❌ FAIL"
        fi
        return 1
    fi
}

# Docker health checks
check_docker_services() {
    local compose_dir="$PROJECT_ROOT/docker-compose"
    cd "$compose_dir"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found in $compose_dir"
        return 1
    fi
    
    log_info "🐳 Checking Docker services..."
    
    # Check Docker daemon
    perform_check "Docker daemon" "docker info"
    
    # Get list of services to check
    local services_to_check
    if [[ -n "$SERVICES" ]]; then
        IFS=',' read -ra services_to_check <<< "$SERVICES"
    else
        services_to_check=($(docker-compose config --services 2>/dev/null))
    fi
    
    # Check each service
    for service in "${services_to_check[@]}"; do
        perform_check "$service container" "docker-compose ps $service | grep -q 'Up'"
        
        # Additional service-specific checks
        case $service in
            redis)
                perform_check "$service connectivity" "docker-compose exec -T $service redis-cli ping | grep -q PONG"
                ;;
            postgres)
                perform_check "$service connectivity" "docker-compose exec -T $service pg_isready -U postgres"
                ;;
            kafka)
                perform_check "$service connectivity" "docker-compose exec -T $service kafka-broker-api-versions --bootstrap-server localhost:9092"
                ;;
        esac
    done
    
    # Check network connectivity
    perform_check "Docker network" "docker network ls | grep -q $(basename $compose_dir)"
    
    # Check volumes
    perform_check "Docker volumes" "docker volume ls | grep -q $(basename $compose_dir)"
}

# Kubernetes health checks
check_k8s_services() {
    log_info "☸️  Checking Kubernetes services..."
    
    # Check cluster connectivity
    perform_check "Kubernetes cluster" "kubectl cluster-info"
    
    # Check namespace
    perform_check "Game namespace" "kubectl get namespace game-namespace"
    
    # Get list of services to check
    local services_to_check
    if [[ -n "$SERVICES" ]]; then
        IFS=',' read -ra services_to_check <<< "$SERVICES"
    else
        services_to_check=($(kubectl get deployments -n game-namespace -o name 2>/dev/null | sed 's/deployment.apps\///'))
    fi
    
    # Check deployments
    for service in "${services_to_check[@]}"; do
        perform_check "$service deployment" "kubectl get deployment $service -n game-namespace"
        perform_check "$service pods" "kubectl get pods -l app=$service -n game-namespace | grep -q Running"
    done
    
    # Check services
    perform_check "Kubernetes services" "kubectl get services -n game-namespace"
    
    # Check ingress
    perform_check "Ingress controller" "kubectl get ingress -n game-namespace"
}

# AWS health checks
check_aws_services() {
    log_info "☁️  Checking AWS services..."
    
    # Check AWS CLI and credentials
    perform_check "AWS CLI" "aws --version"
    perform_check "AWS credentials" "aws sts get-caller-identity"
    
    # Check CloudFormation stack
    local stack_name="justenoughforagame-prod-infrastructure"
    perform_check "CloudFormation stack" "aws cloudformation describe-stacks --stack-name $stack_name"
    
    # Check ECS services if they exist
    local cluster_name="justenoughforagame-cluster"
    perform_check "ECS cluster" "aws ecs describe-clusters --clusters $cluster_name"
    
    # Check Lambda functions
    perform_check "Lambda functions" "aws lambda list-functions --query 'Functions[?starts_with(FunctionName, \`justenoughforagame\`)]'"
    
    # Check DynamoDB tables
    perform_check "DynamoDB tables" "aws dynamodb list-tables --query 'TableNames[?starts_with(@, \`justenoughforagame\`)]'"
    
    # Check ElastiCache
    perform_check "ElastiCache clusters" "aws elasticache describe-cache-clusters --query 'CacheClusters[?starts_with(CacheClusterId, \`justenoughforagame\`)]'"
}

# System prerequisites checks
check_prerequisites() {
    log_info "🔧 Checking system prerequisites..."
    
    # Check common tools
    perform_check "curl" "curl --version"
    perform_check "jq" "jq --version"
    perform_check "git" "git --version"
    
    # Platform-specific checks
    case $PLATFORM in
        docker|all)
            perform_check "Docker" "docker --version"
            perform_check "Docker Compose" "docker-compose --version"
            ;;
    esac
    
    case $PLATFORM in
        k8s|all)
            perform_check "kubectl" "kubectl version --client"
            ;;
    esac
    
    case $PLATFORM in
        aws|all)
            perform_check "AWS CLI" "aws --version"
            ;;
    esac
}

# Main health check function
run_health_checks() {
    log_info "🏥 Starting health checks for platform: $PLATFORM"
    echo ""
    
    # Reset counters
    TOTAL_CHECKS=0
    PASSED_CHECKS=0
    FAILED_CHECKS=0
    
    # Check prerequisites
    check_prerequisites
    
    # Platform-specific checks
    case $PLATFORM in
        docker)
            check_docker_services
            ;;
        k8s)
            check_k8s_services
            ;;
        aws)
            check_aws_services
            ;;
        all)
            check_docker_services
            check_k8s_services
            check_aws_services
            ;;
        *)
            log_error "Unsupported platform: $PLATFORM"
            exit 1
            ;;
    esac
    
    # Print summary
    echo ""
    log_info "📊 Health Check Summary:"
    log_info "   Total Checks: $TOTAL_CHECKS"
    log_success "   Passed: $PASSED_CHECKS"
    
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        log_error "   Failed: $FAILED_CHECKS"
        echo ""
        log_warn "⚠️  Some health checks failed. See details above."
        return 1
    else
        log_success "   Failed: $FAILED_CHECKS"
        echo ""
        log_success "🎉 All health checks passed!"
        return 0
    fi
}

# Watch mode function
watch_health_checks() {
    log_info "👀 Starting continuous monitoring (Ctrl+C to stop)..."
    log_info "Refresh interval: ${INTERVAL}s"
    echo ""
    
    while true; do
        clear
        echo "=== JustEnoughForAGame Health Check - $(date) ==="
        echo ""
        
        if run_health_checks; then
            echo ""
            log_success "System is healthy ✅"
        else
            echo ""
            log_error "System has issues ❌"
        fi
        
        echo ""
        echo "Next check in ${INTERVAL}s... (Ctrl+C to stop)"
        sleep $INTERVAL
    done
}

# Main execution
main() {
    if [[ $WATCH == true ]]; then
        watch_health_checks
    else
        run_health_checks
    fi
}

# Handle Ctrl+C in watch mode
trap 'log_info "Stopping health checks..."; exit 0' INT

# Execute main function
main
