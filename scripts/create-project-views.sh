#!/usr/bin/env bash
set -euo pipefail

# GitHub Project View 作成スクリプト
# 環境変数:
#   GH_TOKEN          - GitHub PAT（Projects 操作権限が必要）
#   PROJECT_OWNER     - Project の所有者
#   PROJECT_NUMBER    - 対象 Project の Number（数値）
#   VIEW_DEFINITIONS  - View 定義（JSON配列、省略時はデフォルト値を使用）
#                       例: [{"name":"Table","layout":"TABLE_LAYOUT"}]
#                       対応レイアウト: TABLE_LAYOUT, BOARD_LAYOUT, ROADMAP_LAYOUT

# --- ヘルパー関数 ---

# GitHub Actions ワークフローコマンドインジェクションを防ぐためのサニタイズ関数
sanitize_for_workflow_command() {
  local value="$1"
  value="${value//'%'/'%25'}"
  value="${value//$'\n'/'%0A'}"
  value="${value//$'\r'/'%0D'}"
  echo "${value}"
}

# --- バリデーション ---

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "::error::GH_TOKEN が設定されていません。Secrets に PROJECT_PAT を設定してください。"
  exit 1
fi

if [[ -z "${PROJECT_OWNER:-}" ]]; then
  echo "::error::PROJECT_OWNER が指定されていません。"
  exit 1
fi

if [[ -z "${PROJECT_NUMBER:-}" ]]; then
  echo "::error::PROJECT_NUMBER が指定されていません。"
  exit 1
fi

if ! [[ "${PROJECT_NUMBER}" =~ ^[0-9]+$ ]]; then
  SAFE_PROJECT_NUMBER=$(sanitize_for_workflow_command "${PROJECT_NUMBER}")
  echo "::error::PROJECT_NUMBER の値が不正です: ${SAFE_PROJECT_NUMBER}（数値のみを指定してください）"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "::error::jq がインストールされていません。JSON の解析に必要です。"
  exit 1
fi

# --- VIEW_DEFINITIONS のデフォルト値設定 ---

if [[ -z "${VIEW_DEFINITIONS:-}" ]]; then
  VIEW_DEFINITIONS='[
    {"name": "Table", "layout": "TABLE_LAYOUT"},
    {"name": "Board", "layout": "BOARD_LAYOUT"},
    {"name": "Roadmap", "layout": "ROADMAP_LAYOUT"}
  ]'
  echo "VIEW_DEFINITIONS が未指定のため、デフォルト値を使用します。"
fi

# VIEW_DEFINITIONS の JSON バリデーション
if ! echo "${VIEW_DEFINITIONS}" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1; then
  echo "::error::VIEW_DEFINITIONS が有効な JSON 配列ではありません。"
  exit 1
fi

# 各要素に必須フィールド（name, layout）が存在し、name が非空の文字列であるか確認
if ! echo "${VIEW_DEFINITIONS}" | jq -e 'all(has("name") and has("layout") and (.name | type == "string" and length > 0) and (.layout | type == "string"))' >/dev/null 2>&1; then
  echo "::error::VIEW_DEFINITIONS の各要素には name（非空の文字列）と layout が必須です。"
  exit 1
fi

# layout の値を検証
VALID_LAYOUTS='["TABLE_LAYOUT","BOARD_LAYOUT","ROADMAP_LAYOUT"]'
if ! echo "${VIEW_DEFINITIONS}" | jq -e --argjson valid "${VALID_LAYOUTS}" 'all(.layout as $l | $valid | index($l) != null)' >/dev/null 2>&1; then
  echo "::error::layout には TABLE_LAYOUT, BOARD_LAYOUT, ROADMAP_LAYOUT のいずれかを指定してください。"
  exit 1
fi

# --- オーナータイプ判定 ---

echo "オーナータイプを判定しています..."

if ! OWNER_INFO=$(gh api "users/${PROJECT_OWNER}" --jq '.type' 2>&1); then
  SAFE_OWNER_INFO=$(sanitize_for_workflow_command "${OWNER_INFO}")
  SAFE_PROJECT_OWNER=$(sanitize_for_workflow_command "${PROJECT_OWNER}")
  echo "::error::オーナー情報の取得に失敗しました: ${SAFE_OWNER_INFO}"
  echo "::error::PROJECT_OWNER=${SAFE_PROJECT_OWNER} が正しいか確認してください。"
  exit 1
fi

OWNER_TYPE="${OWNER_INFO}"
echo "  オーナータイプ: ${OWNER_TYPE}"

if [[ "${OWNER_TYPE}" == "User" ]]; then
  OWNER_QUERY_FIELD="user"
elif [[ "${OWNER_TYPE}" == "Organization" ]]; then
  OWNER_QUERY_FIELD="organization"
else
  SAFE_OWNER_TYPE=$(sanitize_for_workflow_command "${OWNER_TYPE}")
  echo "::error::不明なオーナータイプ: ${SAFE_OWNER_TYPE}"
  exit 1
fi

# --- 既存 View 情報の取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} の既存 View を取得しています..."

VIEW_QUERY=$(cat <<GRAPHQL
query {
  ${OWNER_QUERY_FIELD}(login: "${PROJECT_OWNER}") {
    projectV2(number: ${PROJECT_NUMBER}) {
      id
      views(first: 50) {
        nodes {
          id
          name
          layout
        }
      }
    }
  }
}
GRAPHQL
)

