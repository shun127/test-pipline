#!/bin/bash
set -e

echo "Starting application..."

cd /home/ec2-user/app

# ECRからログイン（ECRを使用する場合）
# aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com

# Docker Composeでアプリケーションを起動
docker-compose pull
docker-compose up -d --build

# コンテナの起動を待機
echo "Waiting for containers to start..."
sleep 10

# コンテナの状態を確認
docker-compose ps

echo "Application started successfully."
