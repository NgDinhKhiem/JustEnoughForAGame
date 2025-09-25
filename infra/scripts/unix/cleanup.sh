#!/bin/bash

# JustEnoughForAGame Infrastructure Cleanup Script
# Comprehensive cleanup of Docker, Kubernetes, and AWS resources

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
    echo "Cleanup JustEnoughForAGame infrastructure resources"
    echo ""
    echo "OPTIONS:"
    echo "  -p, --platform      Platform to cleanup (docker|k8s|aws|all) [default: docker]"
    echo "  -t, --type         Cleanup type (containers|volumes|networks|images|all) [default: containers]"
    echo "  -f, --force        Force cleanup without confirmation [default: false]"
    echo "  -d, --dry-run      Show what would be cleaned without doing it [default: false]"
    echo "  --deep             Perform deep cleanup (unused resources) [default: false]"
    echo "  --logs             Clean up log files [default: false]"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                                   # Clean Docker containers"
    echo "  $0 -t all -f                       # Force clean all Docker resources"
    echo "  $0 -p k8s --dry-run                # Dry run Kubernetes cleanup"
    echo "  $0 -p all --deep --logs            # Deep cleanup with logs for all platforms"
    echo ""
}

# Default values
PLATFORM="docker"
CLEANUP_TYPE="containers"
FORCE=false
DRY_RUN=false
DEEP_CLEANUP=false
CLEAN_LOGS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform|-p)
            PLATFORM="$2"
            shift 2
            ;;
        --type|-t)
            CLEANUP_TYPE="$2"
            shift 2
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --dry-run|-d)
            DRY_RUN=true
            shift
            ;;
        --deep)
            DEEP_CLEANUP=true
            shift
            ;;
        --logs)
            CLEAN_LOGS=true
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

log_info "🧹 JustEnoughForAGame Infrastructure Cleanup"
log_info "Platform: $PLATFORM"
log_info "Type: $CLEANUP_TYPE"
log_info "Dry Run: $DRY_RUN"

# Function to execute or show command
execute_or_show() {
    local description="$1"
    local command="$2"
    
    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY RUN] $description: $command"
    else
        log_info "$description..."
        eval "$command"
    fi
}

# Function to confirm action
confirm_action() {
    local message="$1"
    
    if [[ $FORCE == false ]]; then
        read -p "$message (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled"
            return 1
        fi
    fi
    return 0
}

# Docker cleanup functions
cleanup_docker_containers() {
    local compose_dir="$PROJECT_ROOT/docker-compose"
    cd "$compose_dir" 2>/dev/null || {
        log_warn "Docker compose directory not found"
        return
    }
    
    log_info "🐳 Cleaning up Docker containers..."
    
    # Stop and remove containers
    if confirm_action "🛑 Stop and remove all containers?"; then
        execute_or_show "Stopping containers" "docker-compose down"
        
        # Remove any remaining project containers
        local project_name=$(basename "$compose_dir")
        execute_or_show "Removing project containers" "docker ps -a --filter label=com.docker.compose.project=$project_name -q | xargs -r docker rm -f"
    fi
}

cleanup_docker_volumes() {
    log_info "💾 Cleaning up Docker volumes..."
    
    local compose_dir="$PROJECT_ROOT/docker-compose"
    cd "$compose_dir" 2>/dev/null || {
        log_warn "Docker compose directory not found"
        return
    }
    
    if confirm_action "🗑️  Remove all project volumes (ALL DATA WILL BE LOST)?"; then
        execute_or_show "Removing compose volumes" "docker-compose down -v"
        
        if [[ $DEEP_CLEANUP == true ]]; then
            execute_or_show "Removing unused volumes" "docker volume prune -f"
        fi
    fi
}

cleanup_docker_networks() {
    log_info "🌐 Cleaning up Docker networks..."
    
    local compose_dir="$PROJECT_ROOT/docker-compose"
    local project_name=$(basename "$compose_dir" 2>/dev/null || echo "justenoughforagame")
    
    if confirm_action "🔌 Remove project networks?"; then
        execute_or_show "Removing project networks" "docker network ls --filter name=${project_name} -q | xargs -r docker network rm"
        
        if [[ $DEEP_CLEANUP == true ]]; then
            execute_or_show "Removing unused networks" "docker network prune -f"
        fi
    fi
}

cleanup_docker_images() {
    log_info "📦 Cleaning up Docker images..."
    
    if confirm_action "🖼️  Remove project images?"; then
        execute_or_show "Removing project images" "docker images --filter reference='*justenoughforagame*' -q | xargs -r docker rmi -f"
        execute_or_show "Removing project images" "docker images --filter reference='*tictactoe*' -q | xargs -r docker rmi -f"
        
        if [[ $DEEP_CLEANUP == true ]]; then
            execute_or_show "Removing dangling images" "docker image prune -f"
            if confirm_action "Remove ALL unused images?"; then
                execute_or_show "Removing all unused images" "docker image prune -a -f"
            fi
        fi
    fi
}

cleanup_docker_all() {
    cleanup_docker_containers
    cleanup_docker_volumes
    cleanup_docker_networks
    cleanup_docker_images
    
    if [[ $DEEP_CLEANUP == true ]]; then
        if confirm_action "🧹 Perform Docker system prune?"; then
            execute_or_show "Docker system prune" "docker system prune -a --volumes -f"
        fi
    fi
}

