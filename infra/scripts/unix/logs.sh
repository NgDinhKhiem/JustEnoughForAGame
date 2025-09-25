#!/bin/bash

# JustEnoughForAGame Infrastructure Logs Script
# Comprehensive log viewing and management for all platforms

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
    echo "View logs from JustEnoughForAGame infrastructure services"
    echo ""
    echo "ARGUMENTS:"
    echo "  SERVICE             Specific service to view logs for"
    echo ""
    echo "OPTIONS:"
    echo "  -p, --platform      Platform (docker|k8s|aws) [default: docker]"
    echo "  -f, --follow        Follow log output [default: false]"
    echo "  -t, --tail          Number of lines to show [default: 100]"
    echo "  -s, --since         Show logs since timestamp (e.g., '2h', '30m', '2023-01-01')"
    echo "  -l, --level         Log level filter (error|warn|info|debug)"
    echo "  --grep              Filter logs with grep pattern"
    echo "  --export            Export logs to file"
    echo "  --format            Log format (raw|json|pretty) [default: pretty]"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                                   # Show all Docker service logs"
    echo "  $0 redis                            # Show Redis logs"
    echo "  $0 -f -t 50 postgres               # Follow PostgreSQL logs (50 lines)"
    echo "  $0 -p k8s --grep 'ERROR'           # K8s logs with ERROR pattern"
    echo "  $0 --since '1h' --level error      # Error logs from last hour"
    echo "  $0 --export /tmp/logs.txt          # Export logs to file"
    echo ""
}

# Default values
PLATFORM="docker"
SERVICE=""
FOLLOW=false
TAIL_LINES=100
SINCE=""
LOG_LEVEL=""
GREP_PATTERN=""
EXPORT_FILE=""
LOG_FORMAT="pretty"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform|-p)
            PLATFORM="$2"
            shift 2
            ;;
        --follow|-f)
            FOLLOW=true
            shift
            ;;
        --tail|-t)
            TAIL_LINES="$2"
            shift 2
            ;;
        --since|-s)
            SINCE="$2"
            shift 2
            ;;
        --level|-l)
            LOG_LEVEL="$2"
            shift 2
            ;;
        --grep)
            GREP_PATTERN="$2"
            shift 2
            ;;
        --export)
            EXPORT_FILE="$2"
            shift 2
            ;;
        --format)
            LOG_FORMAT="$2"
            shift 2
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

log_info "📝 JustEnoughForAGame Log Viewer"
log_info "Platform: $PLATFORM"
if [[ -n "$SERVICE" ]]; then
    log_info "Service: $SERVICE"
fi

# Function to build log filter command
build_log_filter() {
    local filter_cmd=""
    
    # Add grep filter if specified
    if [[ -n "$GREP_PATTERN" ]]; then
        filter_cmd="grep -E '$GREP_PATTERN'"
    fi
    
    # Add log level filter
    if [[ -n "$LOG_LEVEL" ]]; then
        local level_pattern
        case $LOG_LEVEL in
            error) level_pattern="ERROR|FATAL|error|fatal" ;;
            warn) level_pattern="WARN|WARNING|warn|warning" ;;
            info) level_pattern="INFO|info" ;;
            debug) level_pattern="DEBUG|debug" ;;
            *) level_pattern="$LOG_LEVEL" ;;
        esac
        
        if [[ -n "$filter_cmd" ]]; then
            filter_cmd="$filter_cmd | grep -E '$level_pattern'"
        else
            filter_cmd="grep -E '$level_pattern'"
        fi
    fi
    
    # Add colorization for pretty format
    if [[ "$LOG_FORMAT" == "pretty" ]]; then
        local color_cmd="sed -E 's/(ERROR|FATAL|error|fatal)/$(echo -e "${RED}")\1$(echo -e "${NC}")/g; s/(WARN|WARNING|warn|warning)/$(echo -e "${YELLOW}")\1$(echo -e "${NC}")/g; s/(INFO|info)/$(echo -e "${GREEN}")\1$(echo -e "${NC}")/g; s/(DEBUG|debug)/$(echo -e "${BLUE}")\1$(echo -e "${NC}")/g'"
        
        if [[ -n "$filter_cmd" ]]; then
            filter_cmd="$filter_cmd | $color_cmd"
        else
            filter_cmd="$color_cmd"
        fi
    fi
    
    echo "$filter_cmd"
}

# Function to view Docker logs
view_docker_logs() {
    local compose_dir="$PROJECT_ROOT/docker-compose"
    cd "$compose_dir" || {
        log_error "Docker compose directory not found: $compose_dir"
        exit 1
    }
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found"
        exit 1
    fi
    
    local docker_cmd="docker-compose logs"
    
    # Add tail option
    if [[ $TAIL_LINES -gt 0 ]]; then
        docker_cmd="$docker_cmd --tail=$TAIL_LINES"
    fi
    
    # Add since option
    if [[ -n "$SINCE" ]]; then
        docker_cmd="$docker_cmd --since=$SINCE"
    fi
    
    # Add follow option
    if [[ $FOLLOW == true ]]; then
        docker_cmd="$docker_cmd -f"
    fi
    
    # Add service if specified
    if [[ -n "$SERVICE" ]]; then
        docker_cmd="$docker_cmd $SERVICE"
    fi
    
    # Add timestamps
    docker_cmd="$docker_cmd -t"
    
    log_info "🐳 Viewing Docker logs..."
    if [[ $FOLLOW == true ]]; then
        log_info "Following logs (Ctrl+C to stop)..."
    fi
    
    # Build filter command
    local filter_cmd=$(build_log_filter)
    
    # Execute command with or without filters
    if [[ -n "$filter_cmd" ]]; then
        if [[ -n "$EXPORT_FILE" ]]; then
            eval "$docker_cmd | $filter_cmd | tee $EXPORT_FILE"
        else
            eval "$docker_cmd | $filter_cmd"
        fi
    else
        if [[ -n "$EXPORT_FILE" ]]; then
            eval "$docker_cmd | tee $EXPORT_FILE"
        else
            eval "$docker_cmd"
        fi
    fi
}

