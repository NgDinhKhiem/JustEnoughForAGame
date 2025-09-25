# TicTacToe Infrastructure Deployment

This directory contains deployment configurations for the TicTacToe game infrastructure.

## Structure

```
deployment/
├── kubernetes/              # Kubernetes deployment configs
│   ├── namespace.yaml       # Namespace and RBAC
│   ├── configmap.yaml       # Configuration and secrets
│   ├── redis.yaml          # Redis deployment
│   ├── kafka.yaml          # Kafka and Zookeeper
│   ├── game-service.yaml   # Game service deployment
│   ├── lobby-service.yaml  # Lobby service deployment
│   └── ingress.yaml        # Ingress controller config
└── aws/                    # AWS deployment configs
    ├── cloudformation/     # CloudFormation templates
    │   └── infrastructure.yml
    └── deploy.sh           # AWS deployment script
```

## Deployment Options

### 1. Local Development (Docker Compose)
For local development and testing:

```bash
# Start local environment
cd ../docker-compose
./start-local.sh

# Stop local environment
./stop-local.sh
```

**Services Available:**
- Redis: `localhost:6379`
- Kafka: `localhost:9092`
- PostgreSQL: `localhost:5432`
- DynamoDB Local: `localhost:8000`
- Kafka UI: `http://localhost:8080`
- Redis Commander: `http://localhost:8081`
- pgAdmin: `http://localhost:8082`

### 2. Kubernetes Deployment
For containerized deployment on Kubernetes:

```bash
# Deploy to Kubernetes
kubectl apply -f kubernetes/

# Check deployment status
kubectl get all -n tictactoe

# Access services
kubectl port-forward -n tictactoe svc/game-service 8080:8080
```

**Prerequisites:**
- Kubernetes cluster (minikube, EKS, GKE, AKS)
- kubectl configured
- NGINX Ingress Controller (optional)

### 3. AWS Cloud Deployment
For production deployment on AWS:

```bash
# Deploy infrastructure
cd aws
./deploy.sh --environment prod --region us-east-1

# Deploy with custom settings
./deploy.sh -e staging -r us-west-2 -p my-tictactoe
```

**AWS Services Used:**
- **ECS Fargate**: Game and Lobby services (real-time WebSocket)
- **Lambda**: Auth, User, Leaderboard, Analytics services
- **DynamoDB**: User data and leaderboard storage
- **ElastiCache Redis**: Session storage and game state
- **Application Load Balancer**: Traffic routing
- **VPC**: Network isolation and security

## Service Architecture

### Lambda Services (Serverless)
- **auth-service**: JWT authentication, session management
- **user-service**: User profiles, stats, rewards
- **leaderboard-service**: Rankings and score aggregation
- **analytics-service**: Event processing and insights

### ECS Fargate Services (Container)
- **game-service**: Real-time TicTacToe game engine
- **lobby-service**: Matchmaking and room management

### Infrastructure Services
- **Redis**: Session storage, game state caching, pub/sub
- **DynamoDB**: User profiles, leaderboard data
- **Kafka**: Event streaming (local/K8s only)

## Configuration

### Environment Variables
Key configuration for all environments:

```bash
# Database
REDIS_HOST=redis-service
REDIS_PORT=6379
POSTGRES_HOST=postgres-service  # K8s only
POSTGRES_PORT=5432

# AWS Services
DYNAMODB_USERS_TABLE=tictactoe-prod-users
DYNAMODB_LEADERBOARD_TABLE=tictactoe-prod-leaderboard
REDIS_CLUSTER_ENDPOINT=tictactoe-prod-redis.xxxxx.cache.amazonaws.com

# Application
JWT_SECRET=your-jwt-secret-key
GAME_SESSION_TIMEOUT=300
MAX_CONCURRENT_GAMES=1000
```

### Security Considerations

1. **Network Security**:
   - Private subnets for backend services
   - Security groups with minimal required access
   - VPC endpoints for AWS services

2. **Data Security**:
   - DynamoDB encryption at rest
   - Redis encryption in transit and at rest
   - JWT token-based authentication

3. **Access Control**:
   - IAM roles with least privilege
   - Service-to-service authentication
   - API rate limiting

## Monitoring and Logging

### Local Development
- **Prometheus**: `http://localhost:9090`
- **Grafana**: `http://localhost:3000`
- **Jaeger**: `http://localhost:16686`

### AWS Production
- **CloudWatch**: Metrics and logs
- **X-Ray**: Distributed tracing
- **AWS Config**: Compliance monitoring

## Scaling Configuration

### Auto Scaling
- **ECS Services**: CPU/Memory based scaling
- **Lambda**: Automatic concurrency scaling
- **DynamoDB**: On-demand billing mode
- **ElastiCache**: Multi-AZ with automatic failover

### Performance Targets
- **Game Response Time**: < 100ms
- **Lobby Matching**: < 2 seconds
- **Concurrent Games**: 1000+
- **Concurrent Users**: 10,000+

## Cost Optimization

### Development
- Use Docker Compose locally (free)
- Kubernetes on minikube (free)

### Production
- Lambda pay-per-use pricing
- ECS Fargate with SPOT instances
- DynamoDB on-demand pricing
- ElastiCache t3.micro instances

## Troubleshooting

### Common Issues

1. **Service Discovery**: Ensure proper DNS resolution
2. **Network Connectivity**: Check security groups and NACLs
3. **Resource Limits**: Monitor CPU/memory usage
4. **Database Connections**: Check connection pooling

### Debugging Commands

```bash
# Kubernetes
kubectl logs -n tictactoe deployment/game-service
kubectl describe pod -n tictactoe <pod-name>

# AWS
aws ecs describe-services --cluster tictactoe-prod-cluster
aws logs tail /aws/lambda/auth-service --follow

# Docker Compose
docker-compose logs -f game-service
docker-compose exec redis redis-cli
```

## Next Steps

1. **CI/CD Pipeline**: Set up automated deployments
2. **Blue/Green Deployment**: Zero-downtime updates
3. **Multi-Region**: Global deployment for low latency
4. **Disaster Recovery**: Backup and restore procedures
