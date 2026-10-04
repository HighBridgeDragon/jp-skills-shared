#!/bin/bash
set -euo pipefail

# スクリプトおよびリポジトリのルートパスを特定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SYNC_FILES_DIR="$SHARED_ROOT/sync/files"

# デフォルト設定
DEFAULT_REPOS=("jp-law-skill" "jp-diet-minutes-skill" "jp-imperial-diet-minutes-skill" "jp-court-cases-skill")
OWNER="HighBridgeDragon"
BRANCH="shared-sync"
DRY_RUN=false
SRC_DIR=""
CUSTOM_REPOS=()

# ヘルプメッセージ
usage() {
  cat << 'EOF'
使用方法: sync.sh [options] [repo1 repo2 ...]

下流リポジトリに jp-skills-shared の共通設定およびドキュメント原本を同期します。

対象リポジトリ（既定）:
  - jp-law-skill
  - jp-diet-minutes-skill
  - jp-imperial-diet-minutes-skill
  - jp-court-cases-skill

オプション:
  --dry-run              差分表示のみを行い、ブランチ作成・コミット・プッシュ・PR作成を行いません
  --src-dir <dir>        指定したローカル作業ディレクトリ配下のリポジトリを使用 (例: c:/SRC, /c/SRC)
  --branch <name>        同期用作業ブランチ名 (デフォルト: shared-sync)
  --owner <name>         GitHub オーナー/組織名 (デフォルト: HighBridgeDragon)
  -h, --help             本ヘルプメッセージを表示

例:
  # 全リポジトリの差分を一時ディレクトリ clone + dry-run で確認
  bash sync/sync.sh --dry-run

  # ローカルの c:/SRC ディレクトリを使用して差分確認
  bash sync/sync.sh --dry-run --src-dir c:/SRC

  # 特定リポジトリのみを同期
  bash sync/sync.sh --dry-run jp-diet-minutes-skill
EOF
  exit 0
}

# 引数解析
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --src-dir|--local-dir)
      SRC_DIR="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --owner|--org)
      OWNER="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    -*)
      echo "不明なオプション: $1" >&2
      exit 1
      ;;
    *)
      CUSTOM_REPOS+=("$1")
      shift
      ;;
  esac
done

