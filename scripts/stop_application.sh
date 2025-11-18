#!/bin/bash
set -e

echo "Stopping application..."

cd /home/ec2-user/app

# Docker Composeで起動中のコンテナを停止
if [ -f docker-compose.yml ]; then
    docker-compose down || true
fi

echo "Application stopped."
