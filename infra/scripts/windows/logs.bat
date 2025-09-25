@echo off
setlocal enabledelayedexpansion

REM JustEnoughForAGame Infrastructure Logs Script for Windows
REM Comprehensive log viewing and management for all platforms

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..\..

REM Default values
set PLATFORM=docker
set SERVICE=
set FOLLOW=false
set TAIL_LINES=100
set SINCE=
set LOG_LEVEL=
set GREP_PATTERN=
set EXPORT_FILE=
set LOG_FORMAT=pretty

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
if "%~1"=="-f" (
    set FOLLOW=true
    shift
    goto :parse_args
)
if "%~1"=="--follow" (
    set FOLLOW=true
    shift
    goto :parse_args
)
if "%~1"=="-t" (
    set TAIL_LINES=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="--tail" (
    set TAIL_LINES=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="-s" (
    set SINCE=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="--since" (
    set SINCE=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="-l" (
    set LOG_LEVEL=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="--level" (
    set LOG_LEVEL=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="--grep" (
    set GREP_PATTERN=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="--export" (
    set EXPORT_FILE=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="--format" (
    set LOG_FORMAT=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="-h" goto :show_help
if "%~1"=="--help" goto :show_help

REM Check if it's a service name (not an option)
if not "%~1"=="-*" (
    if "%SERVICE%"=="" (
        set SERVICE=%~1
        shift
        goto :parse_args
    ) else (
        echo [ERROR] Multiple services specified: %SERVICE% and %~1
        goto :show_help
    )
)

echo [ERROR] Unknown option: %~1
goto :show_help

:show_help
echo Usage: %~n0 [OPTIONS] [SERVICE]
echo.
echo View logs from JustEnoughForAGame infrastructure services
echo.
echo ARGUMENTS:
echo   SERVICE             Specific service to view logs for
echo.
echo OPTIONS:
echo   -p, --platform      Platform (docker^|k8s^|aws) [default: docker]
echo   -f, --follow        Follow log output [default: false]
echo   -t, --tail          Number of lines to show [default: 100]
echo   -s, --since         Show logs since timestamp (e.g., '2h', '30m')
echo   -l, --level         Log level filter (error^|warn^|info^|debug)
echo   --grep              Filter logs with pattern
echo   --export            Export logs to file
echo   --format            Log format (raw^|pretty) [default: pretty]
echo   -h, --help         Show this help message
echo.
echo EXAMPLES:
echo   %~n0                                   # Show all Docker service logs
echo   %~n0 redis                            # Show Redis logs
echo   %~n0 -f -t 50 postgres               # Follow PostgreSQL logs (50 lines)
echo   %~n0 -p k8s --grep ERROR              # K8s logs with ERROR pattern
echo   %~n0 --since 1h --level error         # Error logs from last hour
echo   %~n0 --export C:\temp\logs.txt        # Export logs to file
echo.
exit /b 0

:start_main
echo [INFO] 📝 JustEnoughForAGame Log Viewer
echo [INFO] Platform: %PLATFORM%
if not "%SERVICE%"=="" echo [INFO] Service: %SERVICE%

if "%PLATFORM%"=="docker" call :view_docker_logs
if "%PLATFORM%"=="k8s" call :view_k8s_logs
if "%PLATFORM%"=="aws" call :view_aws_logs

if not "%EXPORT_FILE%"=="" (
    if "%FOLLOW%"=="false" (
        echo [INFO] Logs exported to: %EXPORT_FILE%
    )
)
goto :eof

:view_docker_logs
set COMPOSE_DIR=%PROJECT_ROOT%\docker-compose

if not exist "%COMPOSE_DIR%\docker-compose.yml" (
    echo [ERROR] docker-compose.yml not found in %COMPOSE_DIR%
    exit /b 1
)

cd /d "%COMPOSE_DIR%"

echo [INFO] 🐳 Viewing Docker logs...
if "%FOLLOW%"=="true" echo [INFO] Following logs (Ctrl+C to stop)...

REM Build docker-compose logs command
set DOCKER_CMD=docker-compose logs

REM Add tail option
if %TAIL_LINES% gtr 0 set DOCKER_CMD=%DOCKER_CMD% --tail=%TAIL_LINES%

REM Add since option
if not "%SINCE%"=="" set DOCKER_CMD=%DOCKER_CMD% --since=%SINCE%

REM Add follow option
if "%FOLLOW%"=="true" set DOCKER_CMD=%DOCKER_CMD% -f

REM Add service if specified
if not "%SERVICE%"=="" set DOCKER_CMD=%DOCKER_CMD% %SERVICE%

REM Add timestamps
set DOCKER_CMD=%DOCKER_CMD% -t

REM Execute command with optional filtering and export
if not "%EXPORT_FILE%"=="" (
    if not "%GREP_PATTERN%"=="" (
        %DOCKER_CMD% | findstr /i "%GREP_PATTERN%" > "%EXPORT_FILE%"
    ) else (
        %DOCKER_CMD% > "%EXPORT_FILE%"
    )
) else (
    if not "%GREP_PATTERN%"=="" (
        %DOCKER_CMD% | findstr /i "%GREP_PATTERN%"
    ) else (
        %DOCKER_CMD%
    )
)

goto :eof

:view_k8s_logs
kubectl version --client >nul 2>&1
if errorlevel 1 (
    echo [ERROR] kubectl not found
    exit /b 1
)

kubectl cluster-info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Cannot connect to Kubernetes cluster
    exit /b 1
)

set NAMESPACE=game-namespace

echo [INFO] ☸️  Viewing Kubernetes logs...

REM Build kubectl logs command
set KUBECTL_CMD=kubectl logs

REM Add tail option
if %TAIL_LINES% gtr 0 set KUBECTL_CMD=%KUBECTL_CMD% --tail=%TAIL_LINES%

REM Add since option
if not "%SINCE%"=="" set KUBECTL_CMD=%KUBECTL_CMD% --since=%SINCE%

REM Add follow option
if "%FOLLOW%"=="true" set KUBECTL_CMD=%KUBECTL_CMD% -f

REM Add timestamps
set KUBECTL_CMD=%KUBECTL_CMD% --timestamps=true

REM Add namespace
set KUBECTL_CMD=%KUBECTL_CMD% -n %NAMESPACE%

if not "%SERVICE%"=="" (
    REM Get specific service logs
    set KUBECTL_CMD=%KUBECTL_CMD% deployment/%SERVICE%
    
    echo [INFO] Service: %SERVICE%
    if "%FOLLOW%"=="true" echo [INFO] Following logs (Ctrl+C to stop)...
    
    REM Execute command with optional filtering and export
    if not "%EXPORT_FILE%"=="" (
        if not "%GREP_PATTERN%"=="" (
            %KUBECTL_CMD% | findstr /i "%GREP_PATTERN%" > "%EXPORT_FILE%"
        ) else (
            %KUBECTL_CMD% > "%EXPORT_FILE%"
        )
    ) else (
        if not "%GREP_PATTERN%"=="" (
            %KUBECTL_CMD% | findstr /i "%GREP_PATTERN%"
        ) else (
            %KUBECTL_CMD%
        )
    )
) else (
    REM Get all pods in namespace
    echo [INFO] Found pods, showing logs...
    
    for /f "tokens=*" %%i in ('kubectl get pods -n %NAMESPACE% -o name 2^>nul') do (
        echo.
        echo [INFO] === Logs for %%i ===
        
        set POD_CMD=%KUBECTL_CMD% %%i
        
        if not "%GREP_PATTERN%"=="" (
            !POD_CMD! 2>nul | findstr /i "%GREP_PATTERN%" || echo [WARN] Could not get logs for %%i
        ) else (
            !POD_CMD! 2>nul || echo [WARN] Could not get logs for %%i
        )
    )
)

goto :eof

:view_aws_logs
aws --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] AWS CLI not found
    exit /b 1
)

aws sts get-caller-identity >nul 2>&1
if errorlevel 1 (
    echo [ERROR] AWS credentials not configured
    exit /b 1
)

echo [INFO] ☁️  Viewing AWS CloudWatch logs...

REM Get available log groups
for /f "tokens=*" %%i in ('aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/justenoughforagame" --query "logGroups[*].logGroupName" --output text 2^>nul') do set LOG_GROUPS=%%i

if "%LOG_GROUPS%"=="" (
    echo [WARN] No CloudWatch log groups found for JustEnoughForAGame
    goto :eof
)

if not "%SERVICE%"=="" (
    REM Look for specific service log group (simplified for batch)
    echo [INFO] Searching for service: %SERVICE%
    
    REM This is a simplified version - full pattern matching would be more complex in batch
    echo [INFO] Available log groups:
    for %%g in (%LOG_GROUPS%) do echo [INFO]   - %%g
    echo.
    echo [INFO] Use AWS Console or AWS CLI directly for specific log group viewing:
    echo [INFO] aws logs tail [LOG_GROUP_NAME] --follow
) else (
    echo [INFO] Available log groups:
    for %%g in (%LOG_GROUPS%) do echo [INFO]   - %%g
    echo.
    echo [INFO] Use --SERVICE parameter to specify which service logs to view
)

goto :eof