if ! VIEW_RESULT=$(gh api graphql -f query="${VIEW_QUERY}" 2>&1); then
  SAFE_RESULT=$(sanitize_for_workflow_command "${VIEW_RESULT}")
  echo "::error::Project 情報の取得に失敗しました: ${SAFE_RESULT}"
  echo ""
  echo "考えられる原因:"
  echo "  - PROJECT_NUMBER が正しくない"
  echo "  - PAT に Projects > Read and write 権限が付与されていない"
  echo "  - ネットワークエラー"
  exit 1
fi

# GraphQL 応答内の errors チェック
if echo "${VIEW_RESULT}" | jq -e '.errors and (.errors | length > 0)' >/dev/null 2>&1; then
  SAFE_RESULT=$(sanitize_for_workflow_command "${VIEW_RESULT}")
  echo "::error::Project 情報の取得中に GraphQL エラーが発生しました: ${SAFE_RESULT}"
  echo ""
  echo "GraphQL errors:"
  echo "${VIEW_RESULT}" | jq '.errors' || true
  exit 1
fi

# Project ID の取得
PROJECT_ID=$(echo "${VIEW_RESULT}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.id // empty")
if [[ -z "${PROJECT_ID}" ]]; then
  echo "::error::Project ID を取得できませんでした。Project #${PROJECT_NUMBER} が存在するか確認してください。"
  exit 1
fi
echo "  Project ID: ${PROJECT_ID}"

# 既存 View 名のリストを取得
EXISTING_VIEWS=$(echo "${VIEW_RESULT}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.views.nodes[].name // empty" 2>/dev/null)

echo ""
echo "既存の View:"
echo "${VIEW_RESULT}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.views.nodes[] | \"  - \(.name) (\(.layout))\"" 2>/dev/null || echo "  （取得できませんでした）"

# --- View の作成 ---

echo ""
echo "View を作成します..."

VIEW_COUNT=$(echo "${VIEW_DEFINITIONS}" | jq -r 'length')
CREATED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

for i in $(seq 0 $((VIEW_COUNT - 1))); do
  VIEW_NAME=$(echo "${VIEW_DEFINITIONS}" | jq -r ".[$i].name")
  VIEW_LAYOUT=$(echo "${VIEW_DEFINITIONS}" | jq -r ".[$i].layout")
  SAFE_VIEW_NAME=$(sanitize_for_workflow_command "${VIEW_NAME}")

  echo ""
  echo "[$((i + 1))/${VIEW_COUNT}] View: ${SAFE_VIEW_NAME} (${VIEW_LAYOUT})"

  # 既存 View の重複チェック（View 名は固定文字列として比較）
  if echo "${EXISTING_VIEWS}" | grep -Fqx "${VIEW_NAME}"; then
    echo "  ::notice::View '${SAFE_VIEW_NAME}' は既に存在するためスキップします。"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  # GraphQL mutation で View を作成
  CREATE_MUTATION=$(cat <<GRAPHQL
mutation {
  createProjectV2View(input: {
    projectId: "${PROJECT_ID}"
    name: "${VIEW_NAME}"
    layout: ${VIEW_LAYOUT}
  }) {
    projectV2View {
      id
      name
      layout
    }
  }
}
GRAPHQL
)

  if ! CREATE_RESULT=$(gh api graphql -f query="${CREATE_MUTATION}" 2>&1); then
    SAFE_RESULT=$(sanitize_for_workflow_command "${CREATE_RESULT}")
    echo "  ::error::View '${SAFE_VIEW_NAME}' の作成に失敗しました: ${SAFE_RESULT}"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi

  # GraphQL エラーチェック
  if echo "${CREATE_RESULT}" | jq -e '.errors and (.errors | length > 0)' >/dev/null 2>&1; then
    SAFE_ERRORS=$(sanitize_for_workflow_command "$(echo "${CREATE_RESULT}" | jq -c '.errors')")
    echo "  ::error::View '${SAFE_VIEW_NAME}' の作成中に GraphQL エラーが発生しました: ${SAFE_ERRORS}"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi

  CREATED_VIEW_ID=$(echo "${CREATE_RESULT}" | jq -r '.data.createProjectV2View.projectV2View.id // empty')
  echo "  ::notice::View '${SAFE_VIEW_NAME}' を作成しました。(ID: ${CREATED_VIEW_ID})"
  CREATED_COUNT=$((CREATED_COUNT + 1))
done

# --- サマリー出力 ---

echo ""
echo "========================================="
echo "  完了サマリー"
echo "========================================="
echo "  Owner:    ${PROJECT_OWNER}"
echo "  Project:  #${PROJECT_NUMBER}"
echo "  作成:     ${CREATED_COUNT} 件"
echo "  スキップ: ${SKIPPED_COUNT} 件（既存）"
echo "  失敗:     ${FAILED_COUNT} 件"
echo "========================================="

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## View 作成完了"
    echo ""
    echo "| 項目 | 値 |"
    echo "|------|-----|"
    echo "| Project Owner | \`${PROJECT_OWNER}\` |"
    echo "| Project Number | ${PROJECT_NUMBER} |"
    echo "| 作成 | ${CREATED_COUNT} 件 |"
    echo "| スキップ | ${SKIPPED_COUNT} 件（既存） |"
    echo "| 失敗 | ${FAILED_COUNT} 件 |"
    echo ""
    echo "### View 一覧"
    echo ""
    echo "| View 名 | レイアウト |"
    echo "|---------|-----------|"
    echo "${VIEW_DEFINITIONS}" | jq -r '.[] | "| \(.name) | \(.layout) |"'
  } >> "${GITHUB_STEP_SUMMARY}"
fi

if [[ "${FAILED_COUNT}" -gt 0 ]]; then
  echo ""
  echo "::error::${FAILED_COUNT} 件の View 作成に失敗しました。上記のエラーを確認してください。"
  exit 1
fi

echo ""
echo "セットアップが完了しました。"
