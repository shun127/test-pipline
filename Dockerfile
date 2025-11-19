FROM node:18-alpine

WORKDIR /app

# アプリケーションコードをコピー
COPY . .

# ポート公開
EXPOSE 3000

# アプリケーション起動
CMD ["node", "server.js"]
