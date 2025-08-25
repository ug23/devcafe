# AWS EC2 Spot Instance Development Environment

セキュアで自動管理されるAWS EC2スポットインスタンス開発環境をTerraformで構築するプロジェクトです。公開GitHubリポジトリでの管理を前提に、セキュリティを最優先に設計されています。

## 📋 概要

このプロジェクトは、コスト効率の高いEC2スポットインスタンスを使用して、一時的な開発環境を簡単に構築・管理できるTerraform構成を提供します。

### 主な機能

- 🚀 **c7g.4xlarge** (ARM Graviton3) スポットインスタンスの自動プロビジョニング
- 🐳 **Docker & Docker Compose** の自動インストール
- 🔐 **GitHub認証** の自動設定とリポジトリクローン
- ⏰ **自動削除機能** - 指定時間後に自動的にリソースを削除（デフォルト4時間）
- 🖥️ **IntelliJ Gateway** 対応 - リモート開発環境として利用可能
- 🔒 **セキュリティ重視** - 機密情報の安全な管理

## 🔧 前提条件

以下のツールがローカル環境にインストールされている必要があります：

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

4. **AWS アカウント設定**
   - AWSアカウントとIAMユーザー
   - EC2、VPC、Lambda等の必要な権限
   - 東京リージョン（ap-northeast-1）にSSHキーペアを作成済み

## 🚀 クイックスタート

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

### 3. 必須設定の編集
`.env`ファイルを編集し、最低限以下を設定：
```bash
TF_VAR_ssh_key_name=your-aws-key-name  # AWSに登録済みのSSHキー名（必須）
```

### 4. 環境の起動
```bash
./scripts/start.sh
```

### 5. インスタンスへの接続
起動完了後、表示されるSSHコマンドで接続：
```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<public-ip>
```

## 📝 詳細設定

### AWS認証設定

以下のいずれかの方法でAWS認証を設定してください：

#### 方法1: AWS CLIの設定（推奨）
```bash
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region: ap-northeast-1
# Default output format: json
```

#### 方法2: 環境変数の設定
`.env`ファイルに追加：
```bash
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_DEFAULT_REGION=ap-northeast-1
```

### GitHub Personal Access Token (PAT) の設定

GitHubリポジトリの自動クローンを利用する場合：

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

### SSH鍵の設定

1. AWS EC2コンソールで鍵ペアを作成（まだの場合）
2. ダウンロードした`.pem`ファイルを`~/.ssh/`に配置
3. 権限を設定：
```bash
chmod 400 ~/.ssh/your-key.pem
```
4. `.env`ファイルにキー名を設定（拡張子なし）：
```bash
TF_VAR_ssh_key_name=your-key-name
```

### カスタマイズ可能な設定

`terraform.tfvars`または`.env`で以下の設定をカスタマイズできます：

| 変数名 | デフォルト値 | 説明 |
|--------|------------|------|
| `project_name` | `spot-dev` | プロジェクト名（リソースの命名に使用） |
| `instance_type` | `c7g.4xlarge` | インスタンスタイプ |
| `spot_max_price` | `""` | スポット価格上限（空の場合オンデマンド価格） |
| `root_volume_size` | `100` | ルートボリュームサイズ（GB） |
| `auto_terminate_hours` | `4` | 自動削除までの時間（1-24時間） |
| `enable_jetbrains_gateway` | `true` | JetBrains Gateway用ポート開放 |

## 🎮 使用方法

### 環境の起動
```bash
./scripts/start.sh
```
- 環境変数のチェック
- Terraformの初期化と実行
- 接続情報の表示

### 環境への接続

#### SSH接続
```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<public-ip>
```

#### IntelliJ Gateway接続
1. IntelliJ IDEAでGatewayを開く
2. "New Connection"を選択
3. 以下の情報を入力：
   - Connection Type: SSH
   - Host: 表示されたPublic IP
   - Port: 22
   - Username: ubuntu
   - Authentication: Key pair
   - Private key: `~/.ssh/your-key.pem`のパス

### 自動削除時間の延長
デフォルトでは4時間後に自動削除されます。延長する場合：
```bash
./scripts/extend.sh 2  # 2時間延長
```

### 環境の削除
```bash
./scripts/stop.sh
```
すべてのリソースが完全に削除されます。

## 💰 コスト見積もり

c7g.4xlarge (東京リージョン) の参考価格：
- **オンデマンド**: 約$0.5-0.6/時間
- **スポット**: 約$0.15-0.25/時間（70%程度の削減）

月間使用例（1日8時間、週5日）：
- オンデマンド: 約$80-100
- スポット: 約$25-40

**注意**: 実際の価格は市場状況により変動します。最新の価格は[AWS EC2 Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)を確認してください。

## 🔧 トラブルシューティング

### スポットリクエストが満たされない
```bash
Error: waiting for EC2 Spot Instance Request to be fulfilled
```
**解決策**: 
- 別のアベイラビリティゾーンを試す
- `spot_max_price`を調整する
- オンデマンドインスタンスに切り替える

### SSH接続できない
**確認事項**:
1. セキュリティグループが現在のIPを許可しているか
2. SSHキーの権限が正しいか（400）
3. インスタンスが起動完了しているか

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

## 🔒 セキュリティ注意事項

### 絶対に公開してはいけないファイル

以下のファイルは`.gitignore`に含まれており、**絶対にコミットしないでください**：

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

3. **SSH鍵**
   - Ed25519またはRSA 4096ビット以上を使用
   - パスフレーズで保護
   - 定期的に更新

4. **ネットワークセキュリティ**
   - セキュリティグループは自分のIPのみ許可
   - 不要なポートは開放しない
   - VPCとサブネットを適切に設定

## 📂 プロジェクト構造

```
aws-spot-dev-env/
├── main.tf                 # Terraformメイン設定
├── variables.tf            # 変数定義
├── outputs.tf              # 出力定義
├── setup.sh                # EC2初期設定スクリプト
├── scripts/
│   ├── start.sh            # 環境起動スクリプト
│   ├── stop.sh             # 環境削除スクリプト
│   └── extend.sh           # 自動削除延長スクリプト
├── .gitignore              # Git除外設定
├── terraform.tfvars.example # Terraform変数サンプル
├── .env.example            # 環境変数サンプル
└── README.md               # このファイル
```

## 🤝 貢献

プルリクエストを歓迎します。大きな変更の場合は、まずissueを開いて変更内容を議論してください。

## 📄 ライセンス

[MIT License](LICENSE)

## 🙏 謝辞

このプロジェクトは以下の技術を使用しています：
- [Terraform](https://www.terraform.io/)
- [AWS](https://aws.amazon.com/)
- [Docker](https://www.docker.com/)
- [Ubuntu](https://ubuntu.com/)

## 📞 サポート

問題が発生した場合は、[Issues](https://github.com/your-username/your-repo/issues)でお知らせください。