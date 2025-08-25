# AWS EC2 Spot Instance Development Environment

セキュアで自動管理されるAWS EC2スポットインスタンス開発環境をTerraformにより構築するプロジェクトです。公開GitHubリポジトリでの管理を前提に、セキュリティを最優先に設計されています。

## 概要

このプロジェクトは、コスト効率の高いEC2スポットインスタンスを使用して、一時的な開発環境を簡単に構築・管理できるTerraform構成を提供します。

### 主な機能

- c7g.4xlarge (ARM Graviton3) スポットインスタンスの自動プロビジョニング
- SSM接続によるSSHキー不要の安全な接続（カフェなどからでも接続可能）
- Docker & Docker Composeの自動インストール
- GitHub認証の自動設定とリポジトリクローン
- 指定時間後の自動削除機能（デフォルト4時間）
- IntelliJ Gateway対応（SSMポートフォワーディング経由）
- セキュリティグループ不要、機密情報の安全な管理

## 前提条件

以下のツールがローカル環境にインストールされている必要があります。

1. **Terraform** (v1.0以上)
   ```bash
   brew install terraform  # macOS
   ```

2. **AWS CLI** (v2推奨)
   ```bash
   brew install awscli  # macOS
   ```

3. **jq** (JSONパーサー)
   ```bash
   brew install jq  # macOS
   ```

4. **AWS Session Manager Plugin** （SSM接続用）
   ```bash
   brew install --cask session-manager-plugin  # macOS
   # または https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
   ```

5. **AWS アカウント設定**
   - AWSアカウントとIAMユーザー
   - EC2、VPC、Lambda、SSM等の必要な権限
   - **SSHキーペアは不要** (SSM接続を使用)

※ Ubuntu 22.04 ARMにはSSMエージェントがプリインストールされています。

## クイックスタート

### 1. リポジトリのクローン
```bash
git clone <your-repository-url>
cd aws-spot-dev-env
```

### 2. 設定ファイルの準備
```bash
cp .env.example .env
cp terraform.tfvars.example terraform.tfvars
```

### 3. 設定（オプション）
SSM接続のため**必須設定はありません**。GitHub連携を利用する場合のみ`.env`を編集します。
```bash
TF_VAR_github_pat=ghp_xxxxxxxxxxxxxxxxxxxx  # GitHub Personal Access Token
TF_VAR_github_username=your-username
TF_VAR_github_repo_url=https://github.com/username/repo.git
```

### 4. 環境の起動
```bash
./scripts/start.sh
```

### 5. インスタンスへの接続
起動完了後、SSM経由で接続します。
```bash
./scripts/connect.sh
```

※ SSMセッションはrootユーザーで開始されるため、`ubuntu`ユーザーに切り替えます。
```bash
sudo su - ubuntu
```

## 詳細設定

### AWS認証設定

以下のいずれかの方法でAWS認証を設定してください。

#### 方法1: AWS CLIの設定（推奨）
```bash
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region: ap-northeast-1
# Default output format: json
```

#### 方法2: 環境変数の設定
`.env`ファイルに追加します。
```bash
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_DEFAULT_REGION=ap-northeast-1
```

### GitHub Personal Access Token (PAT) の設定

GitHubリポジトリの自動クローンを利用する場合の手順です。

1. [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens) にアクセス
2. "Generate new token (classic)" をクリック
3. 必要なスコープを選択：
   - `repo` - プライベートリポジトリの場合
   - `public_repo` - パブリックリポジトリのみの場合
4. トークンを生成し、`.env`ファイルに設定：
```bash
TF_VAR_github_pat=ghp_xxxxxxxxxxxxxxxxxxxx
TF_VAR_github_username=your-username
TF_VAR_github_email=your-email@example.com
TF_VAR_github_repo_url=https://github.com/username/repo.git
```

### SSM接続の仕組み

**SSHキーは不要です！**

SSM (Systems Manager Session Manager) を使用して安全に接続します。
- IAMロールベースの認証
- セキュリティグループでのポート開放不要
- 公開IPアドレスへの直接アクセス不要
- カフェなどのIPが変わる場所からでも接続可能

### カスタマイズ可能な設定

`terraform.tfvars`または`.env`で以下の設定をカスタマイズできます。

| 変数名 | デフォルト値 | 説明 |
|--------|------------|------|
| `project_name` | `spot-dev` | プロジェクト名（リソースの命名に使用） |
| `instance_type` | `c7g.4xlarge` | インスタンスタイプ |
| `spot_max_price` | `""` | スポット価格上限（空の場合オンデマンド価格） |
| `root_volume_size` | `100` | ルートボリュームサイズ（GB） |
| `auto_terminate_hours` | `4` | 自動削除までの時間（1-24時間） |
| `enable_jetbrains_gateway` | `true` | JetBrains Gateway用設定 (現在はSSMポートフォワーディングを使用) |

