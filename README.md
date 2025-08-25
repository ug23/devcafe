# devcafe

> Spin up disposable EC2 dev environments in minutes

カフェでコード書きたいけどローカルのリソースが足りない時に、サクッとEC2スポットインスタンスを立ち上げるTerraformプロジェクト。

## なぜ作ったか

「スタバでdocker buildすると辛い」問題を解決するため。
- ☕ カフェの弱いWiFiでもSSM接続なら快適
- 💻 c7g.4xlarge (16vCPU/32GB) が時間$0.15〜
- ⏰ 2時間で自動削除（延長可能）

## 必要なもの

```bash
# macOSの場合
brew install terraform awscli jq
brew install --cask session-manager-plugin
```

## 使い方

### 1分で起動

```bash
# クローン
git clone https://github.com/ug23/devcafe.git
cd devcafe

# 起動（設定不要、SSHキー不要）
./scripts/start.sh

# 接続
./scripts/connect.sh
sudo su - ubuntu
```

### IntelliJ Gatewayで接続

```bash
# ポートフォワーディング開始
./scripts/port-forward.sh 2222 22

# IntelliJ Gatewayで localhost:2222 に接続
```

### 時間延長・削除

```bash
# 2時間延長
./scripts/extend.sh 2

# 削除
./scripts/stop.sh
```

## 特徴

- **SSM接続** - SSHキー不要、IP制限なし
- **自動削除** - デフォルト2時間後（Lambda + CloudWatch Events）
- **GitHub連携** - リポジトリ自動クローン対応
- **Docker完備** - Docker/Docker Compose自動インストール
- **低コスト** - スポットインスタンスで70%削減

## 詳細ドキュメント

- [セットアップガイド](docs/setup.md) - AWS認証、GitHub PAT設定
- [SSM接続ガイド](docs/ssm-connection.md) - 接続方法、ポートフォワーディング
- [トラブルシューティング](docs/troubleshooting.md)
- [セキュリティ](docs/security.md)

## コスト

c7g.4xlarge (東京リージョン)
- オンデマンド: $0.5-0.6/時間
- **スポット: $0.15-0.25/時間** ← これを使用

カフェで2時間作業 = 約$0.30-0.50

## ライセンス

[MIT License](LICENSE) - Yuji Imagawa (@ug23)