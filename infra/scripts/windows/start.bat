@echo off
setlocal enabledelayedexpansion

REM JustEnoughForAGame Infrastructure Start Script for Windows
REM Supports local development, AWS, and Kubernetes deployments

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..\..

REM Default values
set ENVIRONMENT=local
set PLATFORM=docker
set SERVICES=
set MONITORING=false
set WAIT_FOR_HEALTH=true

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
if "%~1"=="-m" (
    set MONITORING=true
    shift
    goto :parse_args
)
if "%~1"=="--monitoring" (
    set MONITORING=true
    shift
    goto :parse_args
)
if "%~1"=="--no-wait" (
    set WAIT_FOR_HEALTH=false
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
echo Start JustEnoughForAGame infrastructure services
echo.
echo OPTIONS:
echo   -e, --environment    Environment (local^|dev^|staging^|prod) [default: local]
echo   -p, --platform      Platform (docker^|k8s^|aws) [default: docker]
echo   -s, --services      Specific services to start (comma-separated)
echo   -m, --monitoring    Include monitoring stack [default: false]
echo   --no-wait          Don't wait for services to be healthy
echo   -h, --help         Show this help message
echo.
echo EXAMPLES:
echo   %~n0                                   # Start local development environment
echo   %~n0 -e dev -p k8s                   # Start dev environment on Kubernetes
echo   %~n0 -s redis,postgres               # Start only Redis and PostgreSQL
echo   %~n0 -m                              # Start with monitoring stack
echo.
exit /b 0

:start_main
echo [INFO] 🎮 Starting JustEnoughForAGame Infrastructure
echo [INFO] Environment: %ENVIRONMENT%
echo [INFO] Platform: %PLATFORM%
echo [INFO] Monitoring: %MONITORING%

if "%PLATFORM%"=="docker" goto :start_docker
if "%PLATFORM%"=="k8s" goto :start_k8s
if "%PLATFORM%"=="aws" goto :start_aws

echo [ERROR] Unsupported platform: %PLATFORM%
exit /b 1

:start_docker
echo [INFO] 🐳 Starting Docker Compose services...

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running. Please start Docker first.
    exit /b 1
)

set COMPOSE_DIR=%PROJECT_ROOT%\docker-compose
if not exist "%COMPOSE_DIR%\docker-compose.yml" (
    echo [ERROR] docker-compose.yml not found in %COMPOSE_DIR%
    exit /b 1
)

cd /d "%COMPOSE_DIR%"

if not "%SERVICES%"=="" (
    echo [INFO] Starting specific services: %SERVICES%
    docker-compose up -d %SERVICES%
) else (
    REM Start core services first
    echo [INFO] Starting core infrastructure services...
    docker-compose up -d redis postgres zookeeper kafka

    if "%WAIT_FOR_HEALTH%"=="true" (
        call :wait_for_service redis
        call :wait_for_service postgres
        call :wait_for_service kafka
    )

    REM Start application services
    echo [INFO] Starting analytics and monitoring services...
    docker-compose up -d clickhouse dynamodb-local localstack

    REM Start development tools if in local/dev environment
    if "%ENVIRONMENT%"=="local" (
        echo [INFO] Starting development tools...
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d kafka-ui redis-commander pgadmin
    )
    if "%ENVIRONMENT%"=="dev" (
        echo [INFO] Starting development tools...
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d kafka-ui redis-commander pgadmin
    )

    REM Start monitoring stack if requested
    if "%MONITORING%"=="true" (
        echo [INFO] Starting monitoring stack...
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d prometheus grafana jaeger
    )
)

echo [INFO] 🎉 Infrastructure started successfully!
echo.
echo [INFO] 📋 Service URLs:
echo [INFO]    🔴 Redis Commander:    http://localhost:8081
echo [INFO]    🐘 pgAdmin:           http://localhost:8082
echo [INFO]    📨 Kafka UI:          http://localhost:8080
echo [INFO]    🔍 ClickHouse:        http://localhost:8123
echo [INFO]    🏠 LocalStack:        http://localhost:4566
echo [INFO]    📊 DynamoDB Local:    http://localhost:8000

if "%MONITORING%"=="true" (
    echo [INFO]    📈 Prometheus:        http://localhost:9090
    echo [INFO]    📊 Grafana:          http://localhost:3000
    echo [INFO]    🔍 Jaeger:           http://localhost:16686
)

echo.
echo [INFO] 🛑 To stop: stop.bat
echo [INFO] 📊 To check status: status.bat
echo [INFO] 📝 To view logs: logs.bat
goto :eof

:start_k8s
echo [INFO] ☸️  Deploying to Kubernetes...

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

REM Apply namespace first
kubectl apply -f "%K8S_DIR%\namespace.yaml"

REM Apply configurations
kubectl apply -f "%K8S_DIR%\configmap.yaml"

REM Apply services
if not "%SERVICES%"=="" (
    REM Handle specific services (simplified for Windows batch)
    kubectl apply -f "%K8S_DIR%\"
) else (
    kubectl apply -f "%K8S_DIR%\"
)

if "%WAIT_FOR_HEALTH%"=="true" (
    echo [INFO] Waiting for deployments to be ready...
    kubectl wait --for=condition=available --timeout=300s deployment --all -n game-namespace
)

echo [INFO] 🎉 Kubernetes deployment completed!
goto :eof

:start_aws
echo [INFO] ☁️  Deploying to AWS...

aws --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] AWS CLI is not installed
    exit /b 1
)

aws sts get-caller-identity >nul 2>&1
if errorlevel 1 (
    echo [ERROR] AWS credentials are not configured
    exit /b 1
)

set AWS_DIR=%PROJECT_ROOT%\deployment\aws

if not exist "%AWS_DIR%\deploy.sh" (
    echo [ERROR] AWS deployment script not found: %AWS_DIR%\deploy.sh
    exit /b 1
)

cd /d "%AWS_DIR%"
REM Note: This calls the Unix script - for full Windows compatibility, create deploy.bat
bash deploy.sh --environment %ENVIRONMENT%

goto :eof

:wait_for_service
set SERVICE_NAME=%~1
set MAX_ATTEMPTS=30
set ATTEMPT=1

echo [INFO] ⏳ Waiting for %SERVICE_NAME% to be healthy...

:wait_loop
docker-compose ps %SERVICE_NAME% 2>nul | findstr /i "healthy Up" >nul
if not errorlevel 1 (
    echo [INFO] ✅ %SERVICE_NAME% is ready!
    goto :eof
)

echo [DEBUG] 🔄 Attempt %ATTEMPT%/%MAX_ATTEMPTS% - %SERVICE_NAME% not ready yet...
timeout /t 5 >nul
set /a ATTEMPT+=1
if %ATTEMPT% leq %MAX_ATTEMPTS% goto :wait_loop

echo [WARN] ⚠️  %SERVICE_NAME% failed to become healthy within expected time
goto :eof
