#!/usr/bin/env bash
# ------------------------------------------------------------------
# Entwicklungs-Sandbox: Start-/Steuerskript
#   ./sandbox.sh            in die Sandbox springen
#   ./sandbox.sh help       alle Unterbefehle
# ------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SERVICE="sandbox"

# Hinweis: hier wird bewusst ueberall "docker compose" ausgeschrieben.
# Eine Abkuerzung als Shell-Funktion waere in Verbindung mit "exec" eine
# Falle - exec umgeht Funktionen und sucht ein gleichnamiges Programm.

msg()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mFehler:\033[0m %s\n' "$*" >&2; exit 1; }

check_docker() {
  command -v docker >/dev/null 2>&1 || die "Docker ist nicht installiert oder nicht im PATH."
  docker info >/dev/null 2>&1 || die "Docker laeuft nicht - bitte den Docker-Daemon bzw. Docker Desktop starten."
  docker compose version >/dev/null 2>&1 || die "Es wird 'docker compose' (Compose v2) benoetigt."
}

ensure_env() {
  if [ ! -f .env ]; then
    [ -f .env.example ] || die ".env und .env.example fehlen."
    cp .env.example .env
    msg ".env aus .env.example erzeugt - bitte bei Gelegenheit anpassen."
  fi
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
  mkdir -p "${WORKSPACE_DIR:-./workspace}"
}

image_name() { echo "${SANDBOX_IMAGE:-sandbox-opencode:local}"; }

image_exists() { docker image inspect "$(image_name)" >/dev/null 2>&1; }

container_running() {
  local cid
  cid="$(docker compose ps -q "$SERVICE" 2>/dev/null || true)"
  [ -n "$cid" ] && [ "$(docker inspect -f '{{.State.Running}}' "$cid" 2>/dev/null)" = "true" ]
}

ensure_up() {
  if ! image_exists; then
    msg "Image wird gebaut - das dauert beim ersten Mal einige Minuten."
    docker compose build
  fi
  if ! container_running; then
    msg "Container wird gestartet ..."
    docker compose up -d
  fi
}

enter_shell() {
  ensure_up
  exec docker compose exec "$SERVICE" bash -l
}

enter_opencode() {
  ensure_up
  exec docker compose exec "$SERVICE" opencode
}

enter_claude() {
  ensure_up
  exec docker compose exec "$SERVICE" claude "$@"
}

usage() {
  cat <<'USAGE'
Verwendung: ./sandbox.sh [Befehl]

  (ohne Befehl)   Sandbox starten und hineinspringen (DEFAULT_ENTRY aus .env)
  shell           Shell im Container oeffnen
  opencode        direkt in opencode springen
  claude          direkt in Claude Code springen
  auth <Agent>    Anmeldung: auth opencode | auth claude
  run <Befehl>    einen Befehl im Container ausfuehren
  clone <O/R>     Repository nach /work klonen
  gh <Argumente>  GitHub CLI im Container aufrufen
  build           Image bauen (nutzt den Cache)
  rebuild         Image komplett neu bauen und Container ersetzen
  update          Basis-Images und opencode aktualisieren
  start | stop    Container starten / anhalten
  restart         Container neu starten
  status          Zustand von Image, Container und Volumes
  logs            Containerausgaben anzeigen
  reseed          Vorlagen aus config/ erneut in den Container kopieren
  setup-mcp       GitHub-MCP-Server bei Claude Code registrieren
  doctor          Selbsttest: Docker, Image, Container, Werkzeuge
  down            Container entfernen (Projekte und Anmeldung bleiben)
  destroy         Container UND Volumes entfernen (Anmeldung geht verloren)
  help            diese Hilfe
USAGE
}

check_docker
ensure_env

cmd="${1:-}"
[ $# -gt 0 ] && shift || true

case "$cmd" in
  ""|enter)
    case "${DEFAULT_ENTRY:-shell}" in
      opencode) enter_opencode ;;
      claude)   enter_claude ;;
      *)        enter_shell ;;
    esac
    ;;
  shell|sh|bash)    enter_shell ;;
  opencode|oc)      enter_opencode ;;
  claude|cc)        enter_claude "$@" ;;
  auth|login)
    ensure_up
    target="${1:-}"
    [ $# -gt 0 ] && shift || true
    case "$target" in
      opencode)
        msg "Im TUI /connect eingeben, Anthropic auswaehlen."
        exec docker compose exec "$SERVICE" opencode
        ;;
      claude)
        msg "Im TUI /login eingeben. Kommt die Rueckleitung nicht an, den Code aus dem Browser einfuegen."
        exec docker compose exec "$SERVICE" claude "$@"
        ;;
      *)
        cat <<'AUTH'
Anmeldung je Agent:
  ./sandbox.sh auth opencode   opencode starten, dort /connect
  ./sandbox.sh auth claude     Claude Code starten, dort /login

Alternativ den Schluessel in die .env eintragen:
  ANTHROPIC_API_KEY   gilt fuer opencode und Claude Code
