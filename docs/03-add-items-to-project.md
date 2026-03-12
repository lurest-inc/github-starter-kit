# ③ Issue/PR 一括紐付け

リポジトリの Issue/PR を Project に一括追加します。

## 使い方

1. `Actions` タブを開く
2. `③ Issue/PR 一括紐付け` を選択
3. `Run workflow` をクリック
4. パラメータを入力して実行

## パラメータ

| パラメータ | 説明 | 必須 | 例 |
|------------|------|:----:|-----|
| `project_number` | 対象 Project の Number | ✅ | `1` |
| `target_repo` | 対象リポジトリ（owner/repo 形式） | ✅ | `myorg/myrepo` |
| `include_issues` | Issue を追加対象にする | ✅ | `true`（デフォルト） |
| `include_prs` | Pull Request を追加対象にする | ✅ | `true`（デフォルト） |
| `item_state` | 取得するアイテムの状態 | - | `open`（デフォルト） |
| `item_label` | 絞り込みラベル（指定ラベルのみ追加） | - | `bug` |

> **Note:** 既に Project に追加済みのアイテムは自動的にスキップされます。

## ワークフロー構成

```
03-add-items-to-project.yml
  └── add-items ジョブ
      └── scripts/add-items-to-project.sh    # アイテム一括追加
```

## スクリプト詳細

### add-items-to-project.sh

リポジトリの Issue/PR を Project に一括追加します。

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 操作権限が必要） | ✅ |
| `PROJECT_OWNER` | Project の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 Project の Number（数値） | ✅ |
| `TARGET_REPO` | 対象リポジトリ（owner/repo 形式） | ✅ |
| `INCLUDE_ISSUES` | Issue を追加対象にする（`true`/`false`） | ❌（デフォルト: `true`） |
| `INCLUDE_PRS` | PR を追加対象にする（`true`/`false`） | ❌（デフォルト: `true`） |
| `ITEM_STATE` | 取得するアイテムの状態（`open`/`closed`/`all`） | ❌（デフォルト: `open`） |
| `ITEM_LABEL` | 絞り込みラベル | ❌ |

> **Note:** 既に Project に追加済みのアイテムは自動的にスキップされます。
