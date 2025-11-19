#!/bin/bash
set -e

echo "Running after install tasks..."

cd /home/ec2-user/app

# .envファイルが存在しない場合は作成
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "Created .env file from .env.example"
    else
        echo ".env.example not found, skipping .env creation"
    fi
fi

# 古いDockerイメージのクリーンアップ
docker system prune -af --volumes || true

echo "After install tasks completed."
