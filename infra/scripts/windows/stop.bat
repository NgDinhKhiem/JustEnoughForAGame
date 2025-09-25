@echo off
setlocal enabledelayedexpansion

REM JustEnoughForAGame Infrastructure Stop Script for Windows
REM Supports local development, AWS, and Kubernetes deployments

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..\..

REM Default values
set ENVIRONMENT=local
set PLATFORM=docker
set SERVICES=
set REMOVE_VOLUMES=false
set REMOVE_NETWORKS=false
set FORCE=false

REM Parse command line arguments
:parse_args
if "%~1"=="" goto :start_main
if "%~1"=="-e" (
    set ENVIRONMENT=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="--environment" (
    set ENVIRONMENT=%~2
    shift /2
    goto :parse_args
)
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
if "%~1"=="-s" (
    set SERVICES=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="--services" (
    set SERVICES=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="-v" (
    set REMOVE_VOLUMES=true
    shift
    goto :parse_args
)
if "%~1"=="--volumes" (
    set REMOVE_VOLUMES=true
    shift
    goto :parse_args
)
if "%~1"=="-n" (
    set REMOVE_NETWORKS=true
    shift
    goto :parse_args
)
if "%~1"=="--networks" (
    set REMOVE_NETWORKS=true
    shift
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
if "%~1"=="-h" goto :show_help
if "%~1"=="--help" goto :show_help

echo [ERROR] Unknown option: %~1
goto :show_help

:show_help
echo Usage: %~n0 [OPTIONS]
echo.
echo Stop JustEnoughForAGame infrastructure services
echo.
echo OPTIONS:
echo   -e, --environment    Environment (local^|dev^|staging^|prod) [default: local]
echo   -p, --platform      Platform (docker^|k8s^|aws) [default: docker]
echo   -s, --services      Specific services to stop (comma-separated)
echo   -v, --volumes       Remove volumes (docker only) [default: false]
echo   -n, --networks      Remove networks (docker only) [default: false]
echo   -f, --force         Force stop without confirmation [default: false]
echo   -h, --help         Show this help message
echo.
echo EXAMPLES:
echo   %~n0                                   # Stop local development environment
echo   %~n0 -v -n                           # Stop and clean volumes and networks
echo   %~n0 -s redis,postgres               # Stop only Redis and PostgreSQL
echo   %~n0 -p k8s -f                       # Force stop Kubernetes services
echo.
exit /b 0

:start_main
echo [INFO] 🛑 Stopping JustEnoughForAGame Infrastructure
echo [INFO] Environment: %ENVIRONMENT%
echo [INFO] Platform: %PLATFORM%

if "%PLATFORM%"=="docker" goto :stop_docker
if "%PLATFORM%"=="k8s" goto :stop_k8s
if "%PLATFORM%"=="aws" goto :stop_aws

echo [ERROR] Unsupported platform: %PLATFORM%
exit /b 1

:stop_docker
set COMPOSE_DIR=%PROJECT_ROOT%\docker-compose

if not exist "%COMPOSE_DIR%\docker-compose.yml" (
    echo [ERROR] docker-compose.yml not found in %COMPOSE_DIR%
    exit /b 1
)

cd /d "%COMPOSE_DIR%"

echo [INFO] 🐳 Stopping Docker Compose services...

if not "%SERVICES%"=="" (
    echo [INFO] Stopping specific services: %SERVICES%
    docker-compose stop %SERVICES%
) else (
    REM Stop all services
    echo [INFO] Stopping all services...
    docker-compose -f docker-compose.yml -f docker-compose.dev.yml down
)

REM Handle volumes cleanup
if "%REMOVE_VOLUMES%"=="true" (
    if "%FORCE%"=="false" (
        choice /C YN /M "🗑️  Are you sure you want to remove all data volumes (ALL DATA WILL BE LOST)?"
        if errorlevel 2 set REMOVE_VOLUMES=false
    )
    
    if "!REMOVE_VOLUMES!"=="true" (
        echo [INFO] 🧹 Removing volumes...
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml down -v
        docker volume prune -f
        echo [INFO] ✅ Volumes removed
    )
)

REM Handle networks cleanup
if "%REMOVE_NETWORKS%"=="true" (
    if "%FORCE%"=="false" (
        choice /C YN /M "🌐 Are you sure you want to remove networks?"
        if errorlevel 2 set REMOVE_NETWORKS=false
    )
    
    if "!REMOVE_NETWORKS!"=="true" (
        echo [INFO] 🧹 Removing networks...
        docker network prune -f
        echo [INFO] ✅ Networks removed
    )
)

echo [INFO] ✅ Docker services stopped successfully!
goto :end_main

:stop_k8s
kubectl version --client >nul 2>&1
if errorlevel 1 (
    echo [ERROR] kubectl is not installed
    exit /b 1
)

kubectl cluster-info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] kubectl cannot connect to cluster
    exit /b 1
)

set K8S_DIR=%PROJECT_ROOT%\deployment\kubernetes

if not exist "%K8S_DIR%" (
    echo [ERROR] Kubernetes deployment directory not found: %K8S_DIR%
    exit /b 1
)

echo [INFO] ☸️  Stopping Kubernetes services...

if not "%SERVICES%"=="" (
    REM Stop specific services (simplified for batch)
    for %%s in (%SERVICES%) do (
        if exist "%K8S_DIR%\%%s-service.yaml" (
            echo [INFO] Deleting %%s...
            kubectl delete -f "%K8S_DIR%\%%s-service.yaml" --ignore-not-found=true
        )
    )
) else (
    if "%FORCE%"=="false" (
        choice /C YN /M "🗑️  Are you sure you want to delete all Kubernetes resources?"
        if errorlevel 2 (
            echo [INFO] Operation cancelled
            exit /b 0
        )
    )
    
    echo [INFO] Deleting all resources...
    kubectl delete -f "%K8S_DIR%\" --ignore-not-found=true
)

echo [INFO] ✅ Kubernetes services stopped successfully!
goto :end_main

:stop_aws
echo [WARN] ⚠️  AWS service termination requires manual intervention
echo [INFO] To stop AWS services:
echo [INFO] 1. Go to AWS Console
echo [INFO] 2. Navigate to CloudFormation
echo [INFO] 3. Delete the stack: justenoughforagame-%ENVIRONMENT%-infrastructure
echo [INFO] 4. Or use AWS CLI:
echo [INFO]    aws cloudformation delete-stack --stack-name justenoughforagame-%ENVIRONMENT%-infrastructure

aws --version >nul 2>&1
if errorlevel 1 goto :end_main

aws sts get-caller-identity >nul 2>&1
if errorlevel 1 goto :end_main

if "%FORCE%"=="false" (
    choice /C YN /M "Do you want to attempt automatic stack deletion?"
    if errorlevel 2 goto :end_main
)

echo [INFO] Attempting to delete CloudFormation stack...
aws cloudformation delete-stack --stack-name justenoughforagame-%ENVIRONMENT%-infrastructure
echo [INFO] Stack deletion initiated. Check AWS Console for progress.

goto :end_main

:end_main
echo.
echo [INFO] ✅ Infrastructure stopped successfully!
echo.
echo [INFO] 🚀 To start again: start.bat
