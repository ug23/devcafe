# トラブルシューティング

## スポットリクエストが満たされない
```bash
Error: waiting for EC2 Spot Instance Request to be fulfilled
```
**解決策**: 
- 別のアベイラビリティゾーンを試す
- `spot_max_price`を調整する
- オンデマンドインスタンスに切り替える

## SSM接続できない
**確認事項**:
1. Session Manager Pluginがインストールされているか
2. AWS CLIの認証が正しく設定されているか
3. インスタンスが起動完了しているか
4. SSMエージェントが正常に動作しているか（`setup.sh`のログを確認）

## 自動削除が機能しない
**確認事項**:
1. CloudWatch EventsとLambdaが正しく設定されているか
2. `terraform output auto_terminate_time`で時刻を確認
3. `./scripts/extend.sh`で手動延長

## GitHub認証エラー
**確認事項**:
1. PATの有効期限
2. 必要なスコープが付与されているか
3. リポジトリURLが正しいか

## ポートフォワーディングが動作しない
**確認事項**:
1. 既に同じポートで実行中でないか確認
   ```bash
   lsof -i :2222  # ポート2222の例
   ```
2. プロセスが正常に起動しているか
   ```bash
   ps aux | grep port-forward
   ```
3. ログファイルを確認
   ```bash
   cat .port-forward.log
   ```