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

## ワークフロー構成

```
01-create-project.yml
  ├── create-project ジョブ
  │   └── scripts/setup-github-project.sh   # Project 作成
  └── extend-project ジョブ（_reusable-extend-project.yml）
      ├── scripts/setup-project-fields.sh    # カスタムフィールド作成
      ├── scripts/setup-status-columns.sh    # ステータスカラム設定
      └── scripts/create-project-views.sh    # View 作成
```

## スクリプト詳細

### setup-github-project.sh

Project を新規作成します。

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 操作権限が必要） | ✅ |
| `PROJECT_OWNER` | Project の所有者 | ✅ |
| `PROJECT_TITLE` | 作成する Project のタイトル | ✅ |
| `PROJECT_VISIBILITY` | Project の公開範囲（`PUBLIC` / `PRIVATE`） | ❌（デフォルト: `PRIVATE`） |

### setup-project-fields.sh

Project にカスタムフィールドを自動作成します。

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 操作権限が必要） | ✅ |
| `PROJECT_OWNER` | Project の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 Project の Number（数値） | ✅ |

**作成されるフィールド:**

| フィールド名 | データ型 | 選択肢 |
|-------------|---------|--------|
| Priority | SINGLE_SELECT | P0, P1, P2, P3 |
| Estimate | SINGLE_SELECT | XS, S, M, L, XL |
| Category | SINGLE_SELECT | Bug, Feature, Chore, Spike |
| Due Date | DATE | - |

> **Note:** 既に同名のフィールドが存在する場合は自動的にスキップされます。

### setup-status-columns.sh

Project の Status カラムを設定します。

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 操作権限が必要） | ✅ |
| `PROJECT_OWNER` | Project の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 Project の Number（数値） | ✅ |

**設定されるステータスカラム:**

| カラム名 | カラー | 説明 |
|---------|--------|------|
| Todo | BLUE | 未着手 |
| In Progress | YELLOW | 作業中 |
| Done | GREEN | 完了 |

### create-project-views.sh

Project に View を自動作成します。

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 操作権限が必要） | ✅ |
| `PROJECT_OWNER` | Project の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 Project の Number（数値） | ✅ |

**作成される View:**

- `Table`（TABLE_LAYOUT）
- `Board`（BOARD_LAYOUT）
- `Roadmap`（ROADMAP_LAYOUT）

> **Note:** 既に同名の View が存在する場合は自動的にスキップされます。
