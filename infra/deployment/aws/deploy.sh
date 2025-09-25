#!/bin/bash

# TicTacToe AWS Deployment Script

set -e

# Configuration
PROJECT_NAME="tictactoe"
REGION="us-east-1"
ENVIRONMENT="prod"
STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-infrastructure"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials are not configured. Please run 'aws configure' first."
    exit 1
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment|-e)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --region|-r)
            REGION="$2"
            shift 2
            ;;
        --project-name|-p)
            PROJECT_NAME="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -e, --environment    Environment name (default: prod)"
            echo "  -r, --region         AWS region (default: us-east-1)"
            echo "  -p, --project-name   Project name (default: tictactoe)"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Update stack name with new environment
STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-infrastructure"

log_info "Starting deployment of TicTacToe infrastructure..."
log_info "Project: $PROJECT_NAME"
log_info "Environment: $ENVIRONMENT"
log_info "Region: $REGION"
log_info "Stack: $STACK_NAME"

# Validate CloudFormation template
log_info "Validating CloudFormation template..."
if aws cloudformation validate-template \
    --template-body file://cloudformation/infrastructure.yml \
    --region $REGION > /dev/null; then
    log_info "Template validation successful"
else
    log_error "Template validation failed"
    exit 1
fi

# Check if stack exists
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    log_info "Stack exists. Updating..."
    OPERATION="update-stack"
    WAIT_CONDITION="stack-update-complete"
else
    log_info "Stack does not exist. Creating..."
    OPERATION="create-stack"
    WAIT_CONDITION="stack-create-complete"
fi

# Deploy/Update stack
log_info "Deploying CloudFormation stack..."
aws cloudformation $OPERATION \
    --stack-name $STACK_NAME \
    --template-body file://cloudformation/infrastructure.yml \
    --parameters \
        ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
        ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME \
    --capabilities CAPABILITY_IAM \
    --region $REGION \
    --tags \
        Key=Project,Value=$PROJECT_NAME \
        Key=Environment,Value=$ENVIRONMENT \
        Key=ManagedBy,Value=CloudFormation

if [ $? -eq 0 ]; then
    log_info "Stack deployment initiated successfully"
else
    log_error "Stack deployment failed"
    exit 1
fi

# Wait for stack operation to complete
log_info "Waiting for stack operation to complete..."
aws cloudformation wait $WAIT_CONDITION \
    --stack-name $STACK_NAME \
    --region $REGION

if [ $? -eq 0 ]; then
    log_info "Stack operation completed successfully!"
else
    log_error "Stack operation failed or timed out"
    
    # Show stack events for debugging
    log_info "Recent stack events:"
    aws cloudformation describe-stack-events \
        --stack-name $STACK_NAME \
        --region $REGION \
        --max-items 10 \
        --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`].[Timestamp,LogicalResourceId,ResourceStatus,ResourceStatusReason]' \
        --output table
    
    exit 1
fi

# Display stack outputs
log_info "Stack outputs:"
aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue,Description]' \
    --output table

log_info "Infrastructure deployment completed successfully!"
log_info "Next steps:"
log_info "1. Build and push Docker images for ECS services"
log_info "2. Deploy Lambda functions for auth and user services"
log_info "3. Configure API Gateway endpoints"
log_info "4. Set up monitoring and logging"
