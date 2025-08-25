# SSM接続ガイド

## SSM接続の仕組み

**SSHキーは不要です！**

SSM (Systems Manager Session Manager) を使用して安全に接続します。
- IAMロールベースの認証
- セキュリティグループでのポート開放不要
- 公開IPアドレスへの直接アクセス不要
- カフェなどのIPが変わる場所からでも接続可能

## 基本的な接続方法

### SSMコンソール接続
```bash
# コンソール接続
./scripts/connect.sh

# ubuntuユーザーに切り替え
sudo su - ubuntu
```

## ポートフォワーディング

### SSHクライアント用
```bash
# SSHポートをローカルに転送（バックグラウンド実行）
./scripts/port-forward.sh 2222 22

# ローカルからSSH接続
ssh -p 2222 ubuntu@localhost

# ポートフォワーディングを停止
./scripts/stop-forward.sh
```

### IntelliJ Gateway接続
1. ポートフォワーディングを開始：
   ```bash
   ./scripts/port-forward.sh 2222 22
   ```
2. IntelliJ IDEAでGatewayを開く
3. "New Connection"を選択
4. 以下の情報を入力：
   - Connection Type: SSH
   - Host: **localhost**
   - Port: **2222**
   - Username: ubuntu
   - Authentication: Password/Key (任意)

## カスタムポートフォワーディング

任意のポートを転送できます：
```bash
# 例: Webアプリケーション（ポート3000）
./scripts/port-forward.sh 3000 3000

# 例: データベース（ポート5432）
./scripts/port-forward.sh 5432 5432
```