# jp-skills-shared

日本の公的データ、議会会議録、法令等を扱う各種 Agent Skills（`jp-*-skill`）リポジトリ群で共通利用される Reusable Workflows、Composite Actions、および同期設定ファイルの単一の情報源（SSOT: Single Source of Truth）です。

## 1. 概要と目的

本リポジトリは、以下のスキルリポジトリにおける CI/CD パイプライン、セキュリティガード、仕様適合性検証、および共通設定・ドキュメントを一元管理します。

- [`HighBridgeDragon/jp-law-skill`](https://github.com/HighBridgeDragon/jp-law-skill)
- [`HighBridgeDragon/jp-diet-minutes-skill`](https://github.com/HighBridgeDragon/jp-diet-minutes-skill)
- [`HighBridgeDragon/jp-imperial-diet-minutes-skill`](https://github.com/HighBridgeDragon/jp-imperial-diet-minutes-skill)
- [`HighBridgeDragon/jp-court-cases-skill`](https://github.com/HighBridgeDragon/jp-court-cases-skill)

### 主な役割
1. **パイプラインの共通化と軽量化**: 各下流リポジトリのワークフローを薄い呼び出し定義に集約し、重複した保守コストを削減します。
2. **サプライチェーン保護の一元適用**: Takumi Guard by GMO や Dependabot の週次更新を標準化し、npm・Action 依存の安全性を確保します。
3. **Agent Skills 仕様の厳格な検証**: `SKILL.md` の Frontmatter、バージョン命名規則、LF 改行コード等の品質基準を自動検証します。
4. **設定原本の同期と共通導入ガイド**: `.gitattributes`, `.markdownlint.json`, `dependabot.yml` を下流へ配信し、汎用クライアント導入ガイド（`docs/install-guide.md`）を一元提供します。

---

## 2. ディレクトリ構成

```text
jp-skills-shared/
├── .github/
│   ├── dependabot.yml                 # GitHub Actions 週次自動更新設定
│   └── workflows/
│       ├── ci.yml                     # 上流自身の自己検証 CI (単体テスト + self-validate)
│       ├── release.yml                # リリース公開時の可動メジャータグ (v1) 自動移動
│       ├── reusable-release.yml       # スキル仕様検証・zip作成・Release公開
│       ├── reusable-markdown-lint.yml # reviewdog による Markdown リント
│       ├── reusable-claude-review.yml # Claude Code PR 自動レビュー (Takumi Guard 適用)
│       └── reusable-claude.yml        # Claude Code 自動対話実行 (Takumi Guard 適用)
├── actions/
│   └── setup-takumi-guard/            # サプライチェーン保護用 Composite Action
│       └── action.yml
├── docs/
│   └── install-guide.md               # 各 AI クライアント対応共通導入ガイド（SSOT）
├── scripts/
│   ├── validate-skill.sh              # Agent Skills 仕様適合性検証スクリプト
│   └── skill-version.sh               # SKILL.md からの semver バージョン抽出スクリプト
├── sync/
│   ├── files/                         # 下流リポジトリへの同期原本ファイル群
│   │   ├── .gitattributes             # LF 改行保護 & zip 除外設定
│   │   ├── .markdownlint.json         # 共通 MarkdownLint ルール
│   │   └── .github/dependabot.yml     # Actions 週次更新設定
│   └── sync.sh                        # 下流リポジトリ一括同期スクリプト (gh CLI 利用)
├── templates/
│   └── release-notes.md.tmpl          # Reusable Release で使用する共通リリースノート原本
├── tests/
│   ├── fixtures/                      # 仕様適合性テスト用モック（正常系・異常系）
│   └── run.sh                         # スクリプト単体テストスイート
└── README.md
```

---

## 3. バージョニング契約

- **下流リポジトリの参照形式**:
  下流リポジトリは常に可動メジャータグ **`@v1`** を指定して Reusable Workflows を呼び出します。
  これにより、破壊的変更を伴わない修正や改善を自動的に受け取ることができます。
  ```yaml
  uses: HighBridgeDragon/jp-skills-shared/.github/workflows/reusable-release.yml@v1
  ```
- **タグの自動移動**:
  上流リポジトリで新しい GitHub Release（例: `v1.0.0`）が公開されると、`.github/workflows/release.yml` が自動的に `v1` タグを最新コミットへ付け替えて強制プッシュします。
- **内部検証時の Git ref**:
  Reusable Workflow の `shared-ref` input は既定値が `v1` です。上流リポジトリ自身の CI 検証でのみ、PR やコミット時点の SHA（`${{ github.sha }}`）を指定して自己検証（`self-validate`）を行います。

---

## 4. Reusable Workflows インターフェース契約と呼び出し例

### 4.1 Reusable Release (`reusable-release.yml`)

Agent Skills 仕様への適合性（`SKILL.md` の frontmatter、改行コード、命名規則等）を検証し、新バージョンが宣言された場合に LICENSE を同梱した zip アーカイブを作成して GitHub Release を公開します。

#### インターフェース定義
- **Workflow パス**: `HighBridgeDragon/jp-skills-shared/.github/workflows/reusable-release.yml@v1`
- **Inputs**:
  - `skill-dir` (string, **必須**): スキルのディレクトリ名（例: `jp-diet-minutes`）
  - `shared-ref` (string, 任意, デフォルト: `'v1'`): 参照する `jp-skills-shared` の Git ref
- **Outputs**:
  - `version`: 抽出された semver バージョン文字列（例: `1.0.0`）
  - `tag`: 作成されたタグ名（例: `v1.0.0`）
  - `released`: 新規リリースが公開されたか否か（`true` または `false`）
- **呼び出し元ジョブの必要権限 (`permissions`)**:
  - `contents: write` (Release およびタグ作成用)

#### 下流リポジトリでの記述例 (`.github/workflows/release.yml`)
```yaml
name: Release

on:
  push:
    branches: [main]
  pull_request:

permissions: {}

jobs:
  release:
    uses: HighBridgeDragon/jp-skills-shared/.github/workflows/reusable-release.yml@v1
    permissions:
      contents: write
    with:
      skill-dir: jp-diet-minutes
```

---

### 4.2 Reusable Markdown Lint (`reusable-markdown-lint.yml`)

下流リポジトリの Markdown ファイル（`**/*.md`）を `reviewdog/action-markdownlint` を用いて検証し、PR 差分上にインラインレビューコメントを投稿します。下流リポジトリの `.markdownlint.json` が適用されます。

#### インターフェース定義
- **Workflow パス**: `HighBridgeDragon/jp-skills-shared/.github/workflows/reusable-markdown-lint.yml@v1`
- **Inputs**: なし
- **Secrets**: なし (内部で `github.token` を自動使用)
- **呼び出し元ジョブの必要権限 (`permissions`)**:
  - `contents: read`
  - `pull-requests: write`

#### 下流リポジトリでの記述例 (`.github/workflows/markdown-lint.yml`)
```yaml
name: Markdown Lint

on:
  pull_request:

permissions: {}

jobs:
  lint:
    uses: HighBridgeDragon/jp-skills-shared/.github/workflows/reusable-markdown-lint.yml@v1
    permissions:
      contents: read
      pull-requests: write
```

---

### 4.3 Reusable Claude Code Review (`reusable-claude-review.yml`)

Pull Request に対して Claude Code Action を実行し、コード品質、セキュリティ、潜在バグ、規約準拠を自動レビューします。実行前に Takumi Guard を適用して npm パッケージのサプライチェーン攻撃を遮断します。

#### インターフェース定義
- **Workflow パス**: `HighBridgeDragon/jp-skills-shared/.github/workflows/reusable-claude-review.yml@v1`
- **Inputs**:
  - `shared-ref` (string, 任意, デフォルト: `'v1'`): 参照する `jp-skills-shared` の Git ref
- **Secrets**:
  - `CLAUDE_CODE_OAUTH_TOKEN` (**必須**): Claude Code Action 用 OAuth トークン
- **呼び出し元ジョブの必要権限 (`permissions`)**:
  - `contents: read`
  - `pull-requests: write`
  - `id-token: write` (OIDC 認証用)

#### 下流リポジトリでの記述例 (`.github/workflows/claude-code-review.yml`)
```yaml
name: Claude Code Review

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]

permissions: {}

jobs:
  review:
    uses: HighBridgeDragon/jp-skills-shared/.github/workflows/reusable-claude-review.yml@v1
    permissions:
      contents: read
      pull-requests: write
      id-token: write
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

---

### 4.4 Reusable Claude Code (`reusable-claude.yml`)

Issue や PR コメントに `@claude` が含まれた際に対話的に Claude Code を実行します。実行前に Takumi Guard を適用します。

#### インターフェース定義
- **Workflow パス**: `HighBridgeDragon/jp-skills-shared/.github/workflows/reusable-claude.yml@v1`
- **Inputs**:
  - `shared-ref` (string, 任意, デフォルト: `'v1'`): 参照する `jp-skills-shared` の Git ref
- **Secrets**:
  - `CLAUDE_CODE_OAUTH_TOKEN` (**必須**): Claude Code Action 用 OAuth トークン
- **呼び出し元ジョブの必要権限 (`permissions`)**:
  - `contents: write`
  - `pull-requests: write`
  - `issues: read`
  - `id-token: write`
  - `actions: read`

#### 下流リポジトリでの記述例 (`.github/workflows/claude.yml`)
```yaml
name: Claude Code

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  pull_request_review:
    types: [submitted]
  issues:
    types: [opened, assigned]

permissions: {}

jobs:
  claude:
    uses: HighBridgeDragon/jp-skills-shared/.github/workflows/reusable-claude.yml@v1
    permissions:
      contents: write
      pull-requests: write
      issues: read
      id-token: write
      actions: read
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

---

## 5. Composite Action: Setup Takumi Guard

`actions/setup-takumi-guard/action.yml` は、GMO Flatt Security 製の [Takumi Guard](https://github.com/flatt-security/setup-takumi-guard-npm)（npm パッケージのサプライチェーン保護ツール）をセットアップする Composite Action です。
Claude Code ワークフロー内で npm パッケージを実行・インストールする際の改ざん・悪意あるパッケージ混入を防御します。

---

## 6. 同期原本と同期スクリプト (`sync.sh`)

### 6.1 同期対象ファイル原本 (`sync/files/`)
- `.gitattributes`: シェルスクリプトの LF 改行保護、および GitHub Download ZIP / Source code (zip) からの `SKILL.md` 除外（誤解釈・誤アップロード防止）。
- `.markdownlint.json`: プロジェクト共通の MarkdownLint 設定。
- `.github/dependabot.yml`: GitHub Actions の週次定期更新（月曜実行、コミットプレフィックス `ci`）。

※ 各種 AI クライアントへの導入手順は、本リポジトリの [`docs/install-guide.md`](docs/install-guide.md) を単一情報源（SSOT）として集約しています。下流リポジトリの `docs/install.md` は共通ガイドへのリンクとスキル固有の制約・ドメインのみを保持します。

### 6.2 同期スクリプト (`sync/sync.sh`) の使用方法

下流リポジトリへの設定ファイル・ドキュメントの同期は、`sync/sync.sh` を用いてローカルから実行します。

#### 基本コマンド例

```bash
# 1. 差分確認のみ（dry-run）: 全リポジトリを一時ディレクトリに clone して差分を表示
bash sync/sync.sh --dry-run

# 2. ローカルディレクトリを指定して差分確認 (高速)
bash sync/sync.sh --dry-run --src-dir c:/SRC

# 3. 特定のリポジトリのみ差分確認
bash sync/sync.sh --dry-run jp-diet-minutes-skill

# 4. 実際の同期と Pull Request 作成の実行
# (ブランチ shared-sync の作成・コミット・プッシュ・gh pr create)
bash sync/sync.sh
```

#### コマンドオプション一覧

| オプション | 引数 | 説明 | デフォルト値 |
|---|---|---|---|
| `--dry-run` | なし | 差分表示のみを行い、コミット・プッシュ・PR 作成をスキップ | `false` |
| `--src-dir` | `<dir>` | 既存ローカルリポジトリが存在する親ディレクトリを指定 | 自動探索 (`c:/SRC` 等) または clone |
| `--branch` | `<name>` | 作成・プッシュする同期ブランチ名 | `shared-sync` |
| `--owner` | `<name>` | 対象 GitHub オーナー/組織名 | `HighBridgeDragon` |
| `-h`, `--help` | なし | ヘルプメッセージを表示 | - |

---

## 7. セキュリティと設計原則

1. **最小権限原則 (Least Privilege)**:
   すべての Reusable Workflow の最上位で `permissions: {}` を宣言し、各ジョブで必要な権限のみをピンポイントで明示付与しています。
2. **サプライチェーン・認証情報の保護**:
   `actions/checkout` では `persist-credentials: false` を徹底し、不要なトークン流出を防止しています。例外は Claude 系 2 本の呼び出し元リポジトリの checkout で、private リポジトリに限り資格情報を残します。claude-code-action が認証設定より前に `git fetch` するため、残さないと private では必ず失敗します（[anthropics/claude-code-action#1711](https://github.com/anthropics/claude-code-action/issues/1711)）。action は実行中に自身のトークンを `.git/config` へ書き込む（[#1818](https://github.com/anthropics/claude-code-action/issues/1818)）ため、残すことで増える露出は小さいと判断しています。public は匿名で fetch できるため従来どおり残しません。また、Claude Code 実行前には Takumi Guard を必ず実行します。
3. **インジェクション・ディレクトリトラバーサル防御**:
   `reusable-release.yml` では、受け取った `skill-dir` 引数を正規表現（`^[a-z0-9][a-z0-9-]*(/[a-z0-9][a-z0-9-]*)*$`）で厳格に検証し、コマンドインジェクションや親ディレクトリ（`..`）へのトラバーサルを遮断します。
