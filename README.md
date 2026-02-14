# nippo

あの日、なにをしていたか。
ふと気になる瞬間がある。

振り返ることで気づく、自分の変化。
でも、記録を続けることは、人生への足し算。

その手間を、nippo が引き受ける。
あなたの毎日を、静かに刻み続けるために。

*— by Claude*

---

毎日のGitHub活動を自動収集し、マークダウン形式の日報として蓄積するシステムです。

## 前提条件

- [gh](https://cli.github.com/) (GitHub CLI) — 認証済みであること (`gh auth login`)
- [jq](https://jqlang.github.io/jq/) — JSONパーサー

## セットアップ

### 1. 日報データ用のリポジトリを作成

日報データは別リポジトリ (private 推奨) で管理します:

```bash
gh repo create your-name/my-reports --private --clone
```

### 2. 設定ファイルを作成

対話形式でセットアップ:

```bash
./scripts/generate-report.sh --setup
```

以下の内容で `~/.config/nippo/config` が作成されます:

```bash
# nippo config
GITHUB_USER="your-name"
OUTPUT_DIR="/path/to/my-reports/reports"
```

手動で作成・編集しても OK です。

| 設定項目 | 説明 | 必須 |
|---------|------|------|
| `GITHUB_USER` | GitHub ユーザー名 | いいえ (`gh` から自動取得) |
| `OUTPUT_DIR` | レポート出力先ディレクトリ | いいえ (デフォルト: `./reports`) |

## 使い方

### ローカル実行

```bash
# 当日の日報を生成（OUTPUT_DIR に出力）
./scripts/generate-report.sh

# 日付を指定
./scripts/generate-report.sh 2026-02-14

# --output で一時的に出力先を変更（config より優先）
./scripts/generate-report.sh --output /tmp/reports
```

### GitHub Actions (Reusable Workflow)

日報データ用リポジトリに以下のワークフローを `.github/workflows/daily-report.yml` として配置してください:

```yaml
name: Daily Report

on:
  workflow_dispatch:
    inputs:
      date:
        description: "Target date (YYYY-MM-DD). Defaults to today."
        required: false
        type: string
      github_user:
        description: "GitHub username. Defaults to the actor."
        required: false
        type: string

jobs:
  report:
    uses: shun0918/nippo/.github/workflows/generate-report.yml@main
    with:
      date: ${{ inputs.date || '' }}
      github_user: ${{ inputs.github_user || '' }}
    secrets:
      gh_pat: ${{ secrets.GH_PAT }}
```

> **注意:** プライベートリポジトリの活動を取得するには、`repo` スコープを持つ [Personal Access Token](https://github.com/settings/tokens) を `GH_PAT` シークレットとして登録してください。

## Ignore 設定

特定の Organization やリポジトリを日報から除外できます。`~/.config/nippo/ignore` にパターンを記述してください。

```bash
# Organization 全体を除外
my-company/*

# 特定リポジトリを除外
shun0918/secret-project

# ワイルドカード
*/internal-*
```

- 1行1パターン（`fnmatch` / bash glob 形式）
- `#` 以降はコメント
- 空行は無視

対象は `owner/repo` 形式の文字列に対してマッチングされます。

## レポート内容

- **Commits** — 当日のコミット（リポジトリ別）
- **Pull Requests** — 作成したPR / マージされたPR
- **Issues** — 関連するIssueの活動
- **Reviews** — レビューしたPR
- **Notes** — 手書きメモ欄（再生成しても保持される）
