# Spec: Ausgangsstand vor Einführung der Specs

- **Status:** Umgesetzt <!-- Entwurf | Freigegeben | Umgesetzt -->
- **Datum:** 2026-11-12

## Ziel / Problem

Dieser Fork von OrangeHRM wurde bisher ohne Specs weiterentwickelt. Diese Spec hält einmalig
fest, was der Fork zum 12.11.2026 gegenüber Upstream OrangeHRM 5.8 (Commit `d3815c0d7`)
anders macht (Stand nach PR #7 „hide login when jf keycloak is configured“). Sie dient als
Bezugspunkt: Spätere Specs verweisen auf ihre IDs, z. B. „ändert AC-L2“. Nach der Freigabe
wird sie nicht mehr geändert.

Das Verhalten von Upstream OrangeHRM 5.8 wird nicht beschrieben; es gilt unverändert, soweit
hier nichts anderes steht. Beschrieben wird beobachtbares Verhalten über Oberfläche, API und
Betrieb, keine Implementierungsdetails.

## User Stories

- Als Mitglied der Jugendfeuerwehr möchte ich mich über den Jugendfeuerwehr-Keycloak
  anmelden, ohne von einem zweiten Login-Formular verwirrt zu werden.
- Als Administrator möchte ich lange E-Mail-Adressen und Benutzernamen (z. B. aus dem
  Keycloak) speichern können, ohne dass die Eingabe abgeschnitten oder abgelehnt wird.
- Als Nutzer möchte ich, dass Seiten auch dann Daten zeigen, wenn mein Browser-Cache nicht
  zum ETag des Servers passt.
- Als Betreiber möchte ich OrangeHRM als fertiges Docker-Image starten, das sich beim ersten
  Start selbst installiert.
- Als Betreiber möchte ich, dass ein Release-Tag automatisch ein Image veröffentlicht.

## Akzeptanzkriterien

### Login mit Jugendfeuerwehr-Keycloak (`AC-L`)

- **AC-L1:** WENN ein Social-Login-Provider (OpenID) konfiguriert ist, dessen URL
  `jf-landkreis-karlsruhe.de` enthält (Groß-/Kleinschreibung egal), DANN SOLL die
  Loginseite das Formular mit Benutzername, Passwort, „Login“ und „Passwort vergessen?“
  sowie den Trenner zu den Provider-Buttons nicht anzeigen.
- **AC-L2:** Der Button dieses Providers SOLL mit „Jugendfeuerwehr-Login“ beschriftet sein.
  Andere Provider behalten ihre konfigurierte Beschriftung.
- **AC-L3:** FALLS kein solcher Provider konfiguriert ist, DANN SOLL die Loginseite das
  Formular, den Trenner (sofern es Provider gibt) und die Provider-Buttons wie im Upstream
  zeigen.
- **AC-L4:** Die Überschrift „oder anmelden mit“ über den Provider-Buttons SOLL nie
  angezeigt werden.

### Längere E-Mail-Adressen und Benutzernamen (`AC-E`)

- **AC-E1:** Das System SOLL Benutzernamen mit bis zu 120 Zeichen akzeptieren (vorher 40;
  Mindestlänge 5 unverändert). Das gilt für Admin → Benutzer anlegen und bearbeiten,
  PIM → Mitarbeiter mit Login-Daten anlegen, den Admin-Benutzer im Installer und die API
  zur Prüfung von Benutzernamen.
- **AC-E2:** Das System SOLL folgende E-Mail-Adressen mit bis zu 120 Zeichen akzeptieren:

  | Feld | vorher |
  |---|---|
  | Arbeits-E-Mail des Mitarbeiters (PIM) | 50 |
  | Weitere E-Mail des Mitarbeiters (PIM) | 50 |
  | E-Mail von Bewerbern (Recruitment intern und öffentliches Bewerbungsformular) | 50 (UI) / 100 (DB) |
  | E-Mail der Organisation (Admin → Organisation) | 30 |
  | E-Mail-Abonnenten (Admin → E-Mail-Abonnements) | 100 |
  | „Senden als“ (Admin → E-Mail-Konfiguration) | 100 |
  | E-Mail des Admin-Benutzers im Installer | 50 |
  | E-Mail in Passwort-zurücksetzen-Anfragen | 60 |

- **AC-E3:** FALLS ein Benutzername oder eine der E-Mail-Adressen aus AC-E2 länger als 120
  Zeichen ist, DANN SOLL die Oberfläche die Eingabe mit der Upstream-Meldung zur
  Höchstlänge ablehnen; die API SOLL mit einem Validierungsfehler antworten (Ausnahme
  siehe Bekannte Lücken).
- **AC-E4:** WENN eine bestehende Installation auf diesen Stand aktualisiert wird, DANN SOLL
  die Migration `5.8.1.1` die betroffenen Datenbankspalten auf 120 Zeichen verbreitern, ohne
  Daten zu verändern. Neuinstallationen haben die Spalten direkt mit 120 Zeichen.
- **AC-E5:** Das System SOLL sich als Version `5.8.1.1` ausweisen (Info-Dialog, API,
  Installer).

### API-Cache im Frontend (`AC-C`)

- **AC-C1:** FALLS der Server auf eine Anfrage mit `If-None-Match` mit 304 antwortet, im
  Browser aber keine zwischengespeicherten Daten zu diesem ETag liegen, DANN SOLL das
  Frontend die Anfrage einmal ohne `If-None-Match` wiederholen und die frische Antwort
  verwenden.
- **AC-C2:** FALLS auch die Wiederholung keine verwertbare Antwort liefert, DANN SOLL das
  Frontend keinen weiteren Versuch unternehmen (höchstens eine Wiederholung pro Anfrage)
  und den Fehler in der Browser-Konsole melden.

### Betrieb als Docker-Image (`AC-B`)

- **AC-B1:** WENN der Container ohne bestehende Installation startet (kein
  `lib/confs/Conf.php`), DANN SOLL er OrangeHRM per CLI-Installer in die angegebene,
  bereits existierende Datenbank installieren und danach Apache starten. Bei weiteren
  Starts SOLL er die Installation überspringen.
- **AC-B2:** FALLS beim ersten Start eine der Variablen `ORANGEHRM_DB_HOST`,
  `ORANGEHRM_DB_NAME`, `ORANGEHRM_DB_USER` oder `ORANGEHRM_DB_PASSWORD` fehlt, DANN SOLL
  der Container mit einer Meldung abbrechen, die die fehlende Variable nennt.
- **AC-B3:** Das System SOLL optional `ORANGEHRM_DB_PORT` (Standard `3306`),
  `ORANGEHRM_ADMIN_USER` (Standard `Admin`) und `ORANGEHRM_ADMIN_PASSWORD` (Standardwert
  siehe `README.md`) auswerten.
- **AC-B4:** WÄHREND die Datenbank beim ersten Start nicht erreichbar ist, SOLL der
  Container bis zu 60 s warten. FALLS sie danach nicht erreichbar ist, DANN SOLL er mit
  Fehler beenden.
- **AC-B5:** Konfiguration (`lib/confs`), Cache und Logs SOLLEN in Volumes liegen, sodass
  Installation und Logs einen Neustart oder Austausch des Containers überstehen.
- **AC-B6:** WENN ein Git-Tag `v*` gepusht wird, DANN SOLL ein Image für `linux/amd64` und
  `linux/arm64` nach `ghcr.io/<repo>` veröffentlicht werden, mit den Tags
  `<major>.<minor>.<patch>`, `<major>.<minor>`, `<major>` und `latest`.

## Nicht-Ziele

Gibt es zu diesem Stand bewusst nicht:

- Fachliche Änderungen an den HR-Modulen (PIM, Leave, Time, Recruitment, …) über die
  Feldlängen hinaus
- Ein konfigurierbarer Schalter „nur Social Login“ unabhängig vom Jugendfeuerwehr-Keycloak
- Übersetzungen für die neuen Texte
- Lokale Cypress-Läufe
- Eigene Datenbank im Produktions-Image; die Datenbank wird extern bereitgestellt

## Randbedingungen

- Basis ist Upstream OrangeHRM 5.8 (`d3815c0d7`). Das Verhalten dort gilt, soweit diese Spec
  nichts anderes sagt.
- PHP 8.3, Node 20, MySQL/MariaDB.
- Entwicklung, Tests und Lint laufen ausschließlich über das `Makefile` mit den
  Docker-Workflows `docker/dev/` (Tools-Container) und `docker/local/` (lokale Live-App).
  Details in `AGENTS.md` und `README.md`.
- CI (`.github/workflows/test.yml`) führt PHPUnit und Jest auf MySQL 5.7 und MariaDB 10.3
  aus. Die Upgrade-Tests von 4.x wurden entfernt, der nächtliche Test über viele
  DB-Versionen (`scheduled_test.yml`) ist faktisch deaktiviert. Lint darf keinen Diff
  erzeugen.
- Das Produktions-Image wird aus dem `Dockerfile` im Repo-Root gebaut; der
  Docker-Workflow für lokale Entwicklung ist davon unabhängig.

## Bekannte Lücken

<!-- Abweichungen vom gewünschten Verhalten. Jede wird in einer eigenen Spec behoben,
     die die betroffenen IDs nennt. -->

- **Keycloak-Erkennung hart codiert** (betrifft AC-L1, AC-L2): Ob das Login-Formular
  ausgeblendet wird, hängt an der Domain `jf-landkreis-karlsruhe.de` in der Provider-URL.
  Die Beschriftung „Jugendfeuerwehr-Login“ steht fest im Code und wird nicht übersetzt.
- **Passwort-Login nur versteckt** (betrifft AC-L1): Das Formular ist nur unsichtbar. Der
  Server nimmt Anmeldungen mit Benutzername und Passwort weiterhin an.
- **Eigene Versionsnummer 5.8.1.1** (betrifft AC-E4, AC-E5): Version und Migration des Forks
  können mit künftigen Upstream-Versionen und deren Migrationen kollidieren.
- **Bewerber-E-Mail ohne Längenprüfung in der API** (betrifft AC-E3): Die Recruitment-API
  prüft die Länge der Bewerber-E-Mail nicht; zu lange Werte scheitern erst an der
  Datenbank. Die Oberfläche prüft auf 120 Zeichen.

## Offene Fragen

<!-- Muss leer sein, bevor die Spec freigegeben wird. Für jede Frage: festschreiben
     als Soll, oder als bekannter Mangel in die Nicht-Ziele / eine spätere Spec. -->

Keine.
