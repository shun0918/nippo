# nippo

毎日のGitHub活動を自動収集し、マークダウン形式の日報として蓄積するシステム。

## 前提条件

- [gh](https://cli.github.com/) (GitHub CLI) — 認証済みであること (`gh auth login`)
- [jq](https://jqlang.github.io/jq/) — JSONパーサー

## 使い方

### ローカル実行

```bash
# 当日の日報を生成
./scripts/generate-report.sh

# 日付を指定して生成
./scripts/generate-report.sh 2026-02-14

# GitHubユーザーを指定して生成
GITHUB_USER=foo ./scripts/generate-report.sh
```

### GitHub Actions

1. リポジトリの **Actions** タブから「Generate Daily Report」ワークフローを選択
2. **Run workflow** をクリックし、日付やユーザー名を入力（任意）
3. 生成されたレポートは自動的にコミット・プッシュされる

> **注意:** プライベートリポジトリの活動を取得するには、`repo` スコープを持つ Personal Access Token (PAT) を `GH_PAT` シークレットとして登録してください。

## ディレクトリ構成

```
nippo/
├── README.md
├── .gitignore
├── scripts/
│   └── generate-report.sh        # レポート生成スクリプト
├── .github/
│   └── workflows/
│       └── generate-report.yml    # GitHub Actions ワークフロー
└── reports/                       # 日報格納（自動生成）
    └── YYYY/
        └── MM/
            └── YYYY-MM-DD.md
```

## レポート内容

- **Commits** — 当日のコミット（リポジトリ別）
- **Pull Requests** — 作成したPR / マージされたPR
- **Issues** — 関連するIssueの活動
- **Reviews** — レビューしたPR
- **Notes** — 手書きメモ欄（再生成しても保持される）
