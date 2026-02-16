#!/usr/bin/env bash
#
# Restore ~/.claude from brixtonpham/dot-claude
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/brixtonpham/dot-claude/main/setup.sh | bash
#   bash ~/.claude/setup.sh   # re-sync
#
set -euo pipefail

REPO="https://github.com/brixtonpham/dot-claude.git"
TARGET="$HOME/.claude"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*"; exit 1; }

echo ""
echo "╔══════════════════════════════════════╗"
echo "║     dot-claude restore               ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── Step 1: Handle existing ~/.claude ──
if [ -L "$TARGET" ]; then
    warn "~/.claude is a symlink → $(readlink "$TARGET")"
    warn "Removing symlink (original target untouched)"
    rm "$TARGET"
elif [ -d "$TARGET" ]; then
    if [ -d "$TARGET/.git" ]; then
        log "~/.claude is already a git repo, pulling latest..."
        git -C "$TARGET" fetch origin
        git -C "$TARGET" reset --hard origin/main
        log "Updated to latest. Done!"
        exit 0
    else
        BACKUP="$TARGET.bak.$(date +%s)"
        warn "~/.claude exists but is not a git repo"
        warn "Backing up to $BACKUP"
        mv "$TARGET" "$BACKUP"
    fi
fi

# ── Step 2: Clone ──
log "Cloning dot-claude → ~/.claude"
git clone "$REPO" "$TARGET"

# ── Step 3: Create dirs that were gitignored ──
mkdir -p "$TARGET"/{debug,session-env,file-history,shell-snapshots,cache,history,telemetry}

log "Done! ~/.claude restored with $(git -C "$TARGET" ls-files | wc -l | tr -d ' ') files"
echo ""
echo "Next: run your Claude Code setup (ccp, proxy, etc.)"
