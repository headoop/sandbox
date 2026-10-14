#!/usr/bin/env bash
set -euo pipefail

# Verzeichnisse sicherstellen (Volumes koennen leer gemountet sein)
mkdir -p "$HOME/.config/opencode" "$HOME/.config/gh" \
         "$HOME/.local/share/opencode" "$HOME/.local/bin" \
         "$HOME/.npm-global/bin" "$HOME/go/pkg" \
         "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# --- Vorlagen aus config/ in die Volumes legen ------------------------
# Die Anmeldedaten der Agenten liegen in Volumes, nicht auf dem Host.
# Die Konfigurationsdateien werden beim ersten Start aus /opt/seed kopiert;
# mit SEED_OVERWRITE=1 bei jedem Start neu.
seed() {
  local src="$1" dst="$2"
  [ -f "$src" ] || return 0
  if [ ! -f "$dst" ] || [ "${SEED_OVERWRITE:-0}" = "1" ]; then
    install -m 0600 "$src" "$dst"
  fi
}
seed /opt/seed/claude/settings.json "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"

# Git-Identitaet aus der .env uebernehmen
if [ -n "${GIT_USER_NAME:-}" ]; then
  git config --global user.name "$GIT_USER_NAME"
fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then
  git config --global user.email "$GIT_USER_EMAIL"
fi
git config --global init.defaultBranch "${GIT_DEFAULT_BRANCH:-main}"
git config --global --replace-all safe.directory '*'

# GitHub: Token aus der .env fuer gh und git nutzbar machen
if [ -z "${GH_TOKEN:-}" ] && [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
  export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"
fi

if [ -n "${GH_TOKEN:-}" ]; then
  # git clone/push ueber HTTPS authentifiziert sich ueber die GitHub CLI
  host="${GH_HOST:-github.com}"
  git config --global --unset-all "credential.https://${host}.helper" 2>/dev/null || true
  git config --global --add "credential.https://${host}.helper" ""
  git config --global --add "credential.https://${host}.helper" "!gh auth git-credential"
  git config --global credential.https://gist.github.com.helper "!gh auth git-credential"
fi

exec "$@"
