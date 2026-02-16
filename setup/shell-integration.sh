#!/usr/bin/env bash
# Shell integration for Claude Code with CCP
# Source this from ~/.bashrc or ~/.zshrc

# Fix PATH on Windows (mise activate can clobber system bins)
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    _win_user="$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r' || whoami)"
    [[ ":$PATH:" != *":/usr/bin:"* ]] && export PATH="/usr/bin:/bin:/mingw64/bin:/c/Windows/System32:/c/Users/$_win_user/AppData/Local/Microsoft/WindowsApps:$PATH"
    unset _win_user
    ;;
esac

# Ensure mise shims are in PATH (makes cli-proxy-api, claude, ccp available)
if [[ -d "${LOCALAPPDATA:-$HOME/AppData/Local}/mise/shims" ]]; then
  # Windows (Git Bash)
  export PATH="${LOCALAPPDATA:-$HOME/AppData/Local}/mise/shims:$PATH"
elif [[ -d "$HOME/.local/share/mise/shims" ]]; then
  # macOS / Linux
  export PATH="$HOME/.local/share/mise/shims:$PATH"
fi

# Claude alias - loads ~/.claude as additional config directory
if command -v ccp &> /dev/null; then
  # CCP mode: use profile path
  alias claude='CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 command claude --add-dir "${CLAUDE_CONFIG_DIR:-$(ccp which --path 2>/dev/null)}"'
  ccp-use() {
    ccp use "$@"
    command -v mise &> /dev/null && [[ -f mise.toml ]] && eval "$(mise env)"
  }
else
  # Standalone mode: use ~/.claude directly
  alias claude='CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 command claude --add-dir "$HOME/.claude"'
fi
