#Requires -Version 5.1
<#
    Entwicklungs-Sandbox: Start- und Steuerskript fuer Windows
      .\sandbox.ps1            in die Sandbox springen
      .\sandbox.ps1 help       alle Unterbefehle
    Gleicher Funktionsumfang wie sandbox.sh unter macOS und Linux.
#>

param([string]$Command = '')

$Rest = @($args)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$Service = 'sandbox'
$script:DotEnv = @{}

# ------------------------------------------------------------------ Ausgabe
function Write-Msg  { param([string]$Text) Write-Host '==> ' -ForegroundColor Green  -NoNewline; Write-Host $Text }
function Write-Warn { param([string]$Text) Write-Host '==> ' -ForegroundColor Yellow -NoNewline; Write-Host $Text }
function Stop-WithError {
    param([string]$Text)
    Write-Host 'Fehler: ' -ForegroundColor Red -NoNewline
    Write-Host $Text
    exit 1
}

# ------------------------------------------------------------------ Docker
function Test-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Stop-WithError 'Docker ist nicht installiert oder nicht im PATH.'
    }
    & docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError 'Docker laeuft nicht - bitte Docker Desktop starten.'
    }
    & docker compose version *> $null
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "Es wird 'docker compose' (Compose v2) benoetigt."
    }
}

# ------------------------------------------------------------------ .env
function Import-DotEnv {
    if (-not (Test-Path -LiteralPath '.env')) {
        if (-not (Test-Path -LiteralPath '.env.example')) {
            Stop-WithError '.env und .env.example fehlen.'
        }
        Copy-Item -LiteralPath '.env.example' -Destination '.env'
        Write-Msg '.env aus .env.example erzeugt - bitte bei Gelegenheit anpassen.'
    }

    $script:DotEnv = @{}
    foreach ($line in (Get-Content -LiteralPath '.env')) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        $pos = $trimmed.IndexOf('=')
        if ($pos -lt 1) { continue }
        $key   = $trimmed.Substring(0, $pos).Trim()
        $value = $trimmed.Substring($pos + 1).Trim()
        if ($value.Length -ge 2) {
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
        }
        $script:DotEnv[$key] = $value
    }

    $workspace = Get-Setting 'WORKSPACE_DIR' './workspace'
    if (-not (Test-Path -LiteralPath $workspace)) {
        New-Item -ItemType Directory -Path $workspace -Force | Out-Null
    }
}

function Get-Setting {
    param([string]$Key, [string]$Fallback = '')
    if ($script:DotEnv.ContainsKey($Key) -and $script:DotEnv[$Key] -ne '') {
        return $script:DotEnv[$Key]
    }
    return $Fallback
}

# ------------------------------------------------------------------ Zustand
function Get-ImageName { Get-Setting 'SANDBOX_IMAGE' 'sandbox-opencode:local' }

function Test-ImageExists {
    & docker image inspect (Get-ImageName) *> $null
    return ($LASTEXITCODE -eq 0)
}

function Test-ContainerRunning {
    $cid = & docker compose ps -q $Service 2>$null | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($cid)) { return $false }
    $state = & docker inspect -f '{{.State.Running}}' $cid 2>$null
    return ($state -eq 'true')
}

function Confirm-Up {
    if (-not (Test-ImageExists)) {
        Write-Msg 'Image wird gebaut - das dauert beim ersten Mal einige Minuten.'
        & docker compose build
        if ($LASTEXITCODE -ne 0) { Stop-WithError 'Der Build ist fehlgeschlagen.' }
    }
    if (-not (Test-ContainerRunning)) {
        Write-Msg 'Container wird gestartet ...'
        & docker compose up -d
        if ($LASTEXITCODE -ne 0) { Stop-WithError 'Der Container liess sich nicht starten.' }
    }
}

function Enter-Shell {
    Confirm-Up
    & docker compose exec $Service bash -l
    exit $LASTEXITCODE
}

function Enter-Opencode {
    Confirm-Up
    & docker compose exec $Service opencode
    exit $LASTEXITCODE
}

function Enter-Claude {
    Confirm-Up
    & docker compose exec $Service claude @Rest
    exit $LASTEXITCODE
}

function Show-Usage {
@'
Verwendung: .\sandbox.ps1 [Befehl]      (oder .\sandbox.bat [Befehl])

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
'@ | Write-Host
}

