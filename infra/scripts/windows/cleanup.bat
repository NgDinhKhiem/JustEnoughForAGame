@echo off
setlocal enabledelayedexpansion

REM JustEnoughForAGame Infrastructure Cleanup Script for Windows
REM Comprehensive cleanup of Docker, Kubernetes, and AWS resources

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..\..

REM Default values
set PLATFORM=docker
set CLEANUP_TYPE=containers
set FORCE=false
set DRY_RUN=false
set DEEP_CLEANUP=false
set CLEAN_LOGS=false

REM Parse command line arguments
:parse_args
if "%~1"=="" goto :start_main
if "%~1"=="-p" (
    set PLATFORM=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="--platform" (
    set PLATFORM=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="-t" (
    set CLEANUP_TYPE=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="--type" (
    set CLEANUP_TYPE=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="-f" (
    set FORCE=true
    shift
    goto :parse_args
)
if "%~1"=="--force" (
    set FORCE=true
    shift
    goto :parse_args
)
if "%~1"=="-d" (
    set DRY_RUN=true
    shift
    goto :parse_args
)
if "%~1"=="--dry-run" (
    set DRY_RUN=true
    shift
    goto :parse_args
)
if "%~1"=="--deep" (
    set DEEP_CLEANUP=true
    shift
    goto :parse_args
)
if "%~1"=="--logs" (
    set CLEAN_LOGS=true
    shift
    goto :parse_args
)
if "%~1"=="-h" goto :show_help
if "%~1"=="--help" goto :show_help

echo [ERROR] Unknown option: %~1
goto :show_help

:show_help
echo Usage: %~n0 [OPTIONS]
echo.
echo Cleanup JustEnoughForAGame infrastructure resources
echo.
echo OPTIONS:
echo   -p, --platform      Platform to cleanup (docker^|k8s^|aws^|all) [default: docker]
echo   -t, --type         Cleanup type (containers^|volumes^|networks^|images^|all) [default: containers]
echo   -f, --force        Force cleanup without confirmation [default: false]
echo   -d, --dry-run      Show what would be cleaned without doing it [default: false]
echo   --deep             Perform deep cleanup (unused resources) [default: false]
echo   --logs             Clean up log files [default: false]
echo   -h, --help         Show this help message
echo.
echo EXAMPLES:
echo   %~n0                                   # Clean Docker containers
echo   %~n0 -t all -f                       # Force clean all Docker resources
echo   %~n0 -p k8s --dry-run                # Dry run Kubernetes cleanup
echo   %~n0 -p all --deep --logs            # Deep cleanup with logs for all platforms
echo.
exit /b 0

:start_main
echo [INFO] 🧹 JustEnoughForAGame Infrastructure Cleanup
echo [INFO] Platform: %PLATFORM%
echo [INFO] Type: %CLEANUP_TYPE%
echo [INFO] Dry Run: %DRY_RUN%

if "%DRY_RUN%"=="true" (
    echo [WARN] 🔍 DRY RUN MODE - No actual changes will be made
    echo.
)

if "%PLATFORM%"=="docker" call :cleanup_docker
if "%PLATFORM%"=="k8s" call :cleanup_k8s
if "%PLATFORM%"=="aws" call :cleanup_aws
if "%PLATFORM%"=="all" (
    call :cleanup_docker
    call :cleanup_k8s
    call :cleanup_aws
)

call :cleanup_logs

echo.
if "%DRY_RUN%"=="true" (
    echo [INFO] 🔍 Dry run completed. Run without --dry-run to execute cleanup
) else (
    echo [INFO] ✅ Cleanup completed successfully!
)

echo.
echo [INFO] 🚀 To start services again: start.bat
goto :eof

:cleanup_docker
if "%CLEANUP_TYPE%"=="containers" call :cleanup_docker_containers
if "%CLEANUP_TYPE%"=="volumes" call :cleanup_docker_volumes
if "%CLEANUP_TYPE%"=="networks" call :cleanup_docker_networks
if "%CLEANUP_TYPE%"=="images" call :cleanup_docker_images
if "%CLEANUP_TYPE%"=="all" (
    call :cleanup_docker_containers
    call :cleanup_docker_volumes
    call :cleanup_docker_networks
    call :cleanup_docker_images
    
    if "%DEEP_CLEANUP%"=="true" (
        if "%FORCE%"=="false" (
            choice /C YN /M "🧹 Perform Docker system prune?"
            if errorlevel 2 goto :eof
        )
        call :execute_or_show "Docker system prune" "docker system prune -a --volumes -f"
    )
)
goto :eof

:cleanup_docker_containers
set COMPOSE_DIR=%PROJECT_ROOT%\docker-compose

if not exist "%COMPOSE_DIR%" (
    echo [WARN] Docker compose directory not found
    goto :eof
)

echo [INFO] 🐳 Cleaning up Docker containers...

cd /d "%COMPOSE_DIR%"

if "%FORCE%"=="false" (
    choice /C YN /M "🛑 Stop and remove all containers?"
    if errorlevel 2 goto :eof
)

call :execute_or_show "Stopping containers" "docker-compose down"

REM Remove any remaining project containers
for /f "tokens=*" %%i in ('docker ps -a --filter "label=com.docker.compose.project" --format "{{.ID}}" 2^>nul') do (
    call :execute_or_show "Removing container %%i" "docker rm -f %%i"
)
goto :eof

:cleanup_docker_volumes
echo [INFO] 💾 Cleaning up Docker volumes...

set COMPOSE_DIR=%PROJECT_ROOT%\docker-compose

if not exist "%COMPOSE_DIR%" (
    echo [WARN] Docker compose directory not found
    goto :eof
)

cd /d "%COMPOSE_DIR%"

if "%FORCE%"=="false" (
    choice /C YN /M "🗑️  Remove all project volumes (ALL DATA WILL BE LOST)?"
    if errorlevel 2 goto :eof
)

call :execute_or_show "Removing compose volumes" "docker-compose down -v"

if "%DEEP_CLEANUP%"=="true" (
    call :execute_or_show "Removing unused volumes" "docker volume prune -f"
)
goto :eof

:cleanup_docker_networks
echo [INFO] 🌐 Cleaning up Docker networks...

if "%FORCE%"=="false" (
    choice /C YN /M "🔌 Remove project networks?"
    if errorlevel 2 goto :eof
)

REM Remove project networks (simplified for batch)
call :execute_or_show "Removing project networks" "docker network prune -f"

goto :eof

:cleanup_docker_images
echo [INFO] 📦 Cleaning up Docker images...

if "%FORCE%"=="false" (
    choice /C YN /M "🖼️  Remove project images?"
    if errorlevel 2 goto :eof
)

REM Remove project images
for /f "tokens=*" %%i in ('docker images --filter "reference=*justenoughforagame*" --format "{{.ID}}" 2^>nul') do (
    call :execute_or_show "Removing image %%i" "docker rmi -f %%i"
)

for /f "tokens=*" %%i in ('docker images --filter "reference=*tictactoe*" --format "{{.ID}}" 2^>nul') do (
    call :execute_or_show "Removing image %%i" "docker rmi -f %%i"
)

if "%DEEP_CLEANUP%"=="true" (
    call :execute_or_show "Removing dangling images" "docker image prune -f"
    
    if "%FORCE%"=="false" (
        choice /C YN /M "Remove ALL unused images?"
        if errorlevel 2 goto :eof
    )
    call :execute_or_show "Removing all unused images" "docker image prune -a -f"
)
goto :eof

:cleanup_k8s
echo [INFO] ☸️  Cleaning up Kubernetes resources...

kubectl version --client >nul 2>&1
if errorlevel 1 (
    echo [WARN] kubectl not found
    goto :eof
)

kubectl cluster-info >nul 2>&1
if errorlevel 1 (
    echo [WARN] Cannot connect to Kubernetes cluster
    goto :eof
)

set K8S_DIR=%PROJECT_ROOT%\deployment\kubernetes

if not exist "%K8S_DIR%" (
    echo [WARN] Kubernetes deployment directory not found
    goto :eof
)

if "%FORCE%"=="false" (
    choice /C YN /M "🗑️  Delete all Kubernetes resources in game-namespace?"
    if errorlevel 2 goto :eof
)

call :execute_or_show "Deleting Kubernetes resources" "kubectl delete -f %K8S_DIR%\ --ignore-not-found=true"
call :execute_or_show "Deleting namespace" "kubectl delete namespace game-namespace --ignore-not-found=true"

goto :eof

:cleanup_aws
echo [INFO] ☁️  AWS resource cleanup guidance...

echo [WARN] ⚠️  AWS resources require careful manual cleanup to avoid charges

set STACK_NAME=justenoughforagame-prod-infrastructure

aws --version >nul 2>&1
if errorlevel 1 (
    echo [INFO] AWS CLI not configured. Manual cleanup required:
    echo [INFO] 1. Go to AWS CloudFormation Console
    echo [INFO] 2. Delete stack: %STACK_NAME%
    echo [INFO] 3. Verify all resources are deleted
    goto :cleanup_aws_manual
)

aws sts get-caller-identity >nul 2>&1
if errorlevel 1 (
    echo [INFO] AWS credentials not configured. Manual cleanup required.
    goto :cleanup_aws_manual
)

if "%FORCE%"=="false" (
    choice /C YN /M "🗑️  Delete CloudFormation stack '%STACK_NAME%'?"
    if errorlevel 2 goto :cleanup_aws_manual
)

call :execute_or_show "Deleting CloudFormation stack" "aws cloudformation delete-stack --stack-name %STACK_NAME%"

if "%DRY_RUN%"=="false" (
    echo [INFO] ⏳ Stack deletion initiated. Monitor progress in AWS Console
    echo [INFO] This may take several minutes...
)

:cleanup_aws_manual
echo [INFO] 📋 Additional resources to check manually:
echo [INFO]    • ECS Tasks and Services
echo [INFO]    • Lambda Functions
echo [INFO]    • DynamoDB Tables
echo [INFO]    • ElastiCache Clusters
echo [INFO]    • ECS Container Images in ECR
echo [INFO]    • CloudWatch Log Groups
echo [INFO]    • IAM Roles and Policies
echo [INFO]    • VPC and related networking resources

goto :eof

:cleanup_logs
if "%CLEAN_LOGS%"=="false" goto :eof

echo [INFO] 📝 Cleaning up log files...

REM Clean up common log directories
set LOG_DIRS="%PROJECT_ROOT%\logs" "%USERPROFILE%\.justenoughforagame\logs" "%TEMP%\justenoughforagame-logs"

for %%d in (%LOG_DIRS%) do (
    if exist %%d (
        if "%FORCE%"=="false" (
            choice /C YN /M "Delete logs in %%d?"
            if errorlevel 2 goto :skip_log_dir
        )
        call :execute_or_show "Cleaning %%d" "rmdir /s /q %%d"
        :skip_log_dir
    )
)

goto :eof

:execute_or_show
set DESCRIPTION=%~1
set COMMAND=%~2

if "%DRY_RUN%"=="true" (
    echo [INFO] [DRY RUN] %DESCRIPTION%: %COMMAND%
) else (
    echo [INFO] %DESCRIPTION%...
    %COMMAND%
)
goto :eof