# Kubernetes cleanup functions
cleanup_k8s_resources() {
    log_info "☸️  Cleaning up Kubernetes resources..."
    
    local k8s_dir="$PROJECT_ROOT/deployment/kubernetes"
    
    if [[ ! -d "$k8s_dir" ]]; then
        log_warn "Kubernetes deployment directory not found"
        return
    fi
    
    if confirm_action "🗑️  Delete all Kubernetes resources in game-namespace?"; then
        execute_or_show "Deleting Kubernetes resources" "kubectl delete -f $k8s_dir/ --ignore-not-found=true"
        execute_or_show "Deleting namespace" "kubectl delete namespace game-namespace --ignore-not-found=true"
    fi
    
    if [[ $DEEP_CLEANUP == true ]]; then
        if confirm_action "Clean up unused Kubernetes resources?"; then
            execute_or_show "Removing unused ConfigMaps" "kubectl delete configmap --field-selector metadata.name!=kube-* -A --ignore-not-found=true"
            execute_or_show "Removing unused Secrets" "kubectl delete secret --field-selector type!=kubernetes.io/service-account-token -A --ignore-not-found=true"
        fi
    fi
}

# AWS cleanup functions
cleanup_aws_resources() {
    log_info "☁️  AWS resource cleanup guidance..."
    
    log_warn "⚠️  AWS resources require careful manual cleanup to avoid charges"
    
    local stack_name="justenoughforagame-prod-infrastructure"
    
    if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null; then
        if confirm_action "🗑️  Delete CloudFormation stack '$stack_name'?"; then
            execute_or_show "Deleting CloudFormation stack" "aws cloudformation delete-stack --stack-name $stack_name"
            
            if [[ $DRY_RUN == false ]]; then
                log_info "⏳ Stack deletion initiated. Monitor progress in AWS Console"
                log_info "This may take several minutes..."
            fi
        fi
    else
        log_info "AWS CLI not configured. Manual cleanup required:"
        log_info "1. Go to AWS CloudFormation Console"
        log_info "2. Delete stack: $stack_name"
        log_info "3. Verify all resources are deleted"
    fi
    
    # List other resources to check manually
    log_info "📋 Additional resources to check manually:"
    log_info "   • ECS Tasks and Services"
    log_info "   • Lambda Functions"
    log_info "   • DynamoDB Tables"
    log_info "   • ElastiCache Clusters"
    log_info "   • ECS Container Images in ECR"
    log_info "   • CloudWatch Log Groups"
    log_info "   • IAM Roles and Policies"
    log_info "   • VPC and related networking resources"
}

# Log cleanup function
cleanup_logs() {
    if [[ $CLEAN_LOGS == false ]]; then
        return
    fi
    
    log_info "📝 Cleaning up log files..."
    
    local log_dirs=(
        "$PROJECT_ROOT/logs"
        "$HOME/.justenoughforagame/logs"
        "/tmp/justenoughforagame-logs"
    )
    
    for log_dir in "${log_dirs[@]}"; do
        if [[ -d "$log_dir" ]]; then
            if confirm_action "Delete logs in $log_dir?"; then
                execute_or_show "Cleaning $log_dir" "rm -rf $log_dir/*"
            fi
        fi
    done
    
    # Clean Docker logs if Docker cleanup is enabled
    if [[ $PLATFORM == "docker" || $PLATFORM == "all" ]]; then
        if confirm_action "Truncate Docker container logs?"; then
            execute_or_show "Truncating Docker logs" "docker system events --since '1s' --until '1s' 2>/dev/null || true"
            
            # Clean up large log files
            local containers=$(docker ps -aq 2>/dev/null || true)
            if [[ -n "$containers" ]]; then
                for container in $containers; do
                    local log_file=$(docker inspect --format='{{.LogPath}}' "$container" 2>/dev/null || true)
                    if [[ -n "$log_file" && -f "$log_file" ]]; then
                        execute_or_show "Truncating container $container logs" "truncate -s 0 $log_file"
                    fi
                done
            fi
        fi
    fi
}

# Main cleanup function
run_cleanup() {
    case $PLATFORM in
        docker)
            case $CLEANUP_TYPE in
                containers) cleanup_docker_containers ;;
                volumes) cleanup_docker_volumes ;;
                networks) cleanup_docker_networks ;;
                images) cleanup_docker_images ;;
                all) cleanup_docker_all ;;
                *) log_error "Invalid cleanup type: $CLEANUP_TYPE" ;;
            esac
            ;;
        k8s)
            cleanup_k8s_resources
            ;;
        aws)
            cleanup_aws_resources
            ;;
        all)
            cleanup_docker_all
            cleanup_k8s_resources
            cleanup_aws_resources
            ;;
        *)
            log_error "Unsupported platform: $PLATFORM"
            exit 1
            ;;
    esac
    
    cleanup_logs
}

# Main execution
main() {
    if [[ $DRY_RUN == true ]]; then
        log_warn "🔍 DRY RUN MODE - No actual changes will be made"
        echo ""
    fi
    
    run_cleanup
    
    echo ""
    if [[ $DRY_RUN == true ]]; then
        log_info "🔍 Dry run completed. Run without --dry-run to execute cleanup"
    else
        log_info "✅ Cleanup completed successfully!"
    fi
    
    log_info ""
    log_info "🚀 To start services again: ./start.sh"
}

# Execute main function
main