# ------------------------------------------------------------------ Ablauf
Test-Docker
Import-DotEnv

# Hilfe auch dann, wenn -h oder --help als erstes Argument kommt
if ($Command -eq '' -and $Rest.Count -gt 0) {
    if (@('-h', '--help', '-help', '/?', '-?') -contains $Rest[0]) { Show-Usage; exit 0 }
}

switch ($Command.ToLowerInvariant()) {

    { $_ -in @('', 'enter') } {
        switch (Get-Setting 'DEFAULT_ENTRY' 'shell') {
            'opencode' { Enter-Opencode }
            'claude'   { Enter-Claude }
            default    { Enter-Shell }
        }
        break
    }

    { $_ -in @('shell', 'sh', 'bash') } { Enter-Shell; break }

    { $_ -in @('opencode', 'oc') } { Enter-Opencode; break }

    { $_ -in @('claude', 'cc') } { Enter-Claude; break }

    { $_ -in @('auth', 'login') } {
        $target = ''
        if ($Rest.Count -gt 0) { $target = $Rest[0] }
        $extra = @()
        if ($Rest.Count -gt 1) { $extra = $Rest[1..($Rest.Count - 1)] }
        switch ($target) {
            'opencode' {
                Confirm-Up
                Write-Msg 'Im TUI /connect eingeben, Anthropic auswaehlen.'
                & docker compose exec $Service opencode
                exit $LASTEXITCODE
            }
            'claude' {
                Confirm-Up
                Write-Msg 'Im TUI /login eingeben. Kommt die Rueckleitung nicht an, den Code aus dem Browser einfuegen.'
                & docker compose exec $Service claude @extra
                exit $LASTEXITCODE
            }
            default {
@'
Anmeldung je Agent:
  .\sandbox.ps1 auth opencode   opencode starten, dort /connect
  .\sandbox.ps1 auth claude     Claude Code starten, dort /login

Alternativ den Schluessel in die .env eintragen:
  ANTHROPIC_API_KEY   gilt fuer opencode und Claude Code
'@ | Write-Host
                exit 0
            }
        }
    }

    'reseed' {
        Confirm-Up
        $cmd = 'set -e; install -m 0600 /opt/seed/claude/settings.json "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"'
        & docker compose exec $Service bash -lc $cmd
        if ($LASTEXITCODE -eq 0) { Write-Msg 'Vorlagen aus config/ neu in den Container kopiert.' }
        exit $LASTEXITCODE
    }

    'setup-mcp' {
        Confirm-Up
        $cmd = 'if claude mcp get github >/dev/null 2>&1; then echo "GitHub-MCP-Server ist bei Claude Code bereits eingetragen."; else claude mcp add github --scope user -- github-mcp-server stdio; fi'
        & docker compose exec $Service bash -lc $cmd
        exit $LASTEXITCODE
    }

    { $_ -in @('run', 'exec') } {
        if ($Rest.Count -eq 0) { Stop-WithError 'Kein Befehl angegeben. Beispiel: .\sandbox.ps1 run go version' }
        Confirm-Up
        & docker compose exec $Service bash -lc ($Rest -join ' ')
        exit $LASTEXITCODE
    }

    'clone' {
        if ($Rest.Count -eq 0) { Stop-WithError 'Beispiel: .\sandbox.ps1 clone octocat/hello-world' }
        Confirm-Up
        & docker compose exec $Service bash -lc 'cd /work && gh repo clone "$1"' '_' $Rest[0]
        if ($LASTEXITCODE -eq 0) { Write-Msg ('Geklont nach ' + (Get-Setting 'WORKSPACE_DIR' './workspace') + '.') }
        exit $LASTEXITCODE
    }

    'gh' {
        Confirm-Up
        & docker compose exec $Service gh @Rest
        exit $LASTEXITCODE
    }

    'build' {
        & docker compose build @Rest
        if ($LASTEXITCODE -eq 0) { Write-Msg 'Fertig. Mit .\sandbox.ps1 hineinspringen.' }
        exit $LASTEXITCODE
    }

    'rebuild' {
        & docker compose build --pull --no-cache @Rest
        if ($LASTEXITCODE -ne 0) { Stop-WithError 'Der Build ist fehlgeschlagen.' }
        & docker compose up -d --force-recreate
        Write-Msg 'Image neu gebaut und Container ersetzt.'
        exit $LASTEXITCODE
    }

    'update' {
        & docker compose build --pull @Rest
        if ($LASTEXITCODE -ne 0) { Stop-WithError 'Der Build ist fehlgeschlagen.' }
        & docker compose up -d --force-recreate
        Write-Msg 'Aktualisiert.'
        exit $LASTEXITCODE
    }

    { $_ -in @('start', 'up') } { & docker compose up -d; Write-Msg 'Container laeuft.'; exit $LASTEXITCODE }

    'stop'    { & docker compose stop;    Write-Msg 'Container angehalten.';   exit $LASTEXITCODE }

    'restart' { & docker compose restart; Write-Msg 'Container neu gestartet.'; exit $LASTEXITCODE }

    'logs'    { & docker compose logs -f @Rest; exit $LASTEXITCODE }

    'status' {
        $imageState = if (Test-ImageExists) { '(vorhanden)' } else { '(noch nicht gebaut)' }
        $anthropic = if ((Get-Setting 'ANTHROPIC_API_KEY') -ne '') { 'Key in .env' } else { 'kein Key (Anmeldung im jeweiligen TUI)' }
        $github = if ((Get-Setting 'GITHUB_PERSONAL_ACCESS_TOKEN') -ne '') {
            'Token gesetzt, Toolsets: ' + (Get-Setting 'GITHUB_TOOLSETS' 'Standard')
        } else { 'kein Token in .env' }

        Write-Host ('Image:      ' + (Get-ImageName) + ' ' + $imageState)
        Write-Host ('Projekte:   ' + (Get-Setting 'WORKSPACE_DIR' './workspace') + '  ->  /work')
        Write-Host ('Anthropic:  ' + $anthropic)
        Write-Host ('GitHub:     ' + $github)
        Write-Host ('Board:      ' + (Get-Setting 'GITHUB_PROJECT_OWNER' '(nicht gesetzt)') +
                    ' / Projekt ' + (Get-Setting 'GITHUB_PROJECT_NUMBER' '(nicht gesetzt)'))
        Write-Host ''
        & docker compose ps
        Write-Host ''
        & docker volume ls --filter ('label=com.docker.compose.project=' + (Get-Setting 'SANDBOX_NAME' 'sandbox'))
        exit 0
    }

    'doctor' {
        Write-Host ('Docker:     ' + (& docker --version))
        Write-Host ('Compose:    ' + (& docker compose version --short))
        Write-Host ('Image:      ' + (Get-ImageName) + ' ' + $(if (Test-ImageExists) { 'vorhanden' } else { 'fehlt' }))
        if (Test-ContainerRunning) {
            Write-Host 'Container:  laeuft'
            Write-Host ''
            $probe = '
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
        echo "  GitHub-Token:      $([ -n "${GH_TOKEN:-}" ] && echo gesetzt || echo fehlt)"
        echo "  Anthropic-Key:     $([ -n "${ANTHROPIC_API_KEY:-}" ] && echo gesetzt || echo fehlt)"
        echo "  Claude-Anmeldung:  $([ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json" ] && echo vorhanden || echo fehlt)"
    '
            & docker compose exec -T $Service bash -lc $probe
        } else {
            Write-Host 'Container:  laeuft nicht'
            Write-Warn 'Fuer den vollstaendigen Test: .\sandbox.ps1 start'
        }
        exit 0
    }

    'down' {
        & docker compose down
        Write-Msg 'Container entfernt. Projekte und Anmeldedaten bleiben erhalten.'
        exit $LASTEXITCODE
    }

    'destroy' {
        Write-Warn 'Das loescht auch die opencode-Anmeldung und alle Caches.'
        $answer = Read-Host 'Wirklich? [j/N]'
        if ($answer -match '^[jJyY]$') {
            & docker compose down -v
            Write-Msg 'Alles entfernt.'
        } else {
            Write-Msg 'Abgebrochen.'
        }
        exit 0
    }

    { $_ -in @('help', '-h', '--help', '/?') } { Show-Usage; exit 0 }

    default { Stop-WithError ("Unbekannter Befehl: $Command  (.\sandbox.ps1 help)") }
}