AUTH
        ;;
    esac
    ;;
  reseed)
    ensure_up
    docker compose exec "$SERVICE" bash -lc '
      set -e
      install -m 0600 /opt/seed/claude/settings.json "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
    '
    msg "Vorlagen aus config/ neu in den Container kopiert."
    ;;
  setup-mcp)
    ensure_up
    docker compose exec "$SERVICE" bash -lc '
      if claude mcp get github >/dev/null 2>&1; then
        echo "GitHub-MCP-Server ist bei Claude Code bereits eingetragen."
      else
        claude mcp add github --scope user -- github-mcp-server stdio
      fi
    '
    ;;
  run|exec)
    [ $# -gt 0 ] || die "Kein Befehl angegeben. Beispiel: ./sandbox.sh run go version"
    ensure_up
    exec docker compose exec "$SERVICE" bash -lc "$*"
    ;;
  clone)
    [ $# -gt 0 ] || die "Beispiel: ./sandbox.sh clone octocat/hello-world"
    ensure_up
    docker compose exec "$SERVICE" bash -lc 'cd /work && gh repo clone "$1"' _ "$1"
    msg "Geklont nach ${WORKSPACE_DIR:-./workspace}."
    ;;
  gh)
    ensure_up
    exec docker compose exec "$SERVICE" gh "$@"
    ;;
  build)
    docker compose build "$@"
    msg "Fertig. Mit ./sandbox.sh hineinspringen."
    ;;
  rebuild)
    docker compose build --pull --no-cache "$@"
    docker compose up -d --force-recreate
    msg "Image neu gebaut und Container ersetzt."
    ;;
  update)
    docker compose build --pull "$@"
    docker compose up -d --force-recreate
    msg "Aktualisiert."
    ;;
  start|up)   docker compose up -d; msg "Container laeuft." ;;
  stop)       docker compose stop; msg "Container angehalten." ;;
  restart)    docker compose restart; msg "Container neu gestartet." ;;
  logs)       docker compose logs -f "$@" ;;
  status)
    echo "Image:      $(image_name) $(image_exists && echo '(vorhanden)' || echo '(noch nicht gebaut)')"
    echo "Projekte:   ${WORKSPACE_DIR:-./workspace}  ->  /work"
    echo "Anthropic:  $([ -n "${ANTHROPIC_API_KEY:-}" ] && echo 'Key in .env' || echo 'kein Key (Anmeldung im jeweiligen TUI)')"
    echo "GitHub:     $([ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ] && echo "Token gesetzt, Toolsets: ${GITHUB_TOOLSETS:-Standard}" || echo 'kein Token in .env')"
    echo "Board:      ${GITHUB_PROJECT_OWNER:-(nicht gesetzt)} / Projekt ${GITHUB_PROJECT_NUMBER:-(nicht gesetzt)}"
    echo
    docker compose ps
    echo
    docker volume ls --filter "label=com.docker.compose.project=${SANDBOX_NAME:-sandbox}"
    ;;
  doctor)
    echo "Docker:     $(docker --version)"
    echo "Compose:    $(docker compose version --short 2>/dev/null || echo '?')"
    echo "Image:      $(image_name) $(image_exists && echo 'vorhanden' || echo 'fehlt')"
    echo "Container:  $(container_running && echo 'laeuft' || echo 'laeuft nicht')"
    if container_running; then
      echo
      docker compose exec -T "$SERVICE" bash -lc '
        echo "  opencode:          $(opencode --version 2>/dev/null || echo FEHLT)"
        echo "  claude:            $(claude --version 2>/dev/null || echo FEHLT)"
        echo "  github-mcp-server: $(github-mcp-server --version 2>/dev/null || echo vorhanden/ohne-Versionsausgabe)"
        echo "  gh:                $(gh --version 2>/dev/null | head -1 || echo FEHLT)"
        echo "  go:                $(go version 2>/dev/null || echo nicht-installiert)"
        echo "  node:              $(node --version 2>/dev/null || echo nicht-installiert)"
        echo "  python:            $(python --version 2>/dev/null || echo nicht-installiert)"
        echo "  /work:             $(ls -1 /work 2>/dev/null | wc -l | tr -d " ") Eintraege"
        echo "  Befehle (Quelle):  $(ls -1 /opt/agent-commands/*.md 2>/dev/null | wc -l | tr -d " ")"
        echo "    -> opencode:     $(ls -1 $HOME/.config/opencode/commands/*.md 2>/dev/null | wc -l | tr -d " ")"
        echo "    -> claude:       $(ls -1 $HOME/.claude/commands/*.md 2>/dev/null | wc -l | tr -d " ")"
        echo "  Skills:            $(ls -1d $HOME/.claude/skills/*/ 2>/dev/null | wc -l | tr -d " ")"
        echo "  GitHub-Token:      $([ -n "${GH_TOKEN:-}" ] && echo gesetzt || echo fehlt)"
        echo "  Anthropic-Key:     $([ -n "${ANTHROPIC_API_KEY:-}" ] && echo gesetzt || echo fehlt)"
        echo "  Claude-Anmeldung:  $([ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json" ] && echo vorhanden || echo fehlt)"
      '
    else
      warn "Fuer den vollstaendigen Test: ./sandbox.sh start"
    fi
    ;;
  down)
    docker compose down
    msg "Container entfernt. Projekte und Anmeldedaten bleiben erhalten."
    ;;
  destroy)
    warn "Das loescht auch die Anmeldungen von opencode, Claude Code und gh sowie alle Caches."
    read -r -p "Wirklich? [j/N] " a
    case "$a" in j|J|y|Y) docker compose down -v; msg "Alles entfernt." ;; *) msg "Abgebrochen." ;; esac
    ;;
  help|-h|--help) usage ;;
  *) die "Unbekannter Befehl: $cmd  (./sandbox.sh help)" ;;
esac
