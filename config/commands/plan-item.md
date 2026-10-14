---
description: Ein GitHub-Issue analysieren und den Umsetzungsplan als Kommentar ins Issue schreiben
---

Du planst die Umsetzung eines GitHub-Issues. In diesem Durchgang wird **nichts
implementiert**, kein Branch angelegt und nichts committet.

## Issue

$ARGUMENTS

Issue-Nummer oder Issue-URL. Fehlt die Angabe, frage danach, bevor du beginnst.

## Schritt 0: Kontext ermitteln

Fuehre das zuerst aus und verwende die Ausgabe in allen weiteren Schritten:

```sh
echo "Verzeichnis: $(pwd)"
echo "Repository:  $(git remote get-url origin 2>/dev/null || echo 'kein Git-Repository')"
echo "Branch:      $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"
```

## Vorgehen

1. **Issue lesen.** Titel, Beschreibung, Labels, vorhandene Kommentare und
   verlinkte Pull Requests - ueber die GitHub-Werkzeuge des MCP-Servers oder
   `gh issue view <nr> --comments`.

2. **Code verstehen.** Suche die betroffenen Stellen im Repository, sieh dir
   vergleichbare Implementierungen an und lies die Build- und Testbefehle aus
   README, Makefile, package.json, go.mod o. ae. ab. Rate nichts, was du
   nachlesen kannst.

3. **Rueckfragen.** Sind die Anforderungen widerspruechlich oder lueckenhaft,
   stelle hoechstens drei gezielte Fragen und warte auf Antwort.

4. **Plan formulieren** mit genau diesen Abschnitten:
   - *Ziel* - ein bis drei Saetze
   - *Betroffene Dateien* - mit kurzer Begruendung je Datei
   - *Schritte* - nummeriert, jeder einzeln umsetzbar und ueberpruefbar
   - *Tests* - welche, wie ausgefuehrt, was neu dazukommt
   - *Offene Punkte*
   - *Definition of Done*

5. **Plan ins Issue schreiben.** Als Kommentar, dessen erste Zeile genau
   `## Umsetzungsplan` lautet - daran findet `/implement-item` ihn spaeter
   wieder. Gibt es bereits so einen Kommentar, aktualisiere ihn, statt einen
   zweiten anzulegen.

6. **Zusammenfassung.** Fuenf bis zehn Zeilen: was geplant ist und was als
   naechstes zu entscheiden waere. Schliesse mit dem Hinweis, dass die
   Umsetzung ueber `/implement-item <nummer>` laeuft.

## Regeln

- Keine Codeaenderungen, keine Commits, keine Branches, keine Pull Requests.
- Was du nicht sicher weisst, gehoert unter *Offene Punkte* - nicht in die
  Schritte.
- Schreibe den Plan so, dass ihn jemand ohne diesen Chatverlauf abarbeiten kann.
- Antworte auf Deutsch.
