#!/bin/bash
set -e

echo "Running after install tasks..."

cd /home/ec2-user/app

# .envファイルが存在しない場合は作成
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env file from .env.example"
fi

# ファイルのパーミッション設定
chmod +x scripts/*.sh

# 古いDockerイメージのクリーンアップ
docker system prune -af --volumes || true

echo "After install tasks completed."
