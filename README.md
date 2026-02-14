# nippo

毎日のGitHub活動を自動収集し、マークダウン形式の日報として蓄積するシステム。

## 前提条件

- [gh](https://cli.github.com/) (GitHub CLI) — 認証済みであること (`gh auth login`)
- [jq](https://jqlang.github.io/jq/) — JSONパーサー

## 使い方

### ローカル実行

```bash
# 当日の日報を生成（カレントディレクトリの reports/ に出力）
./scripts/generate-report.sh

# 日付を指定して生成
./scripts/generate-report.sh 2026-02-14

# 出力先を指定（別リポジトリなど）
./scripts/generate-report.sh --output /path/to/your-repo/reports

# 組み合わせ
GITHUB_USER=foo ./scripts/generate-report.sh --output /path/to/your-repo/reports 2026-02-14
```

### GitHub Actions (Reusable Workflow)

日報データを自分のリポジトリ (private 推奨) で管理できます。以下のワークフローをコピーして `.github/workflows/daily-report.yml` として配置してください:

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

#### セットアップ手順

1. 日報データ用のリポジトリを作成 (private 推奨)
2. 上記のワークフローファイルを配置
3. (任意) プライベートリポジトリの活動も取得したい場合は、`repo` スコープを持つ [Personal Access Token](https://github.com/settings/tokens) を `GH_PAT` シークレットとして登録
4. **Actions** タブから「Daily Report」を手動実行

## レポート内容

- **Commits** — 当日のコミット（リポジトリ別）
- **Pull Requests** — 作成したPR / マージされたPR
- **Issues** — 関連するIssueの活動
- **Reviews** — レビューしたPR
- **Notes** — 手書きメモ欄（再生成しても保持される）