# Function to view Kubernetes logs
view_k8s_logs() {
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl not found"
        exit 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    local kubectl_cmd="kubectl logs"
    local namespace="game-namespace"
    
    # Add tail option
    if [[ $TAIL_LINES -gt 0 ]]; then
        kubectl_cmd="$kubectl_cmd --tail=$TAIL_LINES"
    fi
    
    # Add since option
    if [[ -n "$SINCE" ]]; then
        kubectl_cmd="$kubectl_cmd --since=$SINCE"
    fi
    
    # Add follow option
    if [[ $FOLLOW == true ]]; then
        kubectl_cmd="$kubectl_cmd -f"
    fi
    
    # Add timestamps
    kubectl_cmd="$kubectl_cmd --timestamps=true"
    
    # Add namespace
    kubectl_cmd="$kubectl_cmd -n $namespace"
    
    log_info "☸️  Viewing Kubernetes logs..."
    
    if [[ -n "$SERVICE" ]]; then
        # Get specific service logs
        kubectl_cmd="$kubectl_cmd deployment/$SERVICE"
        
        log_info "Service: $SERVICE"
        if [[ $FOLLOW == true ]]; then
            log_info "Following logs (Ctrl+C to stop)..."
        fi
        
        # Build filter command
        local filter_cmd=$(build_log_filter)
        
        # Execute command with or without filters
        if [[ -n "$filter_cmd" ]]; then
            if [[ -n "$EXPORT_FILE" ]]; then
                eval "$kubectl_cmd | $filter_cmd | tee $EXPORT_FILE"
            else
                eval "$kubectl_cmd | $filter_cmd"
            fi
        else
            if [[ -n "$EXPORT_FILE" ]]; then
                eval "$kubectl_cmd | tee $EXPORT_FILE"
            else
                eval "$kubectl_cmd"
            fi
        fi
    else
        # Get all pods in namespace
        local pods=($(kubectl get pods -n $namespace -o name 2>/dev/null | head -10))
        
        if [[ ${#pods[@]} -eq 0 ]]; then
            log_warn "No pods found in namespace $namespace"
            return
        fi
        
        log_info "Found ${#pods[@]} pods, showing logs..."
        
        for pod in "${pods[@]}"; do
            echo ""
            log_info "=== Logs for $pod ==="
            
            local pod_cmd="$kubectl_cmd $pod"
            local filter_cmd=$(build_log_filter)
            
            if [[ -n "$filter_cmd" ]]; then
                eval "$pod_cmd | $filter_cmd" 2>/dev/null || log_warn "Could not get logs for $pod"
            else
                eval "$pod_cmd" 2>/dev/null || log_warn "Could not get logs for $pod"
            fi
        done
    fi
}

# Function to view AWS logs
view_aws_logs() {
    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI not found"
        exit 1
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    log_info "☁️  Viewing AWS CloudWatch logs..."
    
    # List available log groups
    local log_groups=($(aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/justenoughforagame" --query 'logGroups[*].logGroupName' --output text 2>/dev/null))
    
    if [[ ${#log_groups[@]} -eq 0 ]]; then
        log_warn "No CloudWatch log groups found for JustEnoughForAGame"
        return
    fi
    
    if [[ -n "$SERVICE" ]]; then
        # Look for specific service log group
        local log_group=""
        for group in "${log_groups[@]}"; do
            if [[ $group == *"$SERVICE"* ]]; then
                log_group="$group"
                break
            fi
        done
        
        if [[ -z "$log_group" ]]; then
            log_error "No log group found for service: $SERVICE"
            log_info "Available log groups:"
            for group in "${log_groups[@]}"; do
                log_info "  - $group"
            done
            exit 1
        fi
        
        log_info "Viewing logs for: $log_group"
        
        # Build AWS logs command
        local aws_cmd="aws logs tail $log_group"
        
        if [[ $FOLLOW == true ]]; then
            aws_cmd="$aws_cmd --follow"
        fi
        
        if [[ -n "$SINCE" ]]; then
            aws_cmd="$aws_cmd --since $SINCE"
        fi
        
        # Execute command
        local filter_cmd=$(build_log_filter)
        
        if [[ -n "$filter_cmd" ]]; then
            if [[ -n "$EXPORT_FILE" ]]; then
                eval "$aws_cmd | $filter_cmd | tee $EXPORT_FILE"
            else
                eval "$aws_cmd | $filter_cmd"
            fi
        else
            if [[ -n "$EXPORT_FILE" ]]; then
                eval "$aws_cmd | tee $EXPORT_FILE"
            else
                eval "$aws_cmd"
            fi
        fi
    else
        log_info "Available log groups:"
        for group in "${log_groups[@]}"; do
            log_info "  - $group"
        done
        echo ""
        log_info "Use -s <service-name> to view specific service logs"
    fi
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
            view_docker_logs
            ;;
        k8s)
            view_k8s_logs
            ;;
        aws)
            view_aws_logs
            ;;
        *)
            log_error "Unsupported platform: $PLATFORM"
            exit 1
            ;;
    esac
    
    if [[ -n "$EXPORT_FILE" && $FOLLOW == false ]]; then
        log_info "Logs exported to: $EXPORT_FILE"
    fi
}

# Handle Ctrl+C in follow mode
trap 'log_info "Stopping log viewer..."; exit 0' INT

# Execute main function
main
