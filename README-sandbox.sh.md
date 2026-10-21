# sandbox.sh – Erklärung

`sandbox.sh` ist das Start- und Steuerskript der Docker-basierten Entwicklungs-Sandbox. Es ist ein Wrapper um `docker compose`, mit dem du per Einzeiler in einen Container springst, in dem opencode, Claude Code, die GitHub CLI (`gh`) und der GitHub-MCP-Server bereitstehen.

```bash
./sandbox.sh          # Sandbox starten und hineinspringen
./sandbox.sh help     # alle Unterbefehle anzeigen
```

## Ablauf bei jedem Aufruf

1. **Vorbereitung:** `set -euo pipefail` lässt das Skript bei Fehlern, ungesetzten Variablen und fehlgeschlagenen Pipes abbrechen. Danach wechselt es in sein eigenes Verzeichnis, damit `docker compose` die `compose.yaml` findet, egal von wo aus du es aufrufst.
2. **`check_docker`:** Prüft drei Dinge: Ist `docker` installiert? Läuft der Docker-Daemon bzw. Docker Desktop? Ist Compose v2 (`docker compose`) vorhanden?
3. **`ensure_env`:** Fehlt die `.env`, wird sie aus `.env.example` erzeugt. Anschließend wird sie mit `set -a` geladen, dadurch werden alle Variablen exportiert. Zum Schluss legt die Funktion das Workspace-Verzeichnis an (`WORKSPACE_DIR`, Standard `./workspace`).
4. **Befehl auswerten:** Das erste Argument wählt den Unterbefehl aus. Die übrigen Argumente werden an diesen weitergereicht.

## Hilfsfunktionen

| Funktion | Zweck |
|---|---|
| `msg` / `warn` / `die` | Farbige Ausgaben (grün, gelb, rot). `die` beendet das Skript mit Exit-Code 1. |
| `image_name` | Name des Images aus `SANDBOX_IMAGE`, Standard `sandbox-opencode:local`. |
| `image_exists` | Prüft per `docker image inspect`, ob das Image schon gebaut ist. |
| `container_running` | Holt die Container-ID über `docker compose ps -q` und prüft mit `docker inspect`, ob der Container tatsächlich läuft. |
| `ensure_up` | „Lazy-Start“: Baut das Image, falls es fehlt, und startet den Container, falls er nicht läuft. Fast alle Einstiegsbefehle rufen diese Funktion zuerst auf. |
| `enter_shell` / `enter_opencode` / `enter_claude` | Rufen `ensure_up` auf und ersetzen den Skriptprozess dann per `exec` durch die Sitzung im Container. |

## Unterbefehle

### Einstieg

| Befehl | Kurzform | Wirkung |
|---|---|---|
| *(ohne)* / `enter` | – | Springt je nach `DEFAULT_ENTRY` in der `.env` in `shell`, `opencode` oder `claude`. Standard ist `shell`. |
| `shell` | `sh`, `bash` | Login-Shell (`bash -l`) im Container. |
| `opencode` | `oc` | Startet opencode direkt. |
| `claude [args]` | `cc` | Startet Claude Code und reicht weitere Argumente durch. |

### Anmeldung

| Befehl | Wirkung |
|---|---|
| `auth opencode` | Startet opencode. Dort `/connect` eingeben und Anthropic auswählen. |
| `auth claude` | Startet Claude Code. Dort `/login` eingeben. Wenn die Rückleitung nicht ankommt, den Code aus dem Browser einfügen. |
| `auth` | Zeigt die Optionen an, darunter als Alternative `ANTHROPIC_API_KEY` in der `.env`. |

`login` ist ein Alias für `auth`.

### Ausführen im Container

| Befehl | Wirkung |
|---|---|
| `run <Befehl>` / `exec` | Führt einen beliebigen Befehl in einer Login-Shell aus, z. B. `./sandbox.sh run go version`. |
| `gh <Argumente>` | Ruft die GitHub CLI im Container auf. |
| `clone <owner/repo>` | Klont ein Repository per `gh repo clone` nach `/work`. Auf dem Host landet es im Workspace-Verzeichnis. |

