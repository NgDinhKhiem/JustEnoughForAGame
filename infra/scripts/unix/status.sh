#!/bin/bash

# JustEnoughForAGame Infrastructure Status Script
# Shows comprehensive status of all infrastructure components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_header() {
    echo -e "${CYAN}$1${NC}"
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Show status of JustEnoughForAGame infrastructure"
    echo ""
    echo "OPTIONS:"
    echo "  -p, --platform      Platform to check (docker|k8s|aws|all) [default: all]"
    echo "  -s, --services      Specific services to show (comma-separated)"
    echo "  -f, --format        Output format (table|json|yaml) [default: table]"
    echo "  -w, --watch         Continuous monitoring mode [default: false]"
    echo "  -i, --interval      Watch interval in seconds [default: 5]"
    echo "  --no-color          Disable colored output"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                                   # Show status of all platforms"
    echo "  $0 -p docker -f json               # Docker status in JSON format"
    echo "  $0 -s redis,postgres               # Status of specific services"
    echo "  $0 -w -i 10                        # Watch mode with 10s interval"
    echo ""
}

# Default values
PLATFORM="all"
SERVICES=""
FORMAT="table"
WATCH=false
INTERVAL=5
USE_COLOR=true

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
        --format|-f)
            FORMAT="$2"
            shift 2
            ;;
        --watch|-w)
            WATCH=true
            shift
            ;;
        --interval|-i)
            INTERVAL="$2"
            shift 2
            ;;
        --no-color)
            USE_COLOR=false
            # Disable colors
            RED=''
            GREEN=''
            YELLOW=''
            BLUE=''
            CYAN=''
            NC=''
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

# Status tracking (compatible with older bash versions)
STATUS_FILE="/tmp/justenoughforagame_status_$$"

# Function to set status
set_status() {
    echo "$1=$2" >> "$STATUS_FILE"
}

# Function to get status
get_status() {
    grep "^$1=" "$STATUS_FILE" 2>/dev/null | cut -d'=' -f2- | tail -1
}

