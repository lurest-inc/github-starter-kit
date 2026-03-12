# ① GitHub Project 新規作成

新しい Project を作成し、カスタムフィールド・ステータスカラム・View を一括でセットアップします。

## 使い方

1. `Actions` タブを開く
2. `① GitHub Project 新規作成` を選択
3. `Run workflow` をクリック
4. パラメータを入力して実行

## パラメータ

| パラメータ | 説明 | 必須 | 例 |
|------------|------|:----:|-----|
| `project_title` | Project のタイトル | ✅ | `My Project Board` |
| `visibility` | Project の公開範囲 | ✅ | `PRIVATE`（デフォルト） / `PUBLIC` |

> **Note:** Project の Owner はリポジトリの Owner から自動取得されます。
> カスタムフィールド・ステータスカラム・View の定義は各スクリプト内に固定されています。カスタマイズする場合はスクリプトを直接編集してください。
