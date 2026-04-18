#!/bin/sh
set -eu

# Fresh iSH bootstrap for a stable local dev shell.
# Intentionally avoids upgrading the whole distro to edge.
# Uses default iSH repos for the base system, then adds ONLY edge/community
# long enough to install nodejs-current, then removes it again.

log() {
  printf '\n==> %s\n' "$1"
}

require_root() {
  if [ "$(id -u)" != "0" ]; then
    echo "Run this as root inside iSH."
    exit 1
  fi
}

ensure_line() {
  file="$1"
  line="$2"
  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

remove_line() {
  file="$1"
  line="$2"
  tmp="${file}.tmp.$$"
  grep -vxF "$line" "$file" > "$tmp" || true
  mv "$tmp" "$file"
}

require_root

log "Updating base system"
apk update
apk upgrade

log "Installing stable base packages"
apk add bash curl git openssh openssl ranger screen zsh make nodejs npm

log "Temporarily enabling Alpine edge/community for newer Node only"
EDGE_REPO="https://dl-cdn.alpinelinux.org/alpine/edge/community"
ensure_line /etc/apk/repositories "$EDGE_REPO"
apk update

log "Installing nodejs-current without full distro upgrade"
apk add nodejs-current

log "Removing temporary edge repo"
remove_line /etc/apk/repositories "$EDGE_REPO"
apk update

log "Verifying Node and npm"
node -v
npm -v

log "Enabling Corepack"
corepack enable
corepack prepare pnpm@latest --activate
pnpm -v

log "Installing global JS tooling"
pnpm add -g turbo vercel @openai/codex

log "Installing Claude Code via npm (may fail on iSH due to architecture)"
npm install -g @anthropic-ai/claude-code || true

log "Installing Oh My Zsh"
export RUNZSH=no
export CHSH=no
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

log "Setting zsh as default shell when available"
if command -v zsh >/dev/null 2>&1; then
  chsh -s /bin/zsh root || true
fi

log "Done"
echo "Open a new shell and verify:"
echo "  node -v"
echo "  npm -v"
echo "  corepack --version"
echo "  pnpm -v"
echo "  turbo --version"
echo "  vercel --version"
echo "  codex --version"
echo "  claude --version || true"
echo "  zsh --version"
