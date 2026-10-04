#!/bin/bash
set -euo pipefail

# リポジトリルートへ移動
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== validate-skill.sh テストスイート実行開始 ==="

PASSED=0
FAILED=0

assert_exit_code() {
  local expected="$1"
  shift
  local test_name="$1"
  shift
  local cmd=("$@")

  echo "----------------------------------------"
  echo "[TEST] ${test_name}"
  echo "Command: ${cmd[*]} (期待終了コード: ${expected})"

  set +e
  "${cmd[@]}"
  local actual=$?
  set -e

  if [ "${actual}" -eq "${expected}" ]; then
    echo "[PASS] ${test_name} (期待値: ${expected}, 実際: ${actual})"
    PASSED=$((PASSED + 1))
  else
    echo "[FAIL] ${test_name} (期待値: ${expected}, 実際: ${actual})" >&2
    FAILED=$((FAILED + 1))
  fi
}

# 1. 正常系: valid fixture (終了コード 0)
assert_exit_code 0 "正常系: 適合するスキルモック" bash scripts/validate-skill.sh tests/fixtures/valid

# 2. 異常系: ディレクトリ名不一致 (終了コード 1)
assert_exit_code 1 "異常系: ディレクトリ名と name の不一致" bash scripts/validate-skill.sh tests/fixtures/bad-name

# 3. 異常系: CRLF 改行スクリプト混入 (終了コード 1)
assert_exit_code 1 "異常系: CRLF スクリプトの検出" bash scripts/validate-skill.sh tests/fixtures/crlf-script

# 4. 異常系: 不正なバージョン形式 (終了コード 1)
assert_exit_code 1 "異常系: semver 形式以外のバージョン" bash scripts/validate-skill.sh tests/fixtures/bad-version

echo "========================================"
echo "テスト結果サマリ: 合格 ${PASSED} / 失敗 ${FAILED} (全 $((PASSED + FAILED)) 件)"
echo "========================================"

if [ "${FAILED}" -ne 0 ]; then
  echo "テストスイート失敗: ${FAILED} 件のテストが失敗しました" >&2
  exit 1
fi

echo "すべてのテストに合格しました"
exit 0
