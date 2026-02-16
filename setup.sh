#!/usr/bin/env bash
#
# dot-claude: Full Claude Code environment setup
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/brixtonpham/dot-claude/main/setup.sh | bash
#   bash ~/.claude/setup.sh   # re-sync
#
set -euo pipefail

# Fix PATH on Windows
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    WIN_USER="$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r' || whoami)"
    export PATH="/usr/bin:/bin:/mingw64/bin:/c/Windows/System32:/c/Users/$WIN_USER/AppData/Local/Microsoft/WindowsApps:$PATH"
    ;;
esac

REPO="https://github.com/brixtonpham/dot-claude.git"
TARGET="$HOME/.claude"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*"; exit 1; }
info() { echo -e "${BLUE}[i]${NC} $*"; }

OS="unknown"
case "$(uname -s)" in
  Darwin*)  OS="mac";;
  Linux*)   OS="linux";;
  MINGW*|MSYS*|CYGWIN*) OS="windows";;
esac

SHELL_NAME="$(basename "${SHELL:-bash}")"
case "$SHELL_NAME" in
  zsh)  SHELL_RC="$HOME/.zshrc";;
  *)    SHELL_RC="$HOME/.bashrc"
        [[ "$OS" == "windows" ]] && SHELL_RC="$HOME/.bash_profile"
        ;;
esac

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       dot-claude setup                   ║"
echo "║       OS: $OS | Shell: $SHELL_NAME              ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Step 1: Restore ~/.claude from git
# ═══════════════════════════════════════════════════════════════════════
log "Step 1/5: Restoring ~/.claude..."

if [[ -L "$TARGET" ]]; then
    warn "~/.claude is a symlink → $(readlink "$TARGET")"
    warn "Removing symlink (original target untouched)"
    rm "$TARGET"
fi

if [[ -d "$TARGET/.git" ]]; then
    git -C "$TARGET" fetch origin main 2>/dev/null
    git -C "$TARGET" reset --hard origin/main 2>/dev/null
    git -C "$TARGET" clean -fd 2>/dev/null
    log "Synced to latest remote."
elif [[ -d "$TARGET" ]]; then
    BACKUP="$TARGET.bak.$(date +%s)"
    warn "Backing up existing ~/.claude to $BACKUP"
    mv "$TARGET" "$BACKUP"
    git clone "$REPO" "$TARGET"
    log "Fresh clone complete."
else
    git clone "$REPO" "$TARGET"
    log "Cloned to $TARGET"
fi

# Create gitignored directories
mkdir -p "$TARGET"/{debug,session-env,file-history,shell-snapshots,cache,history,telemetry}

# ═══════════════════════════════════════════════════════════════════════
# Step 2: Install mise + tools
# ═══════════════════════════════════════════════════════════════════════
log "Step 2/5: Setting up mise + tools..."

if [[ -z "${LOCALAPPDATA:-}" && "$OS" == "windows" ]]; then
  export LOCALAPPDATA="$HOME/AppData/Local"
fi

for p in \
  "${LOCALAPPDATA:-}/mise/bin" \
  "${LOCALAPPDATA:-}/Programs/mise" \
  "$HOME/AppData/Local/mise/bin" \
  "$HOME/.local/bin" \
  "$HOME/.local/bin/mise/bin"; do
  [[ -d "$p" ]] && export PATH="$p:$PATH"
done

if ! command -v mise &>/dev/null; then
  if [[ "$OS" == "windows" ]]; then
    if command -v winget.exe &>/dev/null || [[ -f "/c/Users/${WIN_USER:-}/AppData/Local/Microsoft/WindowsApps/winget.exe" ]]; then
      log "Installing mise via winget..."
      winget.exe install jdx.mise --accept-source-agreements --accept-package-agreements 2>&1 || true
      for p in "${LOCALAPPDATA:-}/mise/bin" "${LOCALAPPDATA:-}/Programs/mise" "$HOME/AppData/Local/mise/bin"; do
        [[ -d "$p" ]] && export PATH="$p:$PATH"
      done
    else
      log "Installing mise from GitHub releases..."
      MISE_VERSION=$(curl -fsSL "https://api.github.com/repos/jdx/mise/releases/latest" | grep '"tag_name"' | head -1 | cut -d'"' -f4)
      MISE_DIR="$HOME/.local/bin"
      mkdir -p "$MISE_DIR"
      curl -fsSL "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-windows-x64.zip" -o /tmp/mise.zip
      unzip -o /tmp/mise.zip -d "$MISE_DIR" 2>/dev/null || true
      rm -f /tmp/mise.zip
      export PATH="$MISE_DIR:$MISE_DIR/mise/bin:$PATH"
    fi
  else
    curl -fsSL https://mise.jdx.dev/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
