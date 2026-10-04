# クライアント別共通インストールガイド / Client Installation Guide

本ドキュメントは、`HighBridgeDragon/jp-*-skill` シリーズの各スキルに共通する、各種 AI エージェントおよびクライアントへの導入手順と基本動作要件です。

各スキル固有の接続先ドメイン、実行環境（スクリプトまたは HTTP フェッチ）、禁止事項などの制約については、各リポジトリの `docs/install.md` をあわせてご確認ください。

## CLI / パッケージマネージャ

対応クライアント: Claude Code, Cursor, GitHub Copilot CLI, Gemini CLI ほか

```bash
npx skills add <owner>/<repo>
```

各リポジトリの指定コマンドを実行することで、お使いのエージェント環境（プロジェクトの `.agents/skills` やグローバル設定など）に自動インストールされます。

## デスクトップ / Web アプリ

各リポジトリの [Releases](https://github.com) に添付されている `<skill-name>.zip` をダウンロードして利用します。

> [!IMPORTANT]
> アップロードできるのは **Releases に添付された `<skill-name>.zip`** だけです。GitHub リポジトリ画面の **Code > Download ZIP** や Releases の **Source code (zip)** で取得した zip は、展開時のルートが `<repo>-<ref>/`（直下に `<skill-name>/`）になり `SKILL.md` が直下に来ないため、skill として認識されません。
>
> Custom Skill は claude.ai・Claude API・Claude Code の間で同期しません。Claude Code に導入済みでも、claude.ai では別途アップロードが必要です。

### claude.ai / Claude Desktop

1. 各リポジトリの Releases から `<skill-name>.zip` をダウンロードします。
2. claude.ai の Skills 設定から zip ファイルをアップロードします（最新の画面操作手順は公式ヘルプ [Using Skills in Claude](https://support.claude.com/en/articles/12512180-using-skills-in-claude) を参照）。

#### 動作条件（claude.ai / Claude Desktop）

zip を導入しても、以下を満たさない環境では動作しません。

- **コード実行**: 有効になっていること（対象プランや要件の詳細は公式ヘルプ [Using Skills in Claude](https://support.claude.com/en/articles/12512180-using-skills-in-claude) を参照）。同梱スクリプトの実行や HTTP フェッチをコード実行サンドボックス内で行います。
- **ネットワークアクセス（許可ドメイン）**: claude.ai では既定で外部ドメインへの通信が制限されているため、組織オーナー（Organization Owner）による許可ドメインへの追加設定が必要です（設定手順の詳細は公式ヘルプ [Create and edit files with Claude の「Approved network domains」節](https://support.claude.com/en/articles/12111783-create-and-edit-files-with-claude#h_1010adf0ee) を参照。個人プランには追加設定がありません）。追加すべきドメイン名は各リポジトリの `docs/install.md` をご確認ください。許可ドメインを追加できない環境では、Claude Code 経由をご利用ください。
- **Claude API 経由**: API の Skills サンドボックスはネットワークアクセスを持たないため、原理的に外部 API を呼び出せません。

### OpenAI Codex

[OpenAI Codex のスキル仕様](https://developers.openai.com/codex/skills/) に準拠した配置手順です。

1. Releases から `<skill-name>.zip` をダウンロードして展開します。
2. 展開された `<skill-name>` フォルダ（直下に `SKILL.md` があるフォルダ）を、ユーザー共通スキルディレクトリ（`~/.agents/skills/` 直下）またはプロジェクトの `.agents/skills/` 直下に配置します（配置後のパス: `~/.agents/skills/<skill-name>/SKILL.md`。二重フォルダ `<skill-name>/<skill-name>/` にならないようご注意ください）。

> [!NOTE]
> 上記の配置パスは OpenAI Codex 公式ドキュメントに基づく仕様です。ChatGPT Desktop 等におけるローカルスキルの読み込み仕様や対応状況については、OpenAI の公式アナウンスをご確認ください。

### Goose

Block 主導のオープンソースエージェント Goose は [Agent Skills オープン標準](https://agentskills.io/clients) に対応しています。

1. Releases から `<skill-name>.zip` をダウンロードして展開します。
2. スキルの配置先や読み込み方法については、[Goose 公式ドキュメント](https://block.github.io/goose/) の指示に従ってください。なお、同梱スクリプトまたは HTTP 呼び出しを実行できるシェル環境が必要です。

### Google Gemini についての注意

- **Gemini CLI / Google Antigravity**: Agent Skills（`SKILL.md`）仕様に準拠しており、ローカル端末上で正常に動作します。
- **Web 版 Gemini（gemini.google.com）**: Gemini Web の Skills はプロンプト・指示ベースの拡張であり、サンドボックス内でのシェルスクリプト実行機構を持ちません。そのため、本スキルは Web 版 Gemini では動作しません。Gemini CLI または Google Antigravity をご利用ください。

## 共通の環境設定・注意点

### Windows 環境での利用注意（mcp-server-fetch）

`mcp-server-fetch` を Windows で使う場合、文字化け対策に `PYTHONIOENCODING=utf-8` の設定が必要です。設定例:

```json
{
  "mcpServers": {
    "fetch": {
      "command": "uvx",
      "args": ["mcp-server-fetch"],
      "env": {
        "PYTHONIOENCODING": "utf-8"
      }
    }
  }
}
```

## 出典

- [Agent Skills (agentskills.io)](https://agentskills.io)
- [Agent Skills Overview (Anthropic)](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
- [How to create custom Skills (Claude Help)](https://support.claude.com/en/articles/12512198-creating-custom-skills)
- [Using Skills in Claude (Claude Help)](https://support.claude.com/en/articles/12512180-using-skills-in-claude)
- [Create and edit files with Claude (Claude Help)](https://support.claude.com/en/articles/12111783-create-and-edit-files-with-claude)
- [Build skills (OpenAI Codex)](https://developers.openai.com/codex/skills/)
- [Goose (Block)](https://block.github.io/goose/)
