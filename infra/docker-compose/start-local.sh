#!/bin/bash

# TicTacToe Local Development Environment Startup Script

set -e

echo "🎮 Starting TicTacToe Local Development Environment..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Function to wait for service to be healthy
wait_for_service() {
    local service_name=$1
    local max_attempts=30
    local attempt=1
    
    echo "⏳ Waiting for $service_name to be healthy..."
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose ps $service_name | grep -q "healthy\|Up"; then
            echo "✅ $service_name is ready!"
            return 0
        fi
        
        echo "🔄 Attempt $attempt/$max_attempts - $service_name not ready yet..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    echo "❌ $service_name failed to become healthy within expected time"
    return 1
}

# Create necessary directories
mkdir -p ./init-scripts/dev
mkdir -p ./clickhouse-config
mkdir -p ./prometheus
mkdir -p ./grafana/provisioning

# Start core infrastructure services first
echo "🚀 Starting core infrastructure services..."
docker-compose up -d redis postgres zookeeper kafka

# Wait for core services to be ready
wait_for_service "redis"
wait_for_service "postgres" 
wait_for_service "kafka"

# Start AWS simulation services
echo "🔧 Starting AWS simulation services..."
docker-compose up -d dynamodb-local localstack

wait_for_service "dynamodb-local"

# Start analytics and monitoring services
echo "📊 Starting analytics and monitoring services..."
docker-compose up -d clickhouse

# Start development tools
echo "🛠️  Starting development tools..."
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d \
    kafka-ui redis-commander pgadmin

# Optional: Start monitoring stack
read -p "🤔 Do you want to start monitoring stack (Prometheus, Grafana, Jaeger)? (y/N): " start_monitoring

if [[ $start_monitoring =~ ^[Yy]$ ]]; then
    echo "📈 Starting monitoring stack..."
    docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d \
        prometheus grafana jaeger
fi

echo ""
echo "🎉 TicTacToe Development Environment is ready!"
echo ""
echo "📋 Service URLs:"
echo "   🔴 Redis Commander:    http://localhost:8081"
echo "   🐘 pgAdmin:           http://localhost:8082 (admin@tictactoe.com / admin123)"
echo "   📨 Kafka UI:          http://localhost:8080"
echo "   🔍 ClickHouse:        http://localhost:8123"
echo "   🏠 LocalStack:        http://localhost:4566"
echo "   📊 DynamoDB Local:    http://localhost:8000"

if [[ $start_monitoring =~ ^[Yy]$ ]]; then
echo "   📈 Prometheus:        http://localhost:9090"
echo "   📊 Grafana:          http://localhost:3000 (admin / admin123)"
echo "   🔍 Jaeger:           http://localhost:16686"
fi

echo ""
echo "🛑 To stop all services: ./stop-local.sh"
echo "📝 To view logs: docker-compose logs -f [service-name]"
echo ""
