# GitLab + AWS CodePipeline CI/CDパイプライン構築ガイド

## 📋 目次
1. [システム構成](#システム構成)
2. [デプロイフロー](#デプロイフロー)
3. [前提条件](#前提条件)
4. [AWS環境のセットアップ](#aws環境のセットアップ)
5. [EC2インスタンスのセットアップ](#ec2インスタンスのセットアップ)
6. [GitLabのセットアップ](#gitlabのセットアップ)
7. [AWS CodePipelineのセットアップ](#aws-codepipelineのセットアップ)
8. [デプロイ実行](#デプロイ実行)
9. [トラブルシューティング](#トラブルシューティング)

---

## システム構成

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   GitLab    │─────▶│ CodePipeline │─────▶│   EC2 +     │
│ Repository  │      │   + Build    │      │  Docker     │
└─────────────┘      │   + Deploy   │      │  Compose    │
                     └──────────────┘      └─────────────┘
```

### アプリケーション構成
- **Nginx**: リバースプロキシ (ポート80/443)
- **Node.js**: アプリケーションサーバー (ポート3000)
- **PostgreSQL**: データベース (ポート5432)

---

## デプロイフロー

### GitLab CI/CDを使用する場合
1. 開発者がコードをGitLabにプッシュ
2. GitLab Runnerがビルド・テストを実行
3. Dockerイメージをビルド
4. SSHでEC2に接続してdocker-composeでデプロイ

### AWS CodePipelineを使用する場合
1. 開発者がコードをGitLabにプッシュ
2. GitLabのWebhookがCodePipelineをトリガー
3. CodeBuildでDockerイメージをビルド
4. CodeDeployでEC2にデプロイ
5. EC2上でdocker-compose upを実行

---

## 前提条件

- AWSアカウント
- EC2インスタンスが起動済み
- GitLabアカウント（GitLab.comまたはセルフホスト）
- 基本的なAWS・Docker・Git知識

---

## AWS環境のセットアップ

### 1. IAMロールの作成

#### EC2用IAMロール
```bash
# ロール名: EC2-CodeDeploy-Role
# 必要なポリシー:
- AmazonEC2RoleforAWSCodeDeploy
- AmazonSSMManagedInstanceCore
- AmazonECRReadOnlyAccess (ECRを使用する場合)
```

#### CodeBuild用IAMロール
```bash
# ロール名: CodeBuild-Service-Role
# 必要なポリシー:
- AWSCodeBuildAdminAccess
- AmazonEC2ContainerRegistryPowerUser
- CloudWatchLogsFullAccess
```

#### CodePipeline用IAMロール
```bash
# ロール名: CodePipeline-Service-Role
# 必要なポリシー:
- AWSCodePipelineFullAccess
- AWSCodeBuildAdminAccess
- AWSCodeDeployFullAccess
```

### 2. ECRリポジトリの作成（オプション）

```bash
aws ecr create-repository \
  --repository-name sample-web-app \
  --region ap-northeast-1
```

### 3. S3バケットの作成

```bash
# CodePipelineのアーティファクト保存用
aws s3 mb s3://your-codepipeline-artifacts-bucket --region ap-northeast-1
```

---

## EC2インスタンスのセットアップ

### 1. EC2インスタンスの準備

```bash
# EC2にSSH接続
ssh -i your-key.pem ec2-user@your-ec2-ip

# システムアップデート
sudo yum update -y

# Dockerのインストール
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Docker Composeのインストール
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# ログアウトして再ログイン（グループ変更を反映）
exit
```

### 2. CodeDeployエージェントのインストール

```bash
# EC2に再接続
ssh -i your-key.pem ec2-user@your-ec2-ip

# CodeDeployエージェントのインストール
sudo yum install -y ruby wget
cd /tmp
wget https://aws-codedeploy-ap-northeast-1.s3.ap-northeast-1.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto

# エージェントの起動確認
sudo systemctl status codedeploy-agent
```

### 3. アプリケーションディレクトリの作成

```bash
sudo mkdir -p /home/ec2-user/app
sudo chown -R ec2-user:ec2-user /home/ec2-user/app
```

### 4. セキュリティグループの設定

以下のインバウンドルールを追加:
- SSH (22): 開発者のIPアドレス
- HTTP (80): 0.0.0.0/0
- HTTPS (443): 0.0.0.0/0

---

## GitLabのセットアップ

### 1. リポジトリの作成

GitLabで新しいリポジトリを作成し、このプロジェクトをプッシュ:

```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://gitlab.com/your-username/test-pipeline.git
git push -u origin main
```

### 2. GitLab CI/CD変数の設定

**Settings > CI/CD > Variables** で以下を追加:

| Variable | Value | Protected | Masked |
|----------|-------|-----------|--------|
| `SSH_PRIVATE_KEY` | EC2へのSSH秘密鍵 | ✓ | ✓ |
| `EC2_HOST` | EC2のIPアドレス | ✓ | - |
| `EC2_USER` | `ec2-user` | - | - |
| `DEPLOY_PATH` | `/home/ec2-user/app` | - | - |
| `DB_PASSWORD` | データベースパスワード | ✓ | ✓ |

### 3. GitLab Runner（オプション）

GitLab.comを使用する場合は共有ランナーを使用可能です。セルフホストの場合はランナーをインストール:

```bash
# GitLab Runnerのインストール (Ubuntu/Debian)
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install gitlab-runner

# Runnerの登録
sudo gitlab-runner register
```

---

## AWS CodePipelineのセットアップ

### 1. CodeDeployアプリケーションの作成

```bash
# アプリケーションの作成
aws deploy create-application \
  --application-name sample-web-app \
  --compute-platform Server \
  --region ap-northeast-1

# デプロイメントグループの作成
aws deploy create-deployment-group \
  --application-name sample-web-app \
  --deployment-group-name production \
  --service-role-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/CodeDeploy-Service-Role \
  --ec2-tag-filters Key=Name,Value=your-ec2-name,Type=KEY_AND_VALUE \
  --region ap-northeast-1
```

### 2. CodeBuildプロジェクトの作成

AWS ConsoleまたはCLIでCodeBuildプロジェクトを作成:

```yaml
Name: sample-web-app-build
Source: GitLab
Environment:
  - Image: aws/codebuild/standard:7.0
  - Privileged: true (Dockerビルド用)
  - Environment Variables:
    - AWS_ACCOUNT_ID
    - AWS_DEFAULT_REGION
    - IMAGE_REPO_NAME
Buildspec: buildspec.yml
```

### 3. CodePipelineの作成

**AWS Console > CodePipeline > Create pipeline**

#### Source Stage
- Source Provider: GitLab (Connection経由)
- Repository: your-username/test-pipeline
- Branch: main

#### Build Stage
- Build Provider: AWS CodeBuild
- Project Name: sample-web-app-build

#### Deploy Stage
- Deploy Provider: AWS CodeDeploy
- Application Name: sample-web-app
- Deployment Group: production

### 4. GitLabとAWSの連携設定

AWS ConsoleでGitLab Connectionを作成:
1. **Developer Tools > Connections**
2. **Create connection**
3. GitLabを選択
4. 認証情報を入力してConnection作成

---

## デプロイ実行

### GitLab CI/CDでデプロイ

```bash
# mainブランチにプッシュ
git add .
git commit -m "Deploy to production"
git push origin main

# GitLab CI/CD > Pipelines でステータス確認
```

### CodePipelineでデプロイ

```bash
# mainブランチにプッシュすると自動的にパイプラインが実行される
git push origin main

# AWS Console > CodePipeline でステータス確認
```

### 手動デプロイ（ローカルテスト用）

```bash
# EC2にSSH接続
ssh -i your-key.pem ec2-user@your-ec2-ip

# アプリケーションディレクトリに移動
cd /home/ec2-user/app

# Docker Composeで起動
docker-compose up -d

# ログ確認
docker-compose logs -f

# ヘルスチェック
curl http://localhost/health
```

---

## デプロイ後の確認

### 1. アプリケーションの動作確認

```bash
# ヘルスチェック
curl http://your-ec2-ip/health

# APIエンドポイント
curl http://your-ec2-ip/

# データベース接続テスト
curl http://your-ec2-ip/db-test

# ユーザー一覧取得
curl http://your-ec2-ip/users
```

### 2. コンテナの状態確認

```bash
# EC2にSSH接続
ssh -i your-key.pem ec2-user@your-ec2-ip

# コンテナ一覧
docker-compose ps

# ログ確認
docker-compose logs nginx
docker-compose logs app
docker-compose logs db
```

---

## トラブルシューティング

### CodeDeployエージェントが起動しない

```bash
# エージェントの状態確認
sudo systemctl status codedeploy-agent

# 再起動
sudo systemctl restart codedeploy-agent

# ログ確認
sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log
```

### Dockerコンテナが起動しない

```bash
# ログ確認
docker-compose logs

# コンテナの再起動
docker-compose down
docker-compose up -d

# Dockerディスクスペース確認
docker system df

# 不要なイメージ・コンテナの削除
docker system prune -af
```

### データベース接続エラー

```bash
# PostgreSQLコンテナのログ確認
docker-compose logs db

# データベース接続テスト
docker-compose exec db psql -U postgres -d sampledb

# ネットワーク確認
docker network ls
docker network inspect test-pipline_app-network
```

### ポート80にアクセスできない

```bash
# セキュリティグループの確認
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Nginxコンテナの状態確認
docker-compose ps nginx
docker-compose logs nginx

# ポート確認
sudo netstat -tlnp | grep :80
```

---

## 環境変数の管理

本番環境では、機密情報は以下のように管理してください:

### AWS Systems Manager Parameter Store

```bash
# パラメータの作成
aws ssm put-parameter \
  --name /production/db-password \
  --value "your-secure-password" \
  --type SecureString \
  --region ap-northeast-1

# パラメータの取得
aws ssm get-parameter \
  --name /production/db-password \
  --with-decryption \
  --region ap-northeast-1
```

### AWS Secrets Manager

```bash
# シークレットの作成
aws secretsmanager create-secret \
  --name production/app-secrets \
  --secret-string '{"DB_PASSWORD":"your-secure-password"}' \
  --region ap-northeast-1
```

---

## メンテナンス

### バックアップ

```bash
# データベースのバックアップ
docker-compose exec db pg_dump -U postgres sampledb > backup_$(date +%Y%m%d).sql

# ボリュームのバックアップ
docker run --rm -v test-pipline_postgres-data:/data -v $(pwd):/backup alpine tar czf /backup/db-backup.tar.gz /data
```

### ログローテーション

```bash
# Dockerログの設定（docker-compose.ymlに追加）
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

---

## まとめ

このガイドでは、GitLabとAWS CodePipelineを使用してEC2上にDocker Composeアプリケーションをデプロイするパイプラインを構築しました。

**主要なファイル:**
- `docker-compose.yml`: Docker構成
- `.gitlab-ci.yml`: GitLab CI/CD設定
- `buildspec.yml`: CodeBuild設定
- `appspec.yml`: CodeDeploy設定
- `scripts/`: デプロイスクリプト

デプロイ方法は2つから選択可能:
1. **GitLab CI/CD**: GitLab RunnerでビルドしSSHでデプロイ
2. **AWS CodePipeline**: フルマネージドなAWSサービスでデプロイ

どちらの方法でも、mainブランチへのプッシュで自動デプロイが実行されます。
