# Entwicklungs-Sandbox mit opencode

Ein abgeschotteter Docker-Container zum Programmieren. Innen laufen zwei
Coding-Agenten nebeneinander: [opencode](https://opencode.ai) und
[Claude Code](https://code.claude.com). Der Quellcode liegt weiterhin auf dem
Mac, nur die Werkzeugkette und die Agenten laufen im Container.

## Struktur

```
sandbox/
├── sandbox.sh              Start- und Steuerskript (macOS, Linux)
├── sandbox.ps1             dasselbe fuer Windows (PowerShell)
├── sandbox.bat             Starthilfe fuer die Eingabeaufforderung
├── compose.yaml            Dienstdefinition, Mounts, Volumes, Grenzen
├── .env                    persoenliche Einstellungen (nicht ins Git)
├── .env.example            Vorlage mit allen Schaltern
├── docker/
│   ├── Dockerfile          Image: Debian + Go/Node/Python + opencode
│   ├── entrypoint.sh       Startlogik (Git-Identitaet, Verzeichnisse)
│   └── bashrc.d/sandbox.sh Begruessung und Prompt im Container
├── .gitattributes          haelt LF-Zeilenenden fuer den Container
├── config/
│   ├── commands/           die geteilten Befehle - eine Quelle fuer beide
│   │   ├── plan-item.md
│   │   └── implement-item.md
│   ├── skills/             duenne SKILL.md-Huellen auf dieselben Texte
│   ├── opencode/opencode.json   Konfiguration inkl. GitHub-MCP-Server
│   └── claude/settings.json Vorlage fuer Claude Code
└── workspace/              Projekte -> im Container unter /work
```

## Erste Schritte

1. Docker Desktop starten.
2. In `.env` den `ANTHROPIC_API_KEY` eintragen (oder leer lassen, siehe unten).
3. Sandbox starten:

macOS und Linux:

```bash
cd ~/Desktop/sandbox
./sandbox.sh
```

Windows (PowerShell):

```powershell
cd $HOME\Desktop\sandbox
.\sandbox.ps1
```

In der Eingabeaufforderung oder per Doppelklick tut es `sandbox.bat`; die Datei
reicht alles an `sandbox.ps1` weiter und umgeht die Ausfuehrungsrichtlinie.

Beim ersten Aufruf wird das Image gebaut (einige Minuten). Danach landet man in
einer Shell im Container, im Verzeichnis `/work`. Dort:

```bash
opencode
```

## Anmeldung bei Claude

Zwei Wege, beide sind vorbereitet:

* **API-Key**: `ANTHROPIC_API_KEY=sk-ant-...` in die `.env`. Der Schluessel wird
  als Umgebungsvariable in den Container gereicht und liegt nicht im Image.
* **Anmeldung im TUI**: `.env`-Eintrag leer lassen, `opencode` starten und dort
  `/connect` eingeben. Die Zugangsdaten landen in `~/.local/share/opencode/`
  im Volume `opencode-data` und ueberleben Neustarts und Rebuilds.
  Oeffnet der Anmeldevorgang einen Browser-Link, diesen auf dem Mac oeffnen und
  den Code zurueck in den Container kopieren.

Modellauswahl im TUI mit `/models`.

## GitHub anbinden

Im Image stecken zwei Wege zu GitHub, beide nutzen dasselbe Token aus der `.env`:

* **GitHub CLI (`gh`)** für Checkout, Branches, Push und Pull Requests. Der
  Git-Credential-Helper wird beim Start gesetzt, `git clone`/`git push` über
  HTTPS funktionieren damit ohne weiteres Zutun.
* **GitHub-MCP-Server** (`github-mcp-server`, im Image als Binary) für alles,
  was opencode selbst über Werkzeuge erledigt: Issues, Pull Requests, Labels,
  Reviews und das Project-Board.

### Token anlegen

In der `.env` eintragen:

```
GITHUB_PERSONAL_ACCESS_TOKEN=ghp_...
```

Nötige Rechte:

| Tokenart      | Rechte                                                                 |
|---------------|------------------------------------------------------------------------|
| Classic       | `repo`, `read:org`, `project`                                           |
| Fine-grained  | Repository: Contents, Issues, Pull requests (je Lesen und Schreiben); Organization: Projects (Lesen und Schreiben) |

Ohne `project` bzw. das Projects-Recht bleiben die Board-Werkzeuge stumm.

### Werkzeuggruppen

`GITHUB_TOOLSETS` in der `.env` steuert, was der MCP-Server anbietet. Voreinstellung:

```
GITHUB_TOOLSETS=context,repos,issues,pull_requests,labels,users,projects
```

`all` schaltet alles frei, `GITHUB_READ_ONLY=1` macht den Server schreibgeschützt.

### Lokal oder entfernt

Voreingestellt läuft der MCP-Server **lokal im Container** — kein Docker-Socket,
kein zusätzlicher Dienst. Wer stattdessen den von GitHub gehosteten Server nutzen
will, dreht in `config/opencode/opencode.json` die beiden `enabled`-Schalter um:
`github` auf `false`, `github-remote` auf `true`. Danach `./sandbox.sh restart`.

### Project-Board (optional, derzeit ungenutzt)

```
GITHUB_PROJECT_OWNER=meine-orga
GITHUB_PROJECT_NUMBER=7
GITHUB_PROJECT_STATUS_FIELD=Status
GITHUB_STATUS_PLANNED="Ready"
GITHUB_STATUS_IN_PROGRESS="In Progress"
GITHUB_STATUS_IN_REVIEW="In Review"
```

Owner und Nummer stehen in der Board-URL:
`github.com/orgs/<owner>/projects/<nummer>`. Die Statuswerte müssen genau so
heißen wie die Spalten auf dem Board.

Die mitgelieferten Befehle arbeiten derzeit nur mit Issues und werten diese
Variablen nicht aus - sie stehen bereit, falls spaeter ein Board dazukommt.

## Die beiden Agenten

| Agent       | Start im Container | Anmeldung                          | Ablage im Container |
|-------------|--------------------|------------------------------------|---------------------|
| opencode    | `opencode`         | `/connect` im TUI oder `ANTHROPIC_API_KEY` | `~/.config/opencode`, `~/.local/share/opencode` |
| Claude Code | `claude`           | `/login` im TUI oder `ANTHROPIC_API_KEY` | `~/.claude` (`CLAUDE_CONFIG_DIR`) |

Von aussen geht es auch direkt:

```bash
./sandbox.sh opencode
./sandbox.sh claude
./sandbox.sh auth claude    # Anmeldung, je Agent
```

Welcher Agent bei einem blanken `./sandbox.sh` startet, steht in der `.env`:
`DEFAULT_ENTRY=shell | opencode | claude`. Voreingestellt ist `shell`, damit
beide gleichberechtigt zur Verfuegung stehen.

Einzeln abschalten laesst sich jeder ueber `INSTALL_OPENCODE` und
`INSTALL_CLAUDE` in der `.env`; danach `./sandbox.sh rebuild`.

### Anmeldung ohne Browser im Container

Beide melden sich normalerweise ueber eine Rueckleitung an `localhost` an.
Kommt die im Container nicht an, zeigt der Browser auf dem Mac einen Code, den
man im TUI einfuegt.

Die Anmeldedaten liegen in Docker-Volumes (`opencode-data`, `claude-data`),
nicht auf dem Mac. Sie ueberstehen Neustarts und `rebuild`, verschwinden aber
bei `./sandbox.sh destroy`.

### Konfigurationsvorlage fuer Claude Code

`config/claude/settings.json` ist eine Vorlage. Da im selben Verzeichnis auch
die Anmeldedaten liegen, wird sie nicht dauerhaft eingehaengt, sondern beim
ersten Start hineinkopiert. Nach einer Aenderung:

```bash
./sandbox.sh reseed
```

Oder `SEED_OVERWRITE=1` in der `.env`, dann geschieht das bei jedem Start.

### GitHub-MCP bei beiden

opencode bekommt den GitHub-MCP-Server ueber seine Konfiguration mitgeliefert.
Bei Claude Code wird er einmalig registriert:

```bash
./sandbox.sh setup-mcp
```


## Geteilte Befehle

Die Befehle liegen an einer Stelle: `config/commands/<name>.md`. Von dort
werden sie dorthin eingehaengt, wo beide Agenten nachsehen:

| Agent       | Eingehaengt nach              | Aufruf          |
|-------------|-------------------------------|-----------------|
| opencode    | `~/.config/opencode/commands` | `/plan-item 42` |
| Claude Code | `~/.claude/commands`          | `/plan-item 42` |

Eine neue Datei in `config/commands/` steht damit sofort in beiden bereit - kein
Kopieren, kein Rebuild, nur die jeweilige CLI neu starten. Die Verzeichnisse
sind nur lesend eingehaengt; geaendert wird auf dem Host.

Zusaetzlich liegt zu jedem Befehl eine Huelle unter
`config/skills/<name>/SKILL.md`, eingehaengt nach `~/.claude/skills` - das liest
auch opencode (Claude-kompatibel). Sie enthaelt keinen zweiten Text, sondern
verweist auf dieselbe Datei unter `/opt/agent-commands/`. Dadurch koennen die
Agenten den Befehl auch von sich aus heranziehen, wenn die Aufgabe passt, statt
nur auf das getippte `/plan-item` zu reagieren.

### Was beim Schreiben eigener Befehle zu beachten ist

Damit eine Datei in beiden funktioniert:

* **Frontmatter** nur mit `description`. `agent:` kennt nur opencode,
  `allowed-tools:` und `argument-hint:` nur Claude Code.
* **Argumente** mit `$ARGUMENTS`, `$1`, `$2` - das koennen beide.
* Die mitgelieferten Befehle ermitteln ihren Kontext in einem "Schritt 0" per
  Kommandoblock, den der Agent selbst ausfuehrt. Shell-Einschuebe der Form
  ``!`git status` `` koennten beide zwar auch direkt, die explizite Variante
  bleibt aber lesbarer und unabhaengig von der jeweiligen CLI-Version.

### Eine Randnotiz

Claude Code fuehrt Befehle und Skills zusammen, opencode haelt beides getrennt.
Deshalb der doppelte Weg: die getippten Befehle funktionieren heute in beiden,
die Skill-Huellen sind der Weg nach vorn - und beide zeigen auf denselben Text.


## Arbeiten mit Issues

```bash
./sandbox.sh clone meine-orga/mein-repo   # Repo nach /work holen
./sandbox.sh                              # in die Sandbox
cd /work/mein-repo
opencode        # oder: claude
```

Im TUI:

```
/plan-item 42
```

Der Agent liest Issue #42 samt Kommentaren, sieht sich den Code an und schreibt
einen Plan als Kommentar ins Issue. Dessen erste Zeile lautet
`## Umsetzungsplan` - daran findet ihn der naechste Schritt wieder. Code aendert
er dabei nicht.

```
/implement-item 42
```

Der Agent holt den Plan aus dem Issue, legt `feature/42-<slug>` an, arbeitet die
Schritte ab, laesst Tests und Linter laufen, committet mit `Refs #42` und
oeffnet einen Pull Request mit `Closes #42`.

Beide Befehle liegen als Textdateien in `config/commands/` und gelten fuer beide
Agenten gleichermassen - siehe [Geteilte Befehle](#geteilte-befehle).
Aenderungen wirken beim naechsten Start der jeweiligen CLI, ohne Rebuild.

### Project-Boards

Die Befehle arbeiten bewusst nur mit Issues. Die Board-Variablen
(`GITHUB_PROJECT_OWNER`, `GITHUB_PROJECT_NUMBER`, `GITHUB_STATUS_*`) stehen
weiterhin in der `.env` und werden in den Container gereicht, aktuell aber von
keinem Befehl ausgewertet. Das Toolset `projects` ist beim MCP-Server ebenfalls
noch aktiv - die Werkzeuge sind also da, falls spaeter doch ein Board dazukommt.

## Taeglicher Gebrauch

```bash
./sandbox.sh            # hineinspringen  (Windows: .\sandbox.ps1)
./sandbox.sh opencode   # direkt in die opencode-Oberflaeche
./sandbox.sh run go test ./...
./sandbox.sh clone owner/repo
./sandbox.sh gh pr list
./sandbox.sh status
./sandbox.sh doctor      # Selbsttest: Docker, Image, Werkzeuge im Container
./sandbox.sh setup-mcp   # GitHub-MCP bei Claude Code eintragen
./sandbox.sh reseed      # Vorlagen aus config/ neu in den Container kopieren
./sandbox.sh stop
./sandbox.sh update     # opencode und Basis-Image aktualisieren
./sandbox.sh help
```

Soll `./sandbox.sh` ohne Argument sofort opencode starten: in der `.env`
`DEFAULT_ENTRY=opencode` setzen.

## Projekte

Standardmaessig wird `./workspace` nach `/work` gemountet. Wer seine Projekte
woanders liegen hat, setzt in der `.env` z. B.:

```
WORKSPACE_DIR=/Users/...
```

Nur dieses Verzeichnis ist fuer den Container sichtbar - das ist der eigentliche
Sandbox-Effekt. Alles ausserhalb bleibt unerreichbar.

## Was im Image steckt

Debian 13 "Trixie" (slim), Go, Node.js 24, Python 3, dazu git, GitHub CLI, ripgrep, fd,
jq, tmux, build-essential, der GitHub-MCP-Server sowie opencode und
Claude Code. Rust laesst sich mit `INSTALL_RUST=true`
zuschalten, einzelne Toolchains mit `INSTALL_NODE=false` usw. abschalten.
Zusaetzliche Debian-Pakete kommen ueber `EXTRA_APT_PACKAGES` ins Image.
Nach jeder Aenderung an diesen Schaltern: `./sandbox.sh rebuild`.

## Windows

`sandbox.ps1` kann dasselbe wie `sandbox.sh` - dieselben Unterbefehle, dieselbe
`.env`, dieselbe `compose.yaml`. Zwei Dinge sind zu beachten:

* **Ausfuehrungsrichtlinie.** PowerShell blockiert unsignierte Skripte in der
  Voreinstellung. Entweder `sandbox.bat` benutzen (ruft PowerShell mit
  `-ExecutionPolicy Bypass` auf) oder einmalig setzen:

  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
  ```

* **Zeilenenden.** Die Dateien im Container (`entrypoint.sh`, `Dockerfile`)
  muessen LF behalten. Die mitgelieferte `.gitattributes` sorgt dafuer, falls der
  Ordner in ein Git-Repository wandert. Wer die Dateien von Hand bearbeitet:
  Editor auf LF stellen, sonst scheitert der Containerstart mit einer Meldung
  wie `exec format error`.

Pfadangaben in der `.env` duerfen Windows-Schreibweise verwenden, etwa
`WORKSPACE_DIR=C:/Users/.../Projekte` (Schraegstriche oder doppelte Backslashes).
Der auskommentierte SSH-Mount in der `compose.yaml` heisst unter Windows
`${USERPROFILE}/.ssh` statt `${HOME}/.ssh`.


## Abgrenzung und Grenzen der Isolation

* Der Container laeuft als unprivilegierter Nutzer `dev` (UID 1000).
* Sichtbar ist nur `WORKSPACE_DIR` sowie `config/opencode`.
* CPU- und Speichergrenze stehen in der `.env` (`SANDBOX_CPUS`, `SANDBOX_MEMORY`).
* Die Ports 3000, 5173 und 8000 sind nur an `127.0.0.1` gebunden.
* `sudo` ist im Container ohne Passwort moeglich (`ENABLE_SUDO=false` schaltet
  das ab). Das betrifft nur den Container, nicht den Mac.
* Der Container hat vollen ausgehenden Netzzugang - er wird fuer die
  Claude-API und Paketinstallationen gebraucht.
* Kein Docker-Socket ist eingehaengt: aus der Sandbox heraus lassen sich keine
  Container auf dem Mac starten.
* `ANTHROPIC_API_KEY` liegt nur in der `.env` und als Umgebungsvariable im
  laufenden Container. Wer stattdessen die Abo-Anmeldung nutzt, hat gar keinen
  Schluessel auf der Platte - die Sitzungstoken liegen dann in den Volumes.
* Das GitHub-Token liegt nur in der `.env` und als Umgebungsvariable im
  laufenden Container, nicht im Image. Es reicht so weit, wie seine Rechte
  reichen - fuer eine engere Grenze ein fine-grained Token auf die betroffenen
  Repositories ausstellen.