fi

if command -v mise &>/dev/null; then
  log "mise: $(mise --version)"
  mkdir -p "$HOME/.config/mise"
  cp -f "$TARGET/setup/mise-config.toml" "$HOME/.config/mise/config.toml"
  mise install --yes 2>&1 | tail -5 || warn "Some tools failed. Run 'mise install' later."

  SYSTEM_PATH="/usr/bin:/bin:/mingw64/bin:/usr/sbin:/sbin"
  eval "$(mise activate bash 2>/dev/null || true)"
  eval "$(mise env 2>/dev/null || true)"
  export PATH="$PATH:$SYSTEM_PATH"

  if [[ -d "${LOCALAPPDATA:-}/mise/shims" ]]; then
    export PATH="${LOCALAPPDATA:-}/mise/shims:$PATH"
  elif [[ -d "$HOME/.local/share/mise/shims" ]]; then
    export PATH="$HOME/.local/share/mise/shims:$PATH"
  fi
  mise reshim 2>/dev/null || true
  log "Tools installed."
else
  warn "mise not in PATH. Some steps may be skipped."
fi

# ═══════════════════════════════════════════════════════════════════════
# Step 3: Install ProxyPal + proxy config
# ═══════════════════════════════════════════════════════════════════════
log "Step 3/5: Setting up ProxyPal..."

install_proxypal() {
  local PROXYPAL_REPO="heyhuynhgiabuu/proxypal"
  local LATEST
  LATEST=$(curl -fsSL "https://api.github.com/repos/$PROXYPAL_REPO/releases/latest" 2>/dev/null | grep '"tag_name"' | head -1 | cut -d'"' -f4)
  [[ -z "$LATEST" ]] && { warn "Could not fetch ProxyPal version."; return 1; }
  local VER="${LATEST#v}"

  case "$OS" in
    windows)
      local EXE_NAME="ProxyPal_${VER}_x64-setup.exe"
      log "Downloading ProxyPal $VER for Windows..."
      curl -fsSL "https://github.com/$PROXYPAL_REPO/releases/download/${LATEST}/${EXE_NAME}" -o "/tmp/$EXE_NAME" || return 1
      cmd.exe /c "$(cygpath -w "/tmp/$EXE_NAME")" 2>/dev/null &
      ;;
    mac)
      local DMG_NAME="ProxyPal_${VER}_aarch64.dmg"
      log "Downloading ProxyPal $VER for macOS..."
      curl -fsSL "https://github.com/$PROXYPAL_REPO/releases/download/${LATEST}/${DMG_NAME}" -o "/tmp/$DMG_NAME" || return 1
      open "/tmp/$DMG_NAME"
      ;;
    linux)
      local DEB_NAME="proxy-pal_${VER}_amd64.deb"
      log "Downloading ProxyPal $VER for Linux..."
      curl -fsSL "https://github.com/$PROXYPAL_REPO/releases/download/${LATEST}/${DEB_NAME}" -o "/tmp/$DEB_NAME" || return 1
      sudo dpkg -i "/tmp/$DEB_NAME" 2>/dev/null || sudo apt-get install -f -y 2>/dev/null
      ;;
  esac
}

PROXYPAL_INSTALLED=false
case "$OS" in
  windows) { [[ -d "${LOCALAPPDATA:-}/ProxyPal" ]] || [[ -d "${APPDATA:-}/ProxyPal" ]] || [[ -f "/c/Program Files/ProxyPal/ProxyPal.exe" ]]; } && PROXYPAL_INSTALLED=true ;;
  mac) { [[ -d "/Applications/ProxyPal.app" ]] || [[ -d "$HOME/Applications/ProxyPal.app" ]]; } && PROXYPAL_INSTALLED=true ;;
esac

if $PROXYPAL_INSTALLED; then
  log "ProxyPal already installed."
else
  install_proxypal || warn "ProxyPal install failed. Download: https://github.com/heyhuynhgiabuu/proxypal/releases"
fi

PROXY_CONFIG_DIR="$HOME/.cli-proxy-api"
PROXY_CONFIG="$PROXY_CONFIG_DIR/config.yaml"
mkdir -p "$PROXY_CONFIG_DIR"
if [[ ! -f "$PROXY_CONFIG" ]]; then
  cp "$TARGET/setup/proxy-config.yaml" "$PROXY_CONFIG"
  log "Proxy config installed to $PROXY_CONFIG"
fi

# ═══════════════════════════════════════════════════════════════════════
# Step 4: MCP servers + Shell integration
# ═══════════════════════════════════════════════════════════════════════
log "Step 4/5: MCP servers & shell integration..."