# Function to clear status
clear_status() {
    rm -f "$STATUS_FILE"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get Docker service status
get_docker_status() {
    local compose_dir="$PROJECT_ROOT/docker-compose"
    
    if [[ ! -d "$compose_dir" ]]; then
        set_status "docker_available" "false"
        return
    fi
    
    cd "$compose_dir"
    set_status "docker_available" "true"
    
    # Check Docker daemon
    if docker info >/dev/null 2>&1; then
        set_status "docker_daemon" "running"
    else
        set_status "docker_daemon" "not_running"
        return
    fi
    
    # Get services to check
    local services_to_check
    if [[ -n "$SERVICES" ]]; then
        IFS=',' read -ra services_to_check <<< "$SERVICES"
    else
        if [[ -f "docker-compose.yml" ]]; then
            services_to_check=($(docker-compose config --services 2>/dev/null | head -10))
        else
            services_to_check=()
        fi
    fi
    
    # Check each service
    for service in "${services_to_check[@]}"; do
        local status_output=$(docker-compose ps "$service" 2>/dev/null | tail -n +2)
        
        if [[ -z "$status_output" ]]; then
            set_status "docker_${service}" "not_created"
        elif echo "$status_output" | grep -q "Up"; then
            if echo "$status_output" | grep -q "healthy"; then
                set_status "docker_${service}" "healthy"
            else
                set_status "docker_${service}" "running"
            fi
        elif echo "$status_output" | grep -q "Exit"; then
            set_status "docker_${service}" "exited"
        else
            set_status "docker_${service}" "unknown"
        fi
    done
}

# Function to get Kubernetes status
get_k8s_status() {
    if ! command_exists kubectl; then
        set_status "k8s_available" "false"
        return
    fi
    
    set_status "k8s_available" "true"
    
    # Check cluster connectivity
    if kubectl cluster-info >/dev/null 2>&1; then
        set_status "k8s_cluster" "connected"
    else
        set_status "k8s_cluster" "not_connected"
        return
    fi
    
    # Check namespace
    if kubectl get namespace game-namespace >/dev/null 2>&1; then
        set_status "k8s_namespace" "exists"
    else
        set_status "k8s_namespace" "not_found"
    fi
    
    # Get services to check
    local services_to_check
    if [[ -n "$SERVICES" ]]; then
        IFS=',' read -ra services_to_check <<< "$SERVICES"
    else
        services_to_check=($(kubectl get deployments -n game-namespace -o name 2>/dev/null | sed 's/deployment.apps\///' | head -10))
    fi
    
    # Check deployments and pods
    for service in "${services_to_check[@]}"; do
        local deployment_status=$(kubectl get deployment "$service" -n game-namespace -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "NotFound")
        local ready_replicas=$(kubectl get deployment "$service" -n game-namespace -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_replicas=$(kubectl get deployment "$service" -n game-namespace -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        if [[ "$deployment_status" == "True" && "$ready_replicas" == "$desired_replicas" ]]; then
            set_status "k8s_${service}" "ready"
        elif [[ "$deployment_status" == "True" ]]; then
            set_status "k8s_${service}" "partial"
        elif [[ "$deployment_status" == "False" ]]; then
            set_status "k8s_${service}" "not_ready"
        else
            set_status "k8s_${service}" "not_found"
        fi
    done
}

# Function to get AWS status
get_aws_status() {
    if ! command_exists aws; then
        set_status "aws_available" "false"
        return
    fi
    
    set_status "aws_available" "true"
    
    # Check AWS credentials
    if aws sts get-caller-identity >/dev/null 2>&1; then
        set_status "aws_credentials" "valid"
    else
        set_status "aws_credentials" "invalid"
        return
    fi
    
    # Check CloudFormation stack
    local stack_name="justenoughforagame-prod-infrastructure"
    local stack_status=$(aws cloudformation describe-stacks --stack-name "$stack_name" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND")
    set_status "aws_cloudformation" "$stack_status"
    
    # Check ECS cluster
    local cluster_name="justenoughforagame-cluster"
    local cluster_status=$(aws ecs describe-clusters --clusters "$cluster_name" --query 'clusters[0].status' --output text 2>/dev/null || echo "NOT_FOUND")
    set_status "aws_ecs_cluster" "$cluster_status"
    
    # Check ECS services
    if [[ "$cluster_status" == "ACTIVE" ]]; then
        local services=($(aws ecs list-services --cluster "$cluster_name" --query 'serviceArns[*]' --output text 2>/dev/null | sed 's/.*\///'))
        for service in "${services[@]}"; do
            local service_status=$(aws ecs describe-services --cluster "$cluster_name" --services "$service" --query 'services[0].status' --output text 2>/dev/null || echo "UNKNOWN")
            set_status "aws_ecs_${service}" "$service_status"
        done
    fi
}

# Function to display status in table format
display_table_format() {
    log_header "=================================================================================="
    log_header "                    JustEnoughForAGame Infrastructure Status"
    log_header "=================================================================================="
    echo ""
    
    # Docker status
    if [[ $PLATFORM == "docker" || $PLATFORM == "all" ]]; then
        log_header "🐳 DOCKER SERVICES"
        echo "────────────────────────────────────────────────────────────────────────────────"
        
        if [[ "$(get_status docker_available)" == "true" ]]; then
            printf "%-25s %s\n" "Docker Daemon:" "$(format_status $(get_status docker_daemon))"
            
            # Get all docker services from status file
            if [[ -f "$STATUS_FILE" ]]; then
                while IFS= read -r line; do
                    local key="${line%%=*}"
                    if [[ $key =~ ^docker_[^da].*$ ]]; then
                        local value="${line#*=}"
                        local service_name="${key#docker_}"
                        printf "%-25s %s\n" "$service_name:" "$(format_status $value)"
                    fi
                done < "$STATUS_FILE"
            fi
        else
            printf "%-25s %s\n" "Docker:" "$(format_status not_available)"
        fi
        echo ""
    fi
    
    # Kubernetes status
    if [[ $PLATFORM == "k8s" || $PLATFORM == "all" ]]; then
        log_header "☸️  KUBERNETES SERVICES"
        echo "────────────────────────────────────────────────────────────────────────────────"
        
        if [[ "$(get_status k8s_available)" == "true" ]]; then
            printf "%-25s %s\n" "Cluster:" "$(format_status $(get_status k8s_cluster))"
            printf "%-25s %s\n" "Namespace:" "$(format_status $(get_status k8s_namespace))"
            
            # Get all k8s services from status file
            if [[ -f "$STATUS_FILE" ]]; then
                while IFS= read -r line; do
                    local key="${line%%=*}"
                    if [[ $key =~ ^k8s_[^cna].*$ ]]; then
                        local value="${line#*=}"
                        local service_name="${key#k8s_}"
                        printf "%-25s %s\n" "$service_name:" "$(format_status $value)"
                    fi
                done < "$STATUS_FILE"
            fi
        else
            printf "%-25s %s\n" "Kubernetes:" "$(format_status not_available)"
        fi
        echo ""
    fi
    
    # AWS status
    if [[ $PLATFORM == "aws" || $PLATFORM == "all" ]]; then
        log_header "☁️  AWS SERVICES"
        echo "────────────────────────────────────────────────────────────────────────────────"
        
        if [[ "$(get_status aws_available)" == "true" ]]; then
            printf "%-25s %s\n" "AWS CLI:" "$(format_status valid)"
            printf "%-25s %s\n" "Credentials:" "$(format_status $(get_status aws_credentials))"
            printf "%-25s %s\n" "CloudFormation:" "$(format_status $(get_status aws_cloudformation))"
            printf "%-25s %s\n" "ECS Cluster:" "$(format_status $(get_status aws_ecs_cluster))"
            
            # Get all aws ecs services from status file
            if [[ -f "$STATUS_FILE" ]]; then
                while IFS= read -r line; do
                    local key="${line%%=*}"
                    if [[ $key =~ ^aws_ecs_[^ca].*$ ]]; then
                        local value="${line#*=}"
                        local service_name="${key#aws_ecs_}"
                        printf "%-25s %s\n" "$service_name:" "$(format_status $value)"
                    fi
                done < "$STATUS_FILE"
            fi
        else
            printf "%-25s %s\n" "AWS:" "$(format_status not_available)"
        fi
        echo ""
    fi
}

# Function to format status with colors and icons
format_status() {
    local status="$1"
    
    case $status in
        "running"|"healthy"|"ready"|"connected"|"valid"|"ACTIVE"|"CREATE_COMPLETE"|"UPDATE_COMPLETE")
            echo -e "${GREEN}✅ ${status}${NC}"
            ;;
        "partial"|"not_ready"|"UPDATE_IN_PROGRESS"|"CREATE_IN_PROGRESS")
            echo -e "${YELLOW}⏳ ${status}${NC}"
            ;;
        "not_running"|"exited"|"not_connected"|"invalid"|"not_found"|"NOT_FOUND"|"FAILED")
            echo -e "${RED}❌ ${status}${NC}"
            ;;
        "not_available"|"not_created")
            echo -e "${YELLOW}⚪ ${status}${NC}"
            ;;
        *)
            echo -e "${BLUE}ℹ️  ${status}${NC}"
            ;;
    esac
}

