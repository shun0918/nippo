#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
NIPPO_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/nippo/config"
if [[ -f "$NIPPO_CONFIG" ]]; then
  # shellcheck source=/dev/null
  source "$NIPPO_CONFIG"
fi

# --- Usage ---
usage() {
  echo "Usage: $(basename "$0") [OPTIONS] [YYYY-MM-DD]"
  echo ""
  echo "Options:"
  echo "  -o, --output DIR   Output directory for reports"
  echo "  --setup            Create config file interactively"
  echo "  -h, --help         Show this help"
  echo ""
  echo "Config: $NIPPO_CONFIG"
  exit 0
}

# --- Setup ---
run_setup() {
  echo "nippo setup"
  echo "==========="
  echo ""
  echo "Config file: $NIPPO_CONFIG"
  echo ""

  # GitHub user
  local default_user
  default_user="$(gh api user --jq '.login' 2>/dev/null || true)"
  read -rp "GitHub username [${default_user}]: " input_user
  local github_user="${input_user:-$default_user}"

  # Output directory
  read -rp "Report output directory (absolute path): " input_output
  local output_dir="$input_output"

  if [[ -z "$output_dir" ]]; then
    echo "Error: Output directory is required." >&2
    exit 1
  fi

  # Write config
  mkdir -p "$(dirname "$NIPPO_CONFIG")"
  cat > "$NIPPO_CONFIG" <<EOC
# nippo config
GITHUB_USER="$github_user"
OUTPUT_DIR="$output_dir"
EOC

  echo ""
  echo "Config saved to $NIPPO_CONFIG"
  cat "$NIPPO_CONFIG"
  exit 0
}

# --- Parse arguments ---
# CLI args override config values
CLI_OUTPUT_DIR=""
TARGET_DATE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      CLI_OUTPUT_DIR="$2"
      shift 2
      ;;
    --setup)
      run_setup
      ;;
    -h|--help)
      usage
      ;;
    *)
      TARGET_DATE="$1"
      shift
      ;;
  esac
done

# CLI > config > default
OUTPUT_DIR="${CLI_OUTPUT_DIR:-${OUTPUT_DIR:-}}"
GITHUB_USER="${GITHUB_USER:-}"
TARGET_DATE="${TARGET_DATE:-$(date +%Y-%m-%d)}"

# --- Prerequisites ---
for cmd in gh jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is not installed." >&2
    exit 1
  fi
done

