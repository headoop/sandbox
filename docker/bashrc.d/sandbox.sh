# Begruessung + Komfort in der Sandbox
export PS1='\[\e[32m\]sandbox\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
alias ll='ls -alF --color=auto'
alias ls='ls --color=auto'

# eza ersetzt ls, sobald es im Image vorhanden ist.
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons=auto --color=auto --group-directories-first'
  alias l='eza --group --group-directories-first --icons=auto --color=auto --long --git --git-ignore'
  # alias ll='eza -alF --git'
  alias ll='eza --group --group-directories-first --icons=auto --color=auto --long --git --all'
  alias la='eza --group-directories-first --color=auto --icons=auto -a'
fi

# Starship ersetzt den Prompt oben, wenn das Image mit INSTALL_STARSHIP=true
# gebaut wurde. Nur in interaktiven Shells, nicht bei "bash -lc".
if [[ $- == *i* ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

# fzf-Tastenkuerzel (Ctrl-R Verlauf, Ctrl-T Dateien, Alt-C Verzeichnis) und
# **<Tab>-Vervollstaendigung. Die Beispieldateien unter /usr/share/doc fehlen
# im slim-Image, darum liefert fzf das Skript selbst.
if [[ $- == *i* ]] && command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash)"
fi

if [ -z "${GH_TOKEN:-}" ] && [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
  export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"
fi

if [ -z "${SANDBOX_MOTD_SHOWN:-}" ] && [ -t 1 ]; then
  export SANDBOX_MOTD_SHOWN=1
  _have() { command -v "$1" >/dev/null 2>&1; }
  echo
  echo "  Entwicklungs-Sandbox  --  Projekte liegen unter /work"
  echo
  _have opencode && echo "  opencode             opencode-TUI"
  _have claude && echo "  claude               Claude Code"
  echo "  gh repo clone O/R    Repository nach /work holen"
  echo
  echo "  Gemeinsame Befehle in allen dreien:"
  echo "    /plan-item <Nr>      Item vom Board planen"
  echo "    /implement-item <Nr> Item umsetzen und PR anlegen"
  echo
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "  Anthropic:  API-Key gesetzt"
  else
    echo "  Anthropic:  kein Key - opencode: /connect, claude: /login"
  fi
  if [ -n "${GH_TOKEN:-}" ]; then
    echo "  GitHub:     Token gesetzt (gh + MCP-Server einsatzbereit)"
  else
    echo "  GitHub:     kein Token -> GITHUB_PERSONAL_ACCESS_TOKEN in .env"
  fi
  echo
  unset -f _have
fi
