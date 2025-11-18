#!/bin/bash
set -e

echo "Validating service..."

cd /home/ec2-user/app

# コンテナが実行中か確認
if ! docker-compose ps | grep -q "Up"; then
    echo "ERROR: Containers are not running!"
    docker-compose logs
    exit 1
fi

# ヘルスチェック
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f http://localhost/health > /dev/null 2>&1; then
        echo "Service health check passed!"
        exit 0
    fi
    
    echo "Waiting for service to be ready... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

echo "ERROR: Service health check failed after $MAX_RETRIES retries!"
docker-compose logs
exit 1