# Validate date format
if [[ ! "$TARGET_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: Invalid date format. Use YYYY-MM-DD." >&2
  exit 1
fi

# Validate date value (macOS/Linux compatible)
if date --version &>/dev/null 2>&1; then
  # GNU date (Linux)
  if ! date -d "$TARGET_DATE" &>/dev/null 2>&1; then
    echo "Error: Invalid date '$TARGET_DATE'." >&2
    exit 1
  fi
else
  # BSD date (macOS)
  if ! date -j -f "%Y-%m-%d" "$TARGET_DATE" &>/dev/null 2>&1; then
    echo "Error: Invalid date '$TARGET_DATE'." >&2
    exit 1
  fi
fi

YEAR="${TARGET_DATE:0:4}"
MONTH="${TARGET_DATE:5:2}"

# --- GitHub User ---
if [[ -z "${GITHUB_USER:-}" ]]; then
  GITHUB_USER="$(gh api user --jq '.login' 2>/dev/null || true)"
  if [[ -z "$GITHUB_USER" ]]; then
    echo "Error: Could not determine GitHub user. Set GITHUB_USER env var or authenticate with 'gh auth login'." >&2
    exit 1
  fi
fi

echo "Generating report for $GITHUB_USER on $TARGET_DATE ..."

# --- Output path ---
if [[ -z "$OUTPUT_DIR" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  OUTPUT_DIR="$REPO_ROOT/reports"
fi
REPORT_DIR="$OUTPUT_DIR/$YEAR/$MONTH"
REPORT_FILE="$REPORT_DIR/$TARGET_DATE.md"

mkdir -p "$REPORT_DIR"

# --- Preserve existing Notes ---
EXISTING_NOTES=""
if [[ -f "$REPORT_FILE" ]]; then
  # Extract everything after "## Notes" line
  EXISTING_NOTES="$(sed -n '/^## Notes$/,$ { /^## Notes$/d; p; }' "$REPORT_FILE")"
fi

# --- Collect GitHub data ---

# 1. Commits
COMMITS_JSON="$(gh search commits --author "$GITHUB_USER" --author-date "$TARGET_DATE" \
  --json repository,sha,commit --limit 100 2>/dev/null || echo '[]')"

# 2. Created PRs
CREATED_PRS_JSON="$(gh search prs --author "$GITHUB_USER" --created "$TARGET_DATE" \
  --json repository,number,title,state,url --limit 100 2>/dev/null || echo '[]')"

# 3. Merged PRs
MERGED_PRS_JSON="$(gh search prs --author "$GITHUB_USER" --merged "$TARGET_DATE" \
  --json repository,number,title,state,url --limit 100 2>/dev/null || echo '[]')"

# 4. Issues
ISSUES_JSON="$(gh search issues --involves "$GITHUB_USER" --updated "$TARGET_DATE" \
  --json repository,number,title,state,url --limit 100 2>/dev/null || echo '[]')"

# 5. Reviews
REVIEWS_JSON="$(gh search prs --reviewed-by "$GITHUB_USER" --updated "$TARGET_DATE" \
  --json repository,number,title,state,url --limit 100 2>/dev/null || echo '[]')"

# --- Generate timestamp ---
GENERATED_AT="$(date '+%Y-%m-%d %H:%M:%S %Z')"

# --- Build Markdown ---

{
  echo "# Daily Report: $TARGET_DATE"
  echo ""
  echo "> Generated at $GENERATED_AT"
  echo "> GitHub User: $GITHUB_USER"
  echo ""

  # Commits section
  echo "## Commits"
  echo ""
  COMMIT_COUNT="$(echo "$COMMITS_JSON" | jq 'length')"
  if [[ "$COMMIT_COUNT" -eq 0 ]]; then
    echo "_No commits._"
  else
    echo "$COMMITS_JSON" | jq -r '
      group_by(.repository.fullName)
      | .[]
      | "### " + .[0].repository.fullName,
      "",
      (.[] | "- [`" + (.sha[0:7]) + "`](https://github.com/" + .repository.fullName + "/commit/" + .sha + ") " + (.commit.message | split("\n") | .[0])),
      ""
    '
  fi
  echo ""

  # Pull Requests section
  echo "## Pull Requests"
  echo ""

  echo "### Created"
  echo ""
  CREATED_COUNT="$(echo "$CREATED_PRS_JSON" | jq 'length')"
  if [[ "$CREATED_COUNT" -eq 0 ]]; then
    echo "_No PRs created._"
  else
    echo "$CREATED_PRS_JSON" | jq -r '
      .[] | "- [" + .repository.nameWithOwner + "#" + (.number|tostring) + "](" + .url + ") " + .title + " (`" + .state + "`)"
    '
  fi
  echo ""

  echo "### Merged"
  echo ""
  MERGED_COUNT="$(echo "$MERGED_PRS_JSON" | jq 'length')"
  if [[ "$MERGED_COUNT" -eq 0 ]]; then
    echo "_No PRs merged._"
  else
    echo "$MERGED_PRS_JSON" | jq -r '
      .[] | "- [" + .repository.nameWithOwner + "#" + (.number|tostring) + "](" + .url + ") " + .title
    '
  fi
  echo ""

  # Issues section
  echo "## Issues"
  echo ""
  ISSUE_COUNT="$(echo "$ISSUES_JSON" | jq 'length')"
  if [[ "$ISSUE_COUNT" -eq 0 ]]; then
    echo "_No issue activity._"
  else
    echo "$ISSUES_JSON" | jq -r '
      .[] | "- [" + .repository.nameWithOwner + "#" + (.number|tostring) + "](" + .url + ") " + .title + " (`" + .state + "`)"
    '
  fi
  echo ""

  # Reviews section
  echo "## Reviews"
  echo ""
  REVIEW_COUNT="$(echo "$REVIEWS_JSON" | jq 'length')"
  if [[ "$REVIEW_COUNT" -eq 0 ]]; then
    echo "_No reviews._"
  else
    echo "$REVIEWS_JSON" | jq -r '
      .[] | "- [" + .repository.nameWithOwner + "#" + (.number|tostring) + "](" + .url + ") " + .title + " (`" + .state + "`)"
    '
  fi
  echo ""

  # Notes section
  echo "## Notes"
  echo ""
  if [[ -n "$EXISTING_NOTES" ]]; then
    echo "$EXISTING_NOTES"
  else
    echo "<!-- Write your notes here -->"
  fi

} > "$REPORT_FILE"

echo "Report saved to $REPORT_FILE"