## 使用方法

### 環境の起動
```bash
./scripts/start.sh
```
- 環境変数のチェック
- Terraformの初期化と実行
- 接続情報の表示

### 環境への接続

#### SSM接続
```bash
# コンソール接続
./scripts/connect.sh

# ubuntuユーザーに切り替え
sudo su - ubuntu
```

#### ポートフォワーディング（SSHクライアント用）
```bash
# SSHポートをローカルに転送（バックグラウンド実行）
./scripts/port-forward.sh 2222 22

# ローカルからSSH接続
ssh -p 2222 ubuntu@localhost

# ポートフォワーディングを停止
./scripts/stop-forward.sh
```

#### IntelliJ Gateway接続
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

### 自動削除時間の延長
デフォルトでは4時間後に自動削除されます。延長する場合は次のコマンドを実行します。
```bash
./scripts/extend.sh 2  # 2時間延長
```

### 環境の削除
```bash
./scripts/stop.sh
```
すべてのリソースが削除されます。

## コスト見積もり

c7g.4xlarge (東京リージョン) の参考価格は以下のとおりです。
- オンデマンドは約$0.5-0.6/時間
- スポットは約$0.15-0.25/時間（70%程度の削減）

月間使用例（1日8時間、週5日）
- オンデマンドは約$80-100
- スポットは約$25-40

実際の価格は市場状況により変動します。最新の価格は[AWS EC2 Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)を確認してください。

## トラブルシューティング

### スポットリクエストが満たされない
```bash
Error: waiting for EC2 Spot Instance Request to be fulfilled
```
**解決策**: 
- 別のアベイラビリティゾーンを試す
- `spot_max_price`を調整する
- オンデマンドインスタンスに切り替える

### SSM接続できない
**確認事項**:
1. Session Manager Pluginがインストールされているか
2. AWS CLIの認証が正しく設定されているか
3. インスタンスが起動完了しているか
4. SSMエージェントが正常に動作しているか（`setup.sh`のログを確認）

### 自動削除が機能しない
**確認事項**:
1. CloudWatch EventsとLambdaが正しく設定されているか
2. `terraform output auto_terminate_time`で時刻を確認
3. `./scripts/extend.sh`で手動延長

### GitHub認証エラー
**確認事項**:
1. PATの有効期限
2. 必要なスコープが付与されているか
3. リポジトリURLが正しいか

## セキュリティ注意事項

### 絶対に公開してはいけないファイル

以下のファイルは`.gitignore`に含まれており、コミットしないように注意してください。

- `.env` - 環境変数（PAT、認証情報を含む）
- `terraform.tfvars` - Terraform変数（機密情報を含む）
- `*.tfstate` - Terraformステートファイル
- `.terraform/` - Terraformプロバイダー
- `*.pem`, `*.key` - SSH鍵
- `.git-credentials` - Git認証情報

### セキュリティベストプラクティス

1. **Personal Access Token (PAT)**
   - 最小限の権限のみ付与
   - 定期的にローテーション
   - 使用しない時は無効化

2. **AWS認証情報**
   - IAMユーザーには最小限の権限のみ付与
   - MFAを有効化
   - アクセスキーの定期的なローテーション

3. **SSM接続のメリット**
   - SSHキーの管理不要
   - セキュリティグループでのポート開放不要
   - セッションの監査ログがCloudTrailに記録

4. **ネットワークセキュリティ**
   - セキュリティグループはアウトバウンドのみ許可
   - インバウンドポートはすべてブロック
   - VPCとサブネットを適切に設定

## プロジェクト構造

```
aws-spot-dev-env/
├── main.tf                 # Terraformメイン設定
├── variables.tf            # 変数定義
├── outputs.tf              # 出力定義
├── setup.sh                # EC2初期設定スクリプト
├── scripts/
│   ├── start.sh            # 環境起動スクリプト
│   ├── stop.sh             # 環境削除スクリプト
│   ├── extend.sh           # 自動削除延長スクリプト
│   ├── connect.sh          # SSM接続スクリプト
│   ├── port-forward.sh     # ポートフォワーディング開始
│   └── stop-forward.sh     # ポートフォワーディング停止
├── .gitignore              # Git除外設定
├── terraform.tfvars.example # Terraform変数サンプル
├── .env.example            # 環境変数サンプル
└── README.md               # このファイル
```

## 貢献

プルリクエストを歓迎します。大きな変更の場合は、まずissueを開いて変更内容を議論してください。

## ライセンス

[MIT License](LICENSE)

## 謝辞

このプロジェクトは以下の技術を使用しています。
- [Terraform](https://www.terraform.io/)
- [AWS](https://aws.amazon.com/)
- [Docker](https://www.docker.com/)
- [Ubuntu](https://ubuntu.com/)

