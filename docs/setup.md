# セットアップガイド

## AWS認証設定

### 方法1: AWS CLIの設定（推奨）
```bash
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region: ap-northeast-1
# Default output format: json
```

### 方法2: 環境変数の設定
`.env`ファイルに追加：
```bash
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_DEFAULT_REGION=ap-northeast-1
```

## GitHub Personal Access Token (PAT) の設定

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

## カスタマイズ可能な設定

`terraform.tfvars`または`.env`で以下の設定をカスタマイズできます。

| 変数名 | デフォルト値 | 説明 |
|--------|------------|------|
| `project_name` | `spot-dev` | プロジェクト名（リソースの命名に使用） |
| `instance_type` | `c7g.4xlarge` | インスタンスタイプ |
| `spot_max_price` | `""` | スポット価格上限（空の場合オンデマンド価格） |
| `root_volume_size` | `100` | ルートボリュームサイズ（GB） |
| `auto_terminate_hours` | `2` | 自動削除までの時間（1-24時間） |
| `enable_jetbrains_gateway` | `true` | JetBrains Gateway用設定 |