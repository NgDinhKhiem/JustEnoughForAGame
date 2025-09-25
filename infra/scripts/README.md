# JustEnoughForAGame Infrastructure Management Scripts

This directory contains comprehensive infrastructure management scripts for the JustEnoughForAGame project, supporting multiple platforms and operating systems.

## Directory Structure

```
scripts/
├── unix/           # Mac/Linux shell scripts
│   ├── start.sh    # Start infrastructure services
│   ├── stop.sh     # Stop infrastructure services
│   ├── check.sh    # Health checks and monitoring
│   ├── cleanup.sh  # Resource cleanup
│   ├── status.sh   # Service status display
│   ├── logs.sh     # Log viewing and management
│   └── restart.sh  # Service restart with health checks
├── windows/        # Windows batch scripts
│   ├── start.bat   # Start infrastructure services
│   ├── stop.bat    # Stop infrastructure services
│   ├── check.bat   # Health checks and monitoring
│   ├── cleanup.bat # Resource cleanup
│   ├── status.bat  # Service status display
│   ├── logs.bat    # Log viewing and management
│   └── restart.bat # Service restart with health checks
└── README.md      # This documentation
```

## Supported Platforms

All scripts support multiple deployment platforms:

- **Docker** - Local development with Docker Compose
- **Kubernetes** - Container orchestration 
- **AWS** - Cloud deployment with CloudFormation, ECS, Lambda

## Quick Start

### Mac/Linux
```bash
# Make scripts executable (if not already)
chmod +x unix/*.sh

# Start local development environment
./unix/start.sh

# Check service health
./unix/check.sh

# View service status
./unix/status.sh

# Stop all services
./unix/stop.sh
```

### Windows
```cmd
# Start local development environment
windows\start.bat

# Check service health  
windows\check.bat

# View service status
windows\status.bat

# Stop all services
windows\stop.bat
```

## Script Documentation

### start.sh / start.bat
Start infrastructure services with comprehensive platform support.

**Usage:**
```bash
# Unix
./start.sh [OPTIONS]

# Windows  
start.bat [OPTIONS]
```

**Options:**
- `-e, --environment` - Environment (local|dev|staging|prod) [default: local]
- `-p, --platform` - Platform (docker|k8s|aws) [default: docker]  
- `-s, --services` - Specific services to start (comma-separated)
- `-m, --monitoring` - Include monitoring stack [default: false]
- `--no-wait` - Don't wait for services to be healthy

**Examples:**
```bash
./start.sh                              # Start local Docker environment
./start.sh -e dev -p k8s                # Start dev environment on Kubernetes
./start.sh -s redis,postgres            # Start only Redis and PostgreSQL
./start.sh -m                           # Start with monitoring (Prometheus, Grafana)
```

### stop.sh / stop.bat
Stop infrastructure services with cleanup options.

**Usage:**
```bash
./stop.sh [OPTIONS]
```

**Options:**
- `-p, --platform` - Platform to stop (docker|k8s|aws) [default: docker]
- `-v, --volumes` - Remove volumes (docker only) [default: false]
- `-n, --networks` - Remove networks (docker only) [default: false]
- `-f, --force` - Force stop without confirmation [default: false]

**Examples:**
```bash
./stop.sh                               # Stop Docker services
./stop.sh -v -n                        # Stop and clean volumes/networks
./stop.sh -p k8s -f                    # Force stop Kubernetes services
```

### check.sh / check.bat
Perform comprehensive health checks across all platforms.

**Usage:**
```bash
./check.sh [OPTIONS]
```

**Options:**
- `-p, --platform` - Platform to check (docker|k8s|aws|all) [default: docker]
- `-s, --services` - Specific services to check
- `-d, --detailed` - Show detailed output
- `-w, --watch` - Continuous monitoring mode
- `-i, --interval` - Watch interval in seconds [default: 5]

**Examples:**
```bash
./check.sh                              # Check Docker services
./check.sh -p all -d                   # Detailed check of all platforms
./check.sh -w -i 10                    # Watch mode with 10s intervals
```

### cleanup.sh / cleanup.bat
Comprehensive cleanup of infrastructure resources.

**Usage:**
```bash
./cleanup.sh [OPTIONS]
```

**Options:**
- `-p, --platform` - Platform to cleanup (docker|k8s|aws|all) [default: docker]
- `-t, --type` - Cleanup type (containers|volumes|networks|images|all) [default: containers]
- `-f, --force` - Force cleanup without confirmation
- `-d, --dry-run` - Show what would be cleaned without doing it
- `--deep` - Perform deep cleanup (unused resources)
- `--logs` - Clean up log files

**Examples:**
```bash
./cleanup.sh                           # Clean Docker containers
./cleanup.sh -t all -f                 # Force clean all Docker resources
./cleanup.sh --dry-run                 # Preview cleanup actions
```

### status.sh / status.bat
Display comprehensive infrastructure status.

**Usage:**
```bash
./status.sh [OPTIONS]
```

**Options:**
- `-p, --platform` - Platform to check (docker|k8s|aws|all) [default: all]
- `-f, --format` - Output format (table|json|yaml) [default: table]
- `-w, --watch` - Continuous monitoring mode
- `-i, --interval` - Watch interval in seconds [default: 5]

**Examples:**
```bash
./status.sh                            # Show status of all platforms
./status.sh -p docker -f json         # Docker status in JSON format
./status.sh -w -i 10                  # Watch mode with 10s intervals
```

### logs.sh / logs.bat
View and manage logs from all infrastructure services.

**Usage:**
```bash
./logs.sh [OPTIONS] [SERVICE]
```

**Options:**
- `-p, --platform` - Platform (docker|k8s|aws) [default: docker]
- `-f, --follow` - Follow log output
- `-t, --tail` - Number of lines to show [default: 100]
- `-s, --since` - Show logs since timestamp (e.g., '2h', '30m')
- `-l, --level` - Log level filter (error|warn|info|debug)
- `--grep` - Filter logs with grep pattern
- `--export` - Export logs to file

**Examples:**
```bash
./logs.sh                              # Show all Docker service logs
./logs.sh redis                        # Show Redis logs
./logs.sh -f -t 50 postgres           # Follow PostgreSQL logs (50 lines)
./logs.sh --since '1h' --level error  # Error logs from last hour
```

### restart.sh / restart.bat
Gracefully restart services with health checks.

**Usage:**
```bash
./restart.sh [OPTIONS] [SERVICE]
```

**Options:**
- `-p, --platform` - Platform (docker|k8s|aws) [default: docker]
- `-e, --environment` - Environment (local|dev|staging|prod) [default: local]
- `-t, --timeout` - Health check timeout in seconds [default: 300]
- `-f, --force` - Force restart without graceful shutdown
- `-r, --rolling` - Rolling restart (K8s only)
- `--no-deps` - Don't restart dependencies (Docker only)

**Examples:**
```bash
./restart.sh                           # Restart all Docker services
./restart.sh redis                     # Restart only Redis service
./restart.sh -p k8s -r                 # Rolling restart on Kubernetes
```

## Environment-Specific Usage

### Local Development
```bash
# Start full local environment with monitoring
./start.sh -e local -m

# Check health of all services
./check.sh -p docker -d

# View logs with error filtering
./logs.sh --level error
```

### Kubernetes Deployment
```bash
# Deploy to Kubernetes
./start.sh -p k8s

# Check deployment status
./status.sh -p k8s

# Rolling restart
./restart.sh -p k8s -r
```

### AWS Production
```bash
# Deploy to AWS
./start.sh -p aws -e prod

# Check AWS services
./check.sh -p aws

# View CloudWatch logs
./logs.sh -p aws
```

## Service URLs (Local Development)

When running locally with Docker, the following services are available:

| Service | URL | Description |
|---------|-----|-------------|
| Redis Commander | http://localhost:8081 | Redis management UI |
| pgAdmin | http://localhost:8082 | PostgreSQL admin (admin@tictactoe.com / admin123) |
| Kafka UI | http://localhost:8080 | Kafka management UI |
| ClickHouse | http://localhost:8123 | ClickHouse database |
| LocalStack | http://localhost:4566 | AWS services simulation |
| DynamoDB Local | http://localhost:8000 | Local DynamoDB |
| Prometheus | http://localhost:9090 | Metrics collection (with -m flag) |
| Grafana | http://localhost:3000 | Metrics visualization (admin / admin123) |
| Jaeger | http://localhost:16686 | Distributed tracing (with -m flag) |

## Prerequisites

### All Platforms
- Git
- curl or wget

### Docker Platform
- Docker
- Docker Compose

### Kubernetes Platform
- kubectl configured with cluster access
- Kubernetes cluster (local or remote)

### AWS Platform
- AWS CLI configured with credentials
- Appropriate IAM permissions for CloudFormation, ECS, Lambda, etc.

## Troubleshooting

### Common Issues

**Docker services won't start:**
```bash
# Check Docker is running
docker info

# Check for port conflicts
./check.sh -p docker -d

# Clean up and restart
./cleanup.sh -f
./start.sh
```

**Kubernetes deployment fails:**
```bash
# Check cluster connectivity
kubectl cluster-info

# Check namespace
kubectl get namespace game-namespace

# View pod logs
./logs.sh -p k8s
```

**Health checks failing:**
```bash
# Run detailed health check
./check.sh -d

# Check service logs
./logs.sh [service-name]

# Restart problematic service
./restart.sh [service-name]
```

### Getting Help

For detailed help on any script:
```bash
# Unix
./script-name.sh --help

# Windows
script-name.bat --help
```

## Development

These scripts are designed to be:
- **Cross-platform** - Same functionality on Unix and Windows
- **Comprehensive** - Support all deployment scenarios
- **User-friendly** - Clear output, helpful error messages
- **Robust** - Error handling and graceful degradation
- **Extensible** - Easy to add new platforms or services

For modifications or additions, maintain consistency across both Unix and Windows versions.
