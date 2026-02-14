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
./scripts/generate-report.sh --output ~/Code/nippo-mine

# 組み合わせ
GITHUB_USER=foo ./scripts/generate-report.sh --output ~/Code/nippo-mine 2026-02-14
```

### 2リポジトリ構成

日報データを private リポジトリで管理する場合の推奨構成:

| リポジトリ | 公開 | 用途 |
|-----------|------|------|
| `nippo` | public | スクリプト・ワークフロー |
| `nippo-mine` | private | 日報データの格納 |

```bash
# ローカル実行例
cd nippo
./scripts/generate-report.sh --output ../nippo-mine/reports
```

### GitHub Actions

`nippo-mine` リポジトリ側のワークフローから実行できます。詳細は `nippo-mine` の README を参照してください。

> **注意:** プライベートリポジトリの活動を取得するには、`repo` スコープを持つ Personal Access Token (PAT) を `GH_PAT` シークレットとして登録してください。

## レポート内容

- **Commits** — 当日のコミット（リポジトリ別）
- **Pull Requests** — 作成したPR / マージされたPR
- **Issues** — 関連するIssueの活動
- **Reviews** — レビューしたPR
- **Notes** — 手書きメモ欄（再生成しても保持される）
