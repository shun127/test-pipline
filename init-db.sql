-- データベース初期化スクリプト

-- usersテーブル作成
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- サンプルデータ挿入
INSERT INTO users (name, email) VALUES
    ('太郎 山田', 'taro@example.com'),
    ('花子 佐藤', 'hanako@example.com'),
    ('次郎 鈴木', 'jiro@example.com')
ON CONFLICT (email) DO NOTHING;

-- インデックス作成
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