### Konfiguration

| Befehl | Wirkung |
|---|---|
| `reseed` | Kopiert die Vorlage `settings.json` aus `/opt/seed/claude` (also `config/` auf dem Host) erneut nach `~/.claude`. |
| `setup-mcp` | Registriert den GitHub-MCP-Server bei Claude Code (`--scope user`), sofern er noch nicht eingetragen ist. |

### Image

| Befehl | Wirkung |
|---|---|
| `build` | Baut das Image mit Cache. |
| `rebuild` | Baut komplett neu (`--pull --no-cache`) und ersetzt den Container (`--force-recreate`). |
| `update` | Zieht neue Basis-Images (`--pull`), baut mit Cache und ersetzt den Container. |

### Lebenszyklus

| Befehl | Wirkung |
|---|---|
| `start` / `up` | Startet den Container im Hintergrund. Hat sich die `.env` geändert, erzeugt Compose den Container dabei neu. |
| `stop` | Hält den Container an. |
| `restart` | Startet den bestehenden Container neu. Änderungen an der `.env` (z. B. `GIT_USER_NAME`/`GIT_USER_EMAIL`) werden dabei **nicht** übernommen, dafür `start` verwenden. |
| `logs` | Zeigt die Containerausgaben fortlaufend an (`-f`). |
| `down` | Entfernt den Container. Projekte und Anmeldedaten in den Volumes bleiben erhalten. |
| `destroy` | Entfernt den Container **und die Volumes** (`down -v`), vorher kommt eine Rückfrage `[j/N]`. Dabei gehen die Anmeldungen von opencode, Claude Code und gh sowie alle Caches verloren. |

### Diagnose

| Befehl | Wirkung |
|---|---|
| `status` | Zeigt Image, Workspace-Zuordnung, ob ein Anthropic-Key und ein GitHub-Token gesetzt sind (nur ja/nein, keine Werte), das Projekt-Board, `docker compose ps` und die zugehörigen Volumes. |
| `doctor` | Selbsttest: Versionen von Docker und Compose, Image- und Containerzustand. Läuft der Container, kommen im Container hinzu: die Versionen von opencode, claude, github-mcp-server, gh, go, node und python, die Einträge in `/work`, die Anzahl der Commands und Skills sowie der Zustand von Token, Key und Claude-Anmeldung. |
| `help` / `-h` / `--help` | Zeigt die Hilfe an. |

Bei einem unbekannten Befehl bricht das Skript mit einer Fehlermeldung ab.

## Bemerkenswerte Details

- **Kein Alias für `docker compose`:** Eine Abkürzung als Shell-Funktion würde zusammen mit `exec` nicht funktionieren, weil `exec` nur echte Programme startet und Funktionen ignoriert. Deshalb steht überall `docker compose` ausgeschrieben.
- **`exec` für interaktive Sitzungen:** Der Skriptprozess wird durch die Container-Sitzung ersetzt. Signale und Exit-Codes kommen so direkt bei dir an, und es bleibt keine überflüssige Bash im Hintergrund hängen.
- **Sichere Argumentübergabe bei `clone`:** `bash -lc '… "$1"' _ "$1"` reicht den Repo-Namen als Positionsparameter weiter, statt ihn in den Befehlsstring einzubauen. So wird nichts falsch interpretiert oder eingeschleust. `run` setzt dagegen absichtlich `"$*"` als Befehlsstring ein, weil dort beliebige Shell-Befehle gewollt sind.
- **`[ $# -gt 0 ] && shift || true`:** Das `|| true` verhindert, dass `set -e` das Skript beendet, wenn keine Argumente mehr übrig sind.
- **`doctor` nutzt `exec -T`:** Es wird kein TTY zugewiesen, weil nur Text ausgegeben wird. So funktioniert der Befehl auch in Pipes und in CI.
- **Persistenz:** Die Anmeldedaten liegen in Docker-Volumes (`opencode-data`, `claude-data`, `gh-config`), die Caches in eigenen Volumes. Deshalb überleben sie `down`, `rebuild` und `update`. Nur `destroy` entfernt sie.
