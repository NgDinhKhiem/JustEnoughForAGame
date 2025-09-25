@echo off
setlocal enabledelayedexpansion

REM JustEnoughForAGame Infrastructure Health Check Script for Windows
REM Performs comprehensive health checks across all platforms

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..\..

REM Default values
set PLATFORM=docker
set SERVICES=
set DETAILED=false
set WATCH=false
set INTERVAL=5

REM Health check counters
set TOTAL_CHECKS=0
set PASSED_CHECKS=0
set FAILED_CHECKS=0

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
if "%~1"=="-d" (
    set DETAILED=true
    shift
    goto :parse_args
)
if "%~1"=="--detailed" (
    set DETAILED=true
    shift
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
echo Perform health checks on JustEnoughForAGame infrastructure
echo.
echo OPTIONS:
echo   -p, --platform      Platform to check (docker^|k8s^|aws^|all) [default: docker]
echo   -s, --services      Specific services to check (comma-separated)
echo   -d, --detailed      Show detailed output [default: false]
echo   -w, --watch         Continuous monitoring mode [default: false]
echo   -i, --interval      Watch interval in seconds [default: 5]
echo   -h, --help         Show this help message
echo.
echo EXAMPLES:
echo   %~n0                                   # Check Docker services
echo   %~n0 -p all -d                       # Detailed check of all platforms
echo   %~n0 -s redis,postgres               # Check specific services
echo   %~n0 -w -i 10                        # Watch mode with 10s interval
echo.
exit /b 0

:start_main
echo [INFO] 🏥 Starting health checks for platform: %PLATFORM%
echo.

if "%WATCH%"=="true" goto :watch_mode

call :run_health_checks
goto :eof

:watch_mode
echo [INFO] 👀 Starting continuous monitoring (Ctrl+C to stop)...
echo [INFO] Refresh interval: %INTERVAL%s
echo.

:watch_loop
cls
echo === JustEnoughForAGame Health Check - %date% %time% ===
echo.

call :run_health_checks

echo.
echo Next check in %INTERVAL%s... (Ctrl+C to stop)
timeout /t %INTERVAL% >nul
goto :watch_loop

:run_health_checks
REM Reset counters
set TOTAL_CHECKS=0
set PASSED_CHECKS=0
set FAILED_CHECKS=0

REM Check prerequisites
call :check_prerequisites

REM Platform-specific checks
if "%PLATFORM%"=="docker" call :check_docker_services
if "%PLATFORM%"=="k8s" call :check_k8s_services
if "%PLATFORM%"=="aws" call :check_aws_services
if "%PLATFORM%"=="all" (
    call :check_docker_services
    call :check_k8s_services
    call :check_aws_services
)

REM Print summary
echo.
echo [INFO] 📊 Health Check Summary:
echo [INFO]    Total Checks: %TOTAL_CHECKS%
echo [INFO]    Passed: %PASSED_CHECKS%
if %FAILED_CHECKS% gtr 0 (
    echo [ERROR]    Failed: %FAILED_CHECKS%
    echo.
    echo [WARN] ⚠️  Some health checks failed. See details above.
    exit /b 1
) else (
    echo [INFO]    Failed: %FAILED_CHECKS%
    echo.
    echo [INFO] 🎉 All health checks passed!
)
goto :eof

:check_prerequisites
echo [INFO] 🔧 Checking system prerequisites...

REM Check common tools
call :perform_check "curl" "curl --version"
call :perform_check "git" "git --version"

REM Platform-specific checks
if "%PLATFORM%"=="docker" (
    call :perform_check "Docker" "docker --version"
    call :perform_check "Docker Compose" "docker-compose --version"
)
if "%PLATFORM%"=="k8s" (
    call :perform_check "kubectl" "kubectl version --client"
)
if "%PLATFORM%"=="aws" (
    call :perform_check "AWS CLI" "aws --version"
)
if "%PLATFORM%"=="all" (
    call :perform_check "Docker" "docker --version"
    call :perform_check "Docker Compose" "docker-compose --version"
    call :perform_check "kubectl" "kubectl version --client"
    call :perform_check "AWS CLI" "aws --version"
)
goto :eof

:check_docker_services
set COMPOSE_DIR=%PROJECT_ROOT%\docker-compose

if not exist "%COMPOSE_DIR%\docker-compose.yml" (
    echo [ERROR] docker-compose.yml not found in %COMPOSE_DIR%
    goto :eof
)

cd /d "%COMPOSE_DIR%"

echo [INFO] 🐳 Checking Docker services...

REM Check Docker daemon
call :perform_check "Docker daemon" "docker info"

REM Check key services
call :perform_check "redis container" "docker-compose ps redis | findstr Up"
call :perform_check "postgres container" "docker-compose ps postgres | findstr Up"
call :perform_check "kafka container" "docker-compose ps kafka | findstr Up"

REM Service-specific connectivity checks
docker-compose exec -T redis redis-cli ping >nul 2>&1
if not errorlevel 1 (
    call :check_passed "redis connectivity"
) else (
    call :check_failed "redis connectivity"
)

REM Check networks and volumes
call :perform_check "Docker network" "docker network ls | findstr docker-compose"
call :perform_check "Docker volumes" "docker volume ls | findstr docker-compose"

goto :eof

:check_k8s_services
echo [INFO] ☸️  Checking Kubernetes services...

REM Check cluster connectivity
call :perform_check "Kubernetes cluster" "kubectl cluster-info"

REM Check namespace
call :perform_check "Game namespace" "kubectl get namespace game-namespace"

REM Check deployments (simplified for batch)
call :perform_check "Kubernetes services" "kubectl get services -n game-namespace"
call :perform_check "Ingress controller" "kubectl get ingress -n game-namespace"

goto :eof

:check_aws_services
echo [INFO] ☁️  Checking AWS services...

REM Check AWS CLI and credentials
call :perform_check "AWS CLI" "aws --version"
call :perform_check "AWS credentials" "aws sts get-caller-identity"

REM Check CloudFormation stack
set STACK_NAME=justenoughforagame-prod-infrastructure
aws cloudformation describe-stacks --stack-name %STACK_NAME% >nul 2>&1
if not errorlevel 1 (
    call :check_passed "CloudFormation stack"
) else (
    call :check_failed "CloudFormation stack"
)

goto :eof

:perform_check
set CHECK_NAME=%~1
set CHECK_COMMAND=%~2

set /a TOTAL_CHECKS+=1

if "%DETAILED%"=="true" echo [DEBUG] 🔍 Checking %CHECK_NAME%...

%CHECK_COMMAND% >nul 2>&1
if not errorlevel 1 (
    call :check_passed "%CHECK_NAME%"
) else (
    call :check_failed "%CHECK_NAME%"
)
goto :eof

:check_passed
set /a PASSED_CHECKS+=1
if "%DETAILED%"=="true" echo [SUCCESS] ✅ %~1 PASS
goto :eof

:check_failed
set /a FAILED_CHECKS+=1
if "%DETAILED%"=="true" echo [ERROR] ❌ %~1 FAIL
goto :eof