CLAUDE_JSON="$HOME/.claude.json"
if [[ ! -f "$CLAUDE_JSON" ]]; then
  cat > "$CLAUDE_JSON" <<'EOF'
{
  "mcpServers": {
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"],
      "env": {}
    },
    "grep": {
      "type": "http",
      "url": "https://mcp.grep.app"
    },
    "stitch": {
      "type": "http",
      "url": "https://stitch.googleapis.com/mcp",
      "headers": {
        "x-goog-api-key": "REPLACE_WITH_YOUR_STITCH_API_KEY"
      }
    }
  }
}
EOF
  warn "Created $CLAUDE_JSON - update Stitch API key!"
else
  info "MCP config exists - keeping current $CLAUDE_JSON"
fi

add_line_if_missing() {
  local file="$1" marker="$2" line="$3"
  if [[ -f "$file" ]] && grep -qF "$marker" "$file" 2>/dev/null; then
    return 0
  elif [[ -f "$file" ]] || touch "$file" 2>/dev/null; then
    printf '\n%s\n' "$line" >> "$file"
    log "Added to $file"
  fi
}

add_line_if_missing "$SHELL_RC" "claude/setup/shell-integration" \
  '# Claude shell integration
source "$HOME/.claude/setup/shell-integration.sh"'

add_line_if_missing "$SHELL_RC" "mise activate" \
  "# mise
eval \"\$(mise activate $SHELL_NAME)\""

if [[ "$OS" == "windows" ]]; then
  add_line_if_missing "$SHELL_RC" "mingw64/bin" \
    '# Fix PATH after mise activate (Windows/Git Bash)
_win_user="$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '"'"'\r'"'"' || whoami)"
[[ ":$PATH:" != *":/usr/bin:"* ]] && export PATH="/usr/bin:/bin:/mingw64/bin:/c/Windows/System32:/c/Users/$_win_user/AppData/Local/Microsoft/WindowsApps:$PATH"
unset _win_user'
fi

log "Shell integration configured."

# ═══════════════════════════════════════════════════════════════════════
# Step 5: Start proxy + Antigravity login
# ═══════════════════════════════════════════════════════════════════════
log "Step 5/5: Starting CLIProxyAPI + Antigravity login..."

PROXY_BIN=""
if command -v cli-proxy-api &>/dev/null; then
  PROXY_BIN="cli-proxy-api"
elif command -v mise &>/dev/null; then
  PROXY_BIN="$(mise which cli-proxy-api 2>/dev/null || true)"
fi

if [[ -n "$PROXY_BIN" && -f "$PROXY_CONFIG" ]]; then
  if [[ "$OS" == "windows" ]]; then
    local_pid=$(netstat.exe -ano 2>/dev/null | grep ":8317.*LISTENING" | awk '{print $5}' | head -1)
    [[ -n "${local_pid:-}" ]] && taskkill.exe //PID "$local_pid" //F 2>/dev/null || true
  else
    lsof -ti:8317 2>/dev/null | xargs kill -9 2>/dev/null || true
  fi
  sleep 1

  nohup "$PROXY_BIN" -config "$PROXY_CONFIG" > /tmp/cli-proxy-api.log 2>&1 &
  PROXY_PID=$!
  sleep 2

  if kill -0 "$PROXY_PID" 2>/dev/null; then
    log "CLIProxyAPI running on port 8317 (PID: $PROXY_PID)"
    if ls "$PROXY_CONFIG_DIR"/antigravity-*.json &>/dev/null; then
      log "Antigravity tokens found. Ready to use Claude!"
    else
      info "No Antigravity tokens found. Opening login..."
      sleep 1
      case "$OS" in
        windows) cmd.exe /c start http://127.0.0.1:8317/management/ 2>/dev/null || true ;;
        mac)     open "http://127.0.0.1:8317/management/" 2>/dev/null || true ;;
        *)       xdg-open "http://127.0.0.1:8317/management/" 2>/dev/null || true ;;
      esac
      info "Login at: http://127.0.0.1:8317/management/"
    fi
  else
    warn "CLIProxyAPI failed to start. Check /tmp/cli-proxy-api.log"
  fi
else
  warn "cli-proxy-api not found. Run 'mise install' after setup."
fi

# ═══════════════════════════════════════════════════════════════════════
# Done!
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║            Setup Complete!               ║"
echo "╠══════════════════════════════════════════╣"
echo "║  1. Restart your terminal                ║"
echo "║  2. Login Antigravity in browser         ║"
echo "║  3. Run: claude                          ║"
echo "╚══════════════════════════════════════════╝"
echo ""
