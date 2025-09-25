@echo off
setlocal enabledelayedexpansion

REM JustEnoughForAGame Infrastructure Status Script for Windows
REM Shows comprehensive status of all infrastructure components

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..\..

REM Default values
set PLATFORM=all
set SERVICES=
set FORMAT=table
set WATCH=false
set INTERVAL=5

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
if "%~1"=="-f" (
    set FORMAT=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="--format" (
    set FORMAT=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="-w" (
    set WATCH=true
    shift
    goto :parse_args
)
if "%~1"=="--watch" (
    set WATCH=true
    shift
    goto :parse_args
)
if "%~1"=="-i" (
    set INTERVAL=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="--interval" (
    set INTERVAL=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="-h" goto :show_help
if "%~1"=="--help" goto :show_help

echo [ERROR] Unknown option: %~1
goto :show_help

:show_help
echo Usage: %~n0 [OPTIONS]
echo.
echo Show status of JustEnoughForAGame infrastructure
echo.
echo OPTIONS:
echo   -p, --platform      Platform to check (docker^|k8s^|aws^|all) [default: all]
echo   -s, --services      Specific services to show (comma-separated)
echo   -f, --format        Output format (table^|simple) [default: table]
echo   -w, --watch         Continuous monitoring mode [default: false]
echo   -i, --interval      Watch interval in seconds [default: 5]
echo   -h, --help         Show this help message
echo.
echo EXAMPLES:
echo   %~n0                                   # Show status of all platforms
echo   %~n0 -p docker                       # Docker status only
echo   %~n0 -s redis,postgres               # Status of specific services
echo   %~n0 -w -i 10                        # Watch mode with 10s interval
echo.
exit /b 0

:start_main
if "%WATCH%"=="true" goto :watch_mode

call :run_status_check
goto :eof

:watch_mode
echo [INFO] 👀 Starting continuous monitoring (Ctrl+C to stop)...
echo [INFO] Refresh interval: %INTERVAL%s
echo.

:watch_loop
cls
echo Last updated: %date% %time%
echo.

call :run_status_check

echo.
echo Next update in %INTERVAL%s... (Ctrl+C to stop)
timeout /t %INTERVAL% >nul
goto :watch_loop

:run_status_check
if "%FORMAT%"=="table" (
    echo ==================================================================================
    echo                     JustEnoughForAGame Infrastructure Status
    echo ==================================================================================
    echo.
)

REM Docker status
if "%PLATFORM%"=="docker" call :get_docker_status
if "%PLATFORM%"=="all" call :get_docker_status

REM Kubernetes status
if "%PLATFORM%"=="k8s" call :get_k8s_status
if "%PLATFORM%"=="all" call :get_k8s_status

REM AWS status
if "%PLATFORM%"=="aws" call :get_aws_status
if "%PLATFORM%"=="all" call :get_aws_status

goto :eof

:get_docker_status
if "%FORMAT%"=="table" (
    echo 🐳 DOCKER SERVICES
    echo --------------------------------------------------------------------------------
)

set COMPOSE_DIR=%PROJECT_ROOT%\docker-compose

if not exist "%COMPOSE_DIR%\docker-compose.yml" (
    call :print_status "Docker" "not_available"
    if "%FORMAT%"=="table" echo.
    goto :eof
)

cd /d "%COMPOSE_DIR%"

REM Check Docker daemon
docker info >nul 2>&1
if not errorlevel 1 (
    call :print_status "Docker Daemon" "running"
) else (
    call :print_status "Docker Daemon" "not_running"
    if "%FORMAT%"=="table" echo.
    goto :eof
)

REM Check common services
call :check_docker_service redis
call :check_docker_service postgres
call :check_docker_service kafka
call :check_docker_service clickhouse
call :check_docker_service "redis-commander"
call :check_docker_service pgadmin

if "%FORMAT%"=="table" echo.
goto :eof

:check_docker_service
set SERVICE_NAME=%~1

docker-compose ps %SERVICE_NAME% 2>nul | findstr /i "Up" >nul
if not errorlevel 1 (
    docker-compose ps %SERVICE_NAME% 2>nul | findstr /i "healthy" >nul
    if not errorlevel 1 (
        call :print_status "%SERVICE_NAME%" "healthy"
    ) else (
        call :print_status "%SERVICE_NAME%" "running"
    )
) else (
    docker-compose ps %SERVICE_NAME% 2>nul | findstr /i "Exit" >nul
    if not errorlevel 1 (
        call :print_status "%SERVICE_NAME%" "exited"
    ) else (
        call :print_status "%SERVICE_NAME%" "not_created"
    )
)
goto :eof

:get_k8s_status
if "%FORMAT%"=="table" (
    echo ☸️  KUBERNETES SERVICES
    echo --------------------------------------------------------------------------------
)

kubectl version --client >nul 2>&1
if errorlevel 1 (
    call :print_status "Kubernetes" "not_available"
    if "%FORMAT%"=="table" echo.
    goto :eof
)

REM Check cluster connectivity
kubectl cluster-info >nul 2>&1
if not errorlevel 1 (
    call :print_status "Cluster" "connected"
) else (
    call :print_status "Cluster" "not_connected"
    if "%FORMAT%"=="table" echo.
    goto :eof
)

REM Check namespace
kubectl get namespace game-namespace >nul 2>&1
if not errorlevel 1 (
    call :print_status "Namespace" "exists"
) else (
    call :print_status "Namespace" "not_found"
)

REM Check services (simplified)
kubectl get services -n game-namespace >nul 2>&1
if not errorlevel 1 (
    call :print_status "Services" "available"
) else (
    call :print_status "Services" "not_found"
)

if "%FORMAT%"=="table" echo.
goto :eof

:get_aws_status
if "%FORMAT%"=="table" (
    echo ☁️  AWS SERVICES
    echo --------------------------------------------------------------------------------
)

aws --version >nul 2>&1
if errorlevel 1 (
    call :print_status "AWS" "not_available"
    if "%FORMAT%"=="table" echo.
    goto :eof
)

call :print_status "AWS CLI" "available"

REM Check credentials
aws sts get-caller-identity >nul 2>&1
if not errorlevel 1 (
    call :print_status "Credentials" "valid"
) else (
    call :print_status "Credentials" "invalid"
    if "%FORMAT%"=="table" echo.
    goto :eof
)

REM Check CloudFormation stack
set STACK_NAME=justenoughforagame-prod-infrastructure
for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --query "Stacks[0].StackStatus" --output text 2^>nul') do set STACK_STATUS=%%i

if not "%STACK_STATUS%"=="" (
    call :print_status "CloudFormation" "%STACK_STATUS%"
) else (
    call :print_status "CloudFormation" "NOT_FOUND"
)

REM Check ECS cluster
set CLUSTER_NAME=justenoughforagame-cluster
for /f "tokens=*" %%i in ('aws ecs describe-clusters --clusters %CLUSTER_NAME% --query "clusters[0].status" --output text 2^>nul') do set CLUSTER_STATUS=%%i

if not "%CLUSTER_STATUS%"=="" (
    call :print_status "ECS Cluster" "%CLUSTER_STATUS%"
) else (
    call :print_status "ECS Cluster" "NOT_FOUND"
)

if "%FORMAT%"=="table" echo.
goto :eof

:print_status
set ITEM_NAME=%~1
set STATUS=%~2

if "%FORMAT%"=="simple" (
    echo %ITEM_NAME%: %STATUS%
    goto :eof
)

REM Format with colors and icons (simplified for Windows)
if "%STATUS%"=="running" set STATUS_DISPLAY=✅ %STATUS%
if "%STATUS%"=="healthy" set STATUS_DISPLAY=✅ %STATUS%
if "%STATUS%"=="ready" set STATUS_DISPLAY=✅ %STATUS%
if "%STATUS%"=="connected" set STATUS_DISPLAY=✅ %STATUS%
if "%STATUS%"=="valid" set STATUS_DISPLAY=✅ %STATUS%
if "%STATUS%"=="available" set STATUS_DISPLAY=✅ %STATUS%
if "%STATUS%"=="exists" set STATUS_DISPLAY=✅ %STATUS%
if "%STATUS%"=="ACTIVE" set STATUS_DISPLAY=✅ %STATUS%
if "%STATUS%"=="CREATE_COMPLETE" set STATUS_DISPLAY=✅ %STATUS%
if "%STATUS%"=="UPDATE_COMPLETE" set STATUS_DISPLAY=✅ %STATUS%

if "%STATUS%"=="partial" set STATUS_DISPLAY=⏳ %STATUS%
if "%STATUS%"=="not_ready" set STATUS_DISPLAY=⏳ %STATUS%
if "%STATUS%"=="UPDATE_IN_PROGRESS" set STATUS_DISPLAY=⏳ %STATUS%
if "%STATUS%"=="CREATE_IN_PROGRESS" set STATUS_DISPLAY=⏳ %STATUS%

if "%STATUS%"=="not_running" set STATUS_DISPLAY=❌ %STATUS%
if "%STATUS%"=="exited" set STATUS_DISPLAY=❌ %STATUS%
if "%STATUS%"=="not_connected" set STATUS_DISPLAY=❌ %STATUS%
if "%STATUS%"=="invalid" set STATUS_DISPLAY=❌ %STATUS%
if "%STATUS%"=="not_found" set STATUS_DISPLAY=❌ %STATUS%
if "%STATUS%"=="NOT_FOUND" set STATUS_DISPLAY=❌ %STATUS%
if "%STATUS%"=="FAILED" set STATUS_DISPLAY=❌ %STATUS%

if "%STATUS%"=="not_available" set STATUS_DISPLAY=⚪ %STATUS%
if "%STATUS%"=="not_created" set STATUS_DISPLAY=⚪ %STATUS%

if not defined STATUS_DISPLAY set STATUS_DISPLAY=ℹ️  %STATUS%

REM Print formatted status (simplified padding for batch)
set "SPACES=                         "
set "PADDED_NAME=%ITEM_NAME%%SPACES%"
set "PADDED_NAME=%PADDED_NAME:~0,25%"

echo %PADDED_NAME% %STATUS_DISPLAY%
goto :eof
