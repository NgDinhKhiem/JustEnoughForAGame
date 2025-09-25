#!/bin/bash

# TicTacToe Local Development Environment Shutdown Script

set -e

echo "🛑 Stopping TicTacToe Local Development Environment..."

# Stop all services
echo "⏹️  Stopping all services..."
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down

# Option to clean up volumes
read -p "🗑️  Do you want to remove all data volumes? (y/N): " remove_volumes

if [[ $remove_volumes =~ ^[Yy]$ ]]; then
    echo "🧹 Removing all volumes..."
    docker-compose -f docker-compose.yml -f docker-compose.dev.yml down -v
    
    # Remove any orphaned volumes
    docker volume prune -f
    
    echo "✅ All volumes removed!"
else
    echo "💾 Data volumes preserved for next startup"
fi

# Option to clean up networks
read -p "🌐 Do you want to remove networks? (y/N): " remove_networks

if [[ $remove_networks =~ ^[Yy]$ ]]; then
    echo "🧹 Removing networks..."
    docker network prune -f
    echo "✅ Networks cleaned!"
fi

echo ""
echo "✅ TicTacToe Development Environment stopped successfully!"
echo ""
echo "🚀 To start again: ./start-local.sh"
echo ""
