FROM node:18-alpine

WORKDIR /app

# パッケージファイルをコピー
COPY package*.json ./

# 依存関係のインストール
RUN npm ci --only=production

# アプリケーションコードをコピー
COPY . .

# ポート公開
EXPOSE 3000

# アプリケーション起動
CMD ["npm", "start"]
