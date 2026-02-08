#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web/mobile) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Run async so session starts immediately while deps install in background
echo '{"async": true, "asyncTimeout": 300000}'

cd "$CLAUDE_PROJECT_DIR"

# ── Detect package manager and install ───────────────────────────────────────
if [ -f "pnpm-lock.yaml" ]; then
  command -v pnpm &>/dev/null || npm install -g pnpm@10
  pnpm install --frozen-lockfile=false
  pnpm build 2>/dev/null || true
elif [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then
  command -v bun &>/dev/null || npm install -g bun
  bun install
  bun run build 2>/dev/null || true
elif [ -f "yarn.lock" ]; then
  command -v yarn &>/dev/null || npm install -g yarn
  yarn install
  yarn build 2>/dev/null || true
elif [ -f "package-lock.json" ] || [ -f "package.json" ]; then
  npm install
  npm run build 2>/dev/null || true
elif [ -f "requirements.txt" ]; then
  pip install -r requirements.txt
elif [ -f "pyproject.toml" ]; then
  pip install -e ".[dev]" 2>/dev/null || pip install -e .
elif [ -f "Cargo.toml" ]; then
  cargo build 2>/dev/null || true
elif [ -f "go.mod" ]; then
  go mod download
fi
