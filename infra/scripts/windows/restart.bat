@echo off
setlocal enabledelayedexpansion

REM JustEnoughForAGame Infrastructure Restart Script for Windows
REM Graceful restart of services with health checks

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..\..

REM Default values
set PLATFORM=docker
set ENVIRONMENT=local
set SERVICE=
set WAIT_FOR_HEALTH=true
set TIMEOUT=300
set FORCE=false
set ROLLING=false
set NO_DEPS=false

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
if "%~1"=="-w" (
    set WAIT_FOR_HEALTH=true
    shift
    goto :parse_args
)
if "%~1"=="--wait" (
    set WAIT_FOR_HEALTH=true
    shift
    goto :parse_args
)
if "%~1"=="--no-wait" (
    set WAIT_FOR_HEALTH=false
    shift
    goto :parse_args
)
if "%~1"=="-t" (
    set TIMEOUT=%~2
    shift /2
    goto :parse_args
)
if "%~1"=="--timeout" (
    set TIMEOUT=%~2
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
if "%~1"=="-r" (
    set ROLLING=true
    shift
    goto :parse_args
)
if "%~1"=="--rolling" (
    set ROLLING=true
    shift
    goto :parse_args
)
if "%~1"=="--no-deps" (
    set NO_DEPS=true
    shift
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
echo Restart JustEnoughForAGame infrastructure services
echo.
echo ARGUMENTS:
echo   SERVICE             Specific service to restart (optional)
echo.
echo OPTIONS:
echo   -p, --platform      Platform (docker^|k8s^|aws) [default: docker]
echo   -e, --environment   Environment (local^|dev^|staging^|prod) [default: local]
echo   -w, --wait          Wait for services to be healthy [default: true]
echo   -t, --timeout       Health check timeout in seconds [default: 300]
echo   -f, --force         Force restart without graceful shutdown [default: false]
echo   -r, --rolling       Rolling restart (K8s only) [default: false]
echo   --no-deps           Don't restart dependencies (Docker only) [default: false]
echo   -h, --help          Show this help message
echo.
echo EXAMPLES:
echo   %~n0                                   # Restart all Docker services
echo   %~n0 redis                            # Restart only Redis service
echo   %~n0 -p k8s -r                       # Rolling restart on Kubernetes
echo   %~n0 -f --no-deps postgres           # Force restart PostgreSQL only
echo   %~n0 -e staging -t 600               # Restart staging with 10min timeout
echo.
exit /b 0

:start_main
echo [INFO] 🔄 Restarting JustEnoughForAGame Infrastructure
echo [INFO] Platform: %PLATFORM%
echo [INFO] Environment: %ENVIRONMENT%
if not "%SERVICE%"=="" echo [INFO] Service: %SERVICE%

if "%PLATFORM%"=="docker" call :restart_docker_services
if "%PLATFORM%"=="k8s" call :restart_k8s_services
if "%PLATFORM%"=="aws" call :restart_aws_services

echo [INFO] 🎉 Restart completed successfully!
echo.
echo [INFO] 📊 To check status: status.bat
echo [INFO] 📝 To view logs: logs.bat
goto :eof

:restart_docker_services
set COMPOSE_DIR=%PROJECT_ROOT%\docker-compose

if not exist "%COMPOSE_DIR%\docker-compose.yml" (
    echo [ERROR] docker-compose.yml not found in %COMPOSE_DIR%
    exit /b 1
)

cd /d "%COMPOSE_DIR%"

echo [INFO] 🐳 Restarting Docker services...

if not "%SERVICE%"=="" (
    REM Restart specific service
    echo [INFO] Restarting service: %SERVICE%
    
    if "%FORCE%"=="true" (
        echo [INFO] Force killing service...
        docker-compose kill %SERVICE% 2>nul
        docker-compose rm -f %SERVICE% 2>nul
    ) else (
        echo [INFO] Gracefully stopping service...
        docker-compose stop %SERVICE% 2>nul
    )
    
    REM Start service
    set START_CMD=docker-compose up -d
    if "%NO_DEPS%"=="true" set START_CMD=!START_CMD! --no-deps
    set START_CMD=!START_CMD! %SERVICE%
    
    echo [INFO] Starting service...
    !START_CMD!
    
    REM Wait for health check
    if "%WAIT_FOR_HEALTH%"=="true" call :wait_for_service %SERVICE% docker
) else (
    REM Restart all services
    echo [INFO] Restarting all services...
    
    if "%FORCE%"=="true" (
        echo [INFO] Force stopping all services...
        docker-compose kill 2>nul
        docker-compose down --remove-orphans 2>nul
    ) else (
        echo [INFO] Gracefully stopping services...
        docker-compose down 2>nul
    )
    
    REM Restart based on environment
    echo [INFO] Starting services for environment: %ENVIRONMENT%
    
    if "%ENVIRONMENT%"=="local" (
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
    ) else if "%ENVIRONMENT%"=="dev" (
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
    ) else (
        docker-compose up -d
    )
    
    REM Wait for key services to be healthy
    if "%WAIT_FOR_HEALTH%"=="true" (
        call :wait_for_service redis docker
        call :wait_for_service postgres docker
        call :wait_for_service kafka docker
    )
)

goto :eof

:restart_k8s_services
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

echo [INFO] ☸️  Restarting Kubernetes services...

set NAMESPACE=game-namespace

if not "%SERVICE%"=="" (
    REM Restart specific service
    echo [INFO] Restarting deployment: %SERVICE%
    
    if "%ROLLING%"=="true" (
        echo [INFO] Performing rolling restart...
        kubectl rollout restart deployment/%SERVICE% -n %NAMESPACE%
        
        if "%WAIT_FOR_HEALTH%"=="true" (
            echo [INFO] Waiting for rollout to complete...
            kubectl rollout status deployment/%SERVICE% -n %NAMESPACE% --timeout=%TIMEOUT%s
        )
    ) else (
        if "%FORCE%"=="true" (
            echo [INFO] Force deleting pods...
            kubectl delete pods -l app=%SERVICE% -n %NAMESPACE% --force --grace-period=0
        ) else (
            echo [INFO] Scaling down deployment...
            kubectl scale deployment %SERVICE% --replicas=0 -n %NAMESPACE%
            
            echo [INFO] Waiting for pods to terminate...
            timeout /t 60 >nul
            
            echo [INFO] Scaling up deployment...
            kubectl scale deployment %SERVICE% --replicas=1 -n %NAMESPACE%
        )
        
        if "%WAIT_FOR_HEALTH%"=="true" call :wait_for_service %SERVICE% k8s
    )
) else (
    REM Restart all deployments
    echo [INFO] Restarting all deployments in namespace: %NAMESPACE%
    
    REM Get deployments (simplified for batch)
    for /f "tokens=*" %%i in ('kubectl get deployments -n %NAMESPACE% -o name 2^>nul') do (
        set DEPLOYMENT=%%i
        set DEPLOYMENT_NAME=!DEPLOYMENT:deployment.apps/=!
        
        if "%ROLLING%"=="true" (
            echo [INFO] Rolling restart: !DEPLOYMENT_NAME!
            kubectl rollout restart !DEPLOYMENT! -n %NAMESPACE%
        ) else (
            echo [INFO] Restarting deployment: !DEPLOYMENT_NAME!
            
            if "%FORCE%"=="true" (
                kubectl delete pods -l app=!DEPLOYMENT_NAME! -n %NAMESPACE% --force --grace-period=0
            ) else (
                kubectl scale !DEPLOYMENT! --replicas=0 -n %NAMESPACE%
                timeout /t 60 >nul
                kubectl scale !DEPLOYMENT! --replicas=1 -n %NAMESPACE%
            )
            
            if "%WAIT_FOR_HEALTH%"=="true" call :wait_for_service !DEPLOYMENT_NAME! k8s
        )
    )
    
    if "%ROLLING%"=="true" (
        if "%WAIT_FOR_HEALTH%"=="true" (
            echo [INFO] Waiting for all rollouts to complete...
            for /f "tokens=*" %%i in ('kubectl get deployments -n %NAMESPACE% -o name 2^>nul') do (
                kubectl rollout status %%i -n %NAMESPACE% --timeout=%TIMEOUT%s 2>nul || echo [WARN] Rollout may not have completed for %%i
            )
        )
    )
)

goto :eof

:restart_aws_services
echo [INFO] ☁️  AWS service restart...

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

echo [WARN] ⚠️  AWS services require specific restart procedures

REM ECS Services
set CLUSTER_NAME=justenoughforagame-cluster
for /f "tokens=*" %%i in ('aws ecs list-services --cluster %CLUSTER_NAME% --query "serviceArns[*]" --output text 2^>nul') do set ECS_SERVICES=%%i

if not "%ECS_SERVICES%"=="" (
    echo [INFO] Found ECS services
    
    if not "%SERVICE%"=="" (
        REM Simplified service matching for batch
        echo [INFO] Restarting ECS service containing: %SERVICE%
        
        if "%FORCE%"=="true" (
            echo [INFO] Forcing new deployment...
        ) else (
            echo [INFO] Updating service with new task definition...
        )
        
        REM Note: This is simplified - would need proper service name matching
        echo [INFO] Use AWS Console or specific AWS CLI commands for ECS service restart
        echo [INFO] aws ecs update-service --cluster %CLUSTER_NAME% --service [SERVICE_NAME] --force-new-deployment
    ) else (
        echo [INFO] To restart all ECS services, use AWS Console or run:
        echo [INFO] for each service: aws ecs update-service --cluster %CLUSTER_NAME% --service [SERVICE_NAME] --force-new-deployment
    )
)

REM Lambda Functions
for /f "tokens=*" %%i in ('aws lambda list-functions --query "Functions[?starts_with(FunctionName, \`justenoughforagame\`)].FunctionName" --output text 2^>nul') do set LAMBDA_FUNCTIONS=%%i

if not "%LAMBDA_FUNCTIONS%"=="" (
    echo [INFO] Found Lambda functions
    echo [INFO] Lambda functions restart automatically on code updates
    echo [INFO] To update Lambda function code, use AWS Console or CLI deployment
)

echo.
echo [INFO] 📋 Manual steps for AWS restart:
echo [INFO] 1. ECS Services: Use force new deployment
echo [INFO] 2. Lambda Functions: Deploy new code versions
echo [INFO] 3. DynamoDB: No restart needed (managed service)
echo [INFO] 4. ElastiCache: Restart through AWS Console if needed

goto :eof

:wait_for_service
set SERVICE_NAME=%~1
set PLATFORM_TYPE=%~2
set /a MAX_ATTEMPTS=%TIMEOUT%/5
set ATTEMPT=1

echo [INFO] ⏳ Waiting for %SERVICE_NAME% to be healthy...

:wait_loop
set IS_HEALTHY=false

if "%PLATFORM_TYPE%"=="docker" (
    docker-compose ps %SERVICE_NAME% 2>nul | findstr /i "healthy Up" >nul
    if not errorlevel 1 set IS_HEALTHY=true
)

if "%PLATFORM_TYPE%"=="k8s" (
    kubectl get pods -l app=%SERVICE_NAME% -n game-namespace 2>nul | findstr /i "Running" >nul
    if not errorlevel 1 (
        REM Simplified health check for batch
        set IS_HEALTHY=true
    )
)

if "%IS_HEALTHY%"=="true" (
    echo [INFO] ✅ %SERVICE_NAME% is healthy!
    goto :eof
)

echo [DEBUG] 🔄 Attempt %ATTEMPT%/%MAX_ATTEMPTS% - %SERVICE_NAME% not ready yet...
timeout /t 5 >nul
set /a ATTEMPT+=1
if %ATTEMPT% leq %MAX_ATTEMPTS% goto :wait_loop

echo [WARN] ⚠️  %SERVICE_NAME% failed to become healthy within %TIMEOUT%s
goto :eof
