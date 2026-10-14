---
description: Den geplanten Stand eines GitHub-Issues umsetzen, testen und als Pull Request einreichen
---

Du setzt ein geplantes GitHub-Issue um und reichst das Ergebnis als Pull Request
ein.

## Issue

$ARGUMENTS

Issue-Nummer oder Issue-URL. Fehlt die Angabe, frage danach, bevor du beginnst.

## Schritt 0: Kontext ermitteln

Fuehre das zuerst aus und verwende die Ausgabe in allen weiteren Schritten:

```sh
echo "Verzeichnis: $(pwd)"
echo "Repository:  $(git remote get-url origin 2>/dev/null || echo 'kein Git-Repository')"
echo "Ziel-Branch: ${GIT_DEFAULT_BRANCH:-main}"
git status -sb | head -20
```

## Vorgehen

1. **Plan holen.** Lies die Kommentare des Issues und nimm den Kommentar, der
   mit `## Umsetzungsplan` beginnt - ueber die GitHub-Werkzeuge des MCP-Servers
   oder `gh issue view <nr> --comments`. Gibt es keinen, brich ab und weise
   darauf hin, dass zuerst `/plan-item <nummer>` laufen sollte.

2. **Arbeitsstand pruefen.** Sind uncommittete Aenderungen vorhanden, frage, wie
   damit verfahren werden soll. Hole dann den Ziel-Branch auf den neuesten Stand
   und lege davon `feature/<nummer>-<slug>` an.

3. **Schrittweise umsetzen.** Arbeite die Schritte des Plans der Reihe nach ab
   und halte dich an die vorhandenen Muster im Projekt. Weicht die Umsetzung vom
   Plan ab, halte die Abweichung mit Begruendung fest.

4. **Pruefen.** Fuehre Tests, Linter und Build aus, so wie es das Projekt
   vorsieht. Gibt es keine Tests fuer den geaenderten Bereich, lege welche an,
   sofern das zum Projekt passt. Erst weiter, wenn alles gruen ist.

5. **Committen.** Kleine, nachvollziehbare Commits; Betreff im Imperativ,
   Koerper mit dem Warum. Jeder Commit verweist mit `Refs #<nummer>` auf das
   Issue.

6. **Pull Request anlegen.** Branch pushen, Pull Request gegen den Ziel-Branch
   erstellen - ueber die GitHub-Werkzeuge des MCP-Servers oder `gh pr create`.
   Der Beschreibungstext enthaelt:
   - was geaendert wurde und warum
   - wie es getestet wurde
   - bewusste Abweichungen vom Plan
   - abschliessend `Closes #<nummer>`

7. **Zusammenfassung.** Nenne PR-URL, Branch, geaenderte Dateien, Testergebnis
   und alles, was offen bleibt.

## Regeln

- Niemals direkt auf den Ziel-Branch committen oder pushen.
- Kein `git push --force`, kein `git reset --hard` auf fremde Commits, keine
  Branches oder Issues loeschen.
- Keine Zugangsdaten in Commits; `.env`-Dateien werden weder veraendert noch
  eingecheckt.
- Bleibt ein Schritt unklar, frage nach, statt eine Annahme zu implementieren.
- Antworte auf Deutsch.