if [ ${#CUSTOM_REPOS[@]} -gt 0 ]; then
  TARGET_REPOS=("${CUSTOM_REPOS[@]}")
else
  TARGET_REPOS=("${DEFAULT_REPOS[@]}")
fi

# パス正規化（Windows / WSL / Git Bash 互換）
normalize_path() {
  local p="$1"
  if command -v wslpath >/dev/null 2>&1 && [[ "$p" =~ ^[A-Za-z]: ]]; then
    wslpath -u "$p"
  elif command -v cygpath >/dev/null 2>&1 && [[ "$p" =~ ^[A-Za-z]: ]]; then
    cygpath -u "$p"
  elif [[ "$p" =~ ^([A-Za-z]):[/\\](.*) ]]; then
    local drive="${BASH_REMATCH[1]}"
    drive="$(echo "$drive" | tr '[:upper:]' '[:lower:]')"
    local rest="${BASH_REMATCH[2]//\\//}"
    if [ -d "/mnt/$drive" ]; then
      echo "/mnt/$drive/$rest"
    else
      echo "/$drive/$rest"
    fi
  else
    echo "$p"
  fi
}

[ -n "$SRC_DIR" ] && SRC_DIR="$(normalize_path "$SRC_DIR")"

echo "=========================================================="
echo "jp-skills-shared 同期スクリプト開始"
echo "モード: $([ "$DRY_RUN" = true ] && echo "DRY-RUN (差分確認のみ)" || echo "APPLY (コミット・PR作成実行)")"
echo "対象リポジトリ: ${TARGET_REPOS[*]}"
echo "同期先ブランチ: $BRANCH"
echo "=========================================================="

# 一時ディレクトリ追跡（クリーンアップ用）
TEMP_DIRS=()
cleanup() {
  for td in "${TEMP_DIRS[@]}"; do
    if [ -d "$td" ]; then
      rm -rf "$td" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT

TOTAL_COUNT=0
DIFF_COUNT=0
SYNCED_COUNT=0

for repo in "${TARGET_REPOS[@]}"; do
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  repo_name="$repo"
  skill="${repo_name%-skill}"
  repo_full="${OWNER}/${repo_name}"

  echo ""
  echo ">>> [${TOTAL_COUNT}/${#TARGET_REPOS[@]}] 処理中: ${repo_name} (skill: ${skill})"

  # 作業ディレクトリの決定
  work_dir=""
  is_temp=false

  # 1. --src-dir で明示指定された場合
  if [ -n "$SRC_DIR" ]; then
    if [ -d "$SRC_DIR/$repo_name" ]; then
      work_dir="$SRC_DIR/$repo_name"
    else
      echo "ERROR: 指定されたディレクトリにリポジトリが見つかりません: $SRC_DIR/$repo_name" >&2
      continue
    fi
  # 2. 自動ローカル探索（親ディレクトリまたは既知のパス）
  elif [ -d "$SHARED_ROOT/../$repo_name/.git" ]; then
    work_dir="$(cd "$SHARED_ROOT/../$repo_name" && pwd)"
  elif [ -d "/mnt/c/SRC/$repo_name/.git" ]; then
    work_dir="/mnt/c/SRC/$repo_name"
  elif [ -d "/c/SRC/$repo_name/.git" ]; then
    work_dir="/c/SRC/$repo_name"
  elif [ -d "c:/SRC/$repo_name/.git" ]; then
    work_dir="c:/SRC/$repo_name"
  # 3. ローカルにない場合は一時ディレクトリに clone
  else
    temp_dir="$(mktemp -d -t "sync-${repo_name}-XXXXXX")"
    TEMP_DIRS+=("$temp_dir")
    is_temp=true
    echo "  リポジトリを一時ディレクトリに clone しています: https://github.com/${repo_full}.git"
    if ! git clone "https://github.com/${repo_full}.git" "$temp_dir" --quiet; then
      echo "ERROR: リポジトリの clone に失敗しました: ${repo_full}" >&2
      continue
    fi
    work_dir="$temp_dir"
  fi

  echo "  作業ディレクトリ: $work_dir"

  # dry-run 復元用に既存状態を記録（ローカルの場合）
  existed_gitattributes=false
  existed_markdownlint=false
  existed_dependabot=false
  existed_install=false
  [ -f "$work_dir/.gitattributes" ] && existed_gitattributes=true
  [ -f "$work_dir/.markdownlint.json" ] && existed_markdownlint=true
  [ -f "$work_dir/.github/dependabot.yml" ] && existed_dependabot=true
  [ -f "$work_dir/docs/install.md" ] && existed_install=true

  # 設定原本のコピーと展開
  mkdir -p "$work_dir/.github"
  mkdir -p "$work_dir/docs"

  cp "$SYNC_FILES_DIR/.gitattributes" "$work_dir/.gitattributes"
  cp "$SYNC_FILES_DIR/.markdownlint.json" "$work_dir/.markdownlint.json"
  cp "$SYNC_FILES_DIR/.github/dependabot.yml" "$work_dir/.github/dependabot.yml"

  # docs/install.md.tmpl の変数展開
  tmpl_file="$SYNC_FILES_DIR/docs/install.md.tmpl"
  dest_file="$work_dir/docs/install.md"

  if command -v envsubst >/dev/null 2>&1; then
    SKILL="$skill" REPO="$repo_full" envsubst '${SKILL} ${REPO}' < "$tmpl_file" > "$dest_file"
  else
    sed -e "s|\${SKILL}|${skill}|g" -e "s|\${REPO}|${repo_full}|g" "$tmpl_file" > "$dest_file"
  fi

  # 差分確認
  pushd "$work_dir" > /dev/null

  # 変更状態の取得（同期対象ファイルに限定）
  changed_files=$(git status --porcelain .gitattributes .markdownlint.json .github/dependabot.yml docs/install.md 2>/dev/null || true)

  if [ -z "$changed_files" ]; then
    echo "  [同期済み] 差分はありません。"
    SYNCED_COUNT=$((SYNCED_COUNT + 1))
    popd > /dev/null
    continue
  fi

  DIFF_COUNT=$((DIFF_COUNT + 1))
  echo "  [差分あり] 変更対象ファイル:"
  echo "$changed_files" | sed 's/^/    /'

  if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "  --- [DRY-RUN 差分出力: ${repo_name}] ---"
    for f in .gitattributes .markdownlint.json .github/dependabot.yml docs/install.md; do
      if [ -f "$f" ]; then
        if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
          git diff "$f" || true
        else
          echo "  新規ファイル: $f"
          git diff --no-index /dev/null "$f" || true
        fi
      fi
    done
    echo "  --- [DRY-RUN 終了] ---"

    # ローカル作業ツリーを元の状態に安全に戻す
    if [ "$is_temp" = false ]; then
      [ "$existed_gitattributes" = true ] && git checkout -- .gitattributes 2>/dev/null || rm -f .gitattributes
      [ "$existed_markdownlint" = true ] && git checkout -- .markdownlint.json 2>/dev/null || rm -f .markdownlint.json
      [ "$existed_dependabot" = true ] && git checkout -- .github/dependabot.yml 2>/dev/null || rm -f .github/dependabot.yml
      [ "$existed_install" = true ] && git checkout -- docs/install.md 2>/dev/null || rm -f docs/install.md
    fi
  else
    # 実際のコミットと PR 作成
    current_branch=$(git branch --show-current 2>/dev/null || echo "main")
    echo "  同期ブランチ作成: $BRANCH (from $current_branch)"
    git checkout -B "$BRANCH"

    git add .gitattributes .markdownlint.json .github/dependabot.yml docs/install.md
    commit_msg="chore: 同期設定および共通ドキュメントの更新"
    git commit -m "$commit_msg"

    echo "  リモートへプッシュ中: origin $BRANCH"
    git push -u origin "$BRANCH" --force

    # PR の存在確認
    existing_pr=$(gh pr list --repo "$repo_full" --head "$BRANCH" --json url -q '.[0].url' 2>/dev/null || true)
    if [ -n "$existing_pr" ]; then
      echo "  [PR] 既存の PR が更新されました: $existing_pr"
    else
      echo "  Pull Request を作成中..."
      pr_url=$(gh pr create \
        --repo "$repo_full" \
        --base main \
        --head "$BRANCH" \
        --title "chore: 同期設定および共通ドキュメントの更新" \
        --body "jp-skills-shared からの自動同期による設定・ドキュメント更新です。

- \`.gitattributes\` (LF 改行コード保護、zip 除外設定)
- \`.markdownlint.json\` (共通 Markdown リント設定)
- \`.github/dependabot.yml\` (GitHub Actions 週次定期更新)
- \`docs/install.md\` (共通クライアント導入ガイド原本からの展開)" 2>/dev/null || true)
      echo "  [PR作成完了] ${pr_url}"
    fi

    # 元のブランチに戻る
    if [ "$is_temp" = false ] && [ -n "$current_branch" ] && [ "$current_branch" != "$BRANCH" ]; then
      git checkout "$current_branch" --quiet 2>/dev/null || true
    fi
  fi

  popd > /dev/null
done

echo ""
echo "=========================================================="
echo "同期処理完了サマリ"
echo "総リポジトリ数: $TOTAL_COUNT"
echo "差分なし (同期済み): $SYNCED_COUNT"
echo "差分あり: $DIFF_COUNT"
echo "=========================================================="
