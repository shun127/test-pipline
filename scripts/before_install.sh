#!/bin/bash
set -e

echo "Installing dependencies..."

# Dockerがインストールされているか確認
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Installing Docker..."
    sudo yum update -y
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ec2-user
fi

# Docker Composeがインストールされているか確認
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose is not installed. Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# CodeDeployエージェントの確認
if ! systemctl is-active --quiet codedeploy-agent; then
    echo "Starting CodeDeploy agent..."
    sudo systemctl start codedeploy-agent
fi

echo "Dependencies check completed."