# Function to display status in JSON format
display_json_format() {
    echo "{"
    local first=true
    if [[ -f "$STATUS_FILE" ]]; then
        while IFS= read -r line; do
            local key="${line%%=*}"
            local value="${line#*=}"
            if [[ $first == true ]]; then
                first=false
            else
                echo ","
            fi
            echo -n "  \"$key\": \"$value\""
        done < "$STATUS_FILE"
    fi
    echo ""
    echo "}"
}

# Function to display status in YAML format
display_yaml_format() {
    echo "infrastructure_status:"
    if [[ -f "$STATUS_FILE" ]]; then
        while IFS= read -r line; do
            local key="${line%%=*}"
            local value="${line#*=}"
            echo "  $key: $value"
        done < "$STATUS_FILE"
    fi
}

# Function to collect all status data
collect_status() {
    # Clear previous data
    clear_status
    
    case $PLATFORM in
        docker)
            get_docker_status
            ;;
        k8s)
            get_k8s_status
            ;;
        aws)
            get_aws_status
            ;;
        all)
            get_docker_status
            get_k8s_status
            get_aws_status
            ;;
        *)
            log_error "Unsupported platform: $PLATFORM"
            exit 1
            ;;
    esac
}

# Function to display status based on format
display_status() {
    case $FORMAT in
        table)
            display_table_format
            ;;
        json)
            display_json_format
            ;;
        yaml)
            display_yaml_format
            ;;
        *)
            log_error "Unsupported format: $FORMAT"
            exit 1
            ;;
    esac
}

# Main status function
run_status_check() {
    collect_status
    display_status
}

# Watch mode function
watch_status() {
    log_info "👀 Starting continuous monitoring (Ctrl+C to stop)..."
    log_info "Refresh interval: ${INTERVAL}s"
    echo ""
    
    while true; do
        if [[ $FORMAT == "table" ]]; then
            clear
            echo "Last updated: $(date)"
            echo ""
        fi
        
        run_status_check
        
        if [[ $FORMAT == "table" ]]; then
            echo ""
            echo "Next update in ${INTERVAL}s... (Ctrl+C to stop)"
        fi
        
        sleep $INTERVAL
    done
}

# Main execution
main() {
    if [[ $WATCH == true ]]; then
        watch_status
    else
        run_status_check
    fi
    # Cleanup temporary status file
    clear_status
}

# Handle Ctrl+C in watch mode
trap 'log_info "Stopping status monitoring..."; clear_status; exit 0' INT

# Execute main function
main
