# Zentrale Docker-Infrastruktur für Self-Hosted-Apps

## Zielbild

Für dauerhaft genutzte Eigenprojekte wie Paperless, Twenty CRM, oder ähnliche Self-Hosted-Apps ist eine **zentralisierte Infrastruktur** sinnvoller als für jedes Projekt eigene Datenbank-, Cache- und Storage-Instanzen zu betreiben.

Empfohlenes Muster:

- **Shared Infra Stack**: Postgres, Redis, MinIO, Reverse Proxy, Monitoring
- **Getrennte App-Stacks**: jede Anwendung behält ihren eigenen Compose-Stack, ihre eigene `.env`, ihre eigenen Volumes und Versionsstände
- **Gemeinsames Docker-Netzwerk**: Apps greifen über interne DNS-Namen auf die Infra-Services zu

Dieses Muster reduziert:

- Port-Konflikte
- Ressourcenverschwendung
- Backup-Chaos
- redundante Services
- administrativen Aufwand

---

## Architekturprinzip

### Zentralisieren

Diese Dienste eignen sich als wiederverwendbare Shared Services:

- **Postgres** als zentrale relationale Datenbankinstanz
- **Redis** als zentraler Cache / Broker
- **MinIO** als S3-kompatibler Object Storage
- **Traefik** als Reverse Proxy mit Dashboard und Docker-Label-basiertem Routing
- **Prometheus** für Metriken
- **Grafana** für Dashboards
- **Loki + Promtail** für zentrale Logsammlung

### Getrennt halten

Diese Dinge bleiben pro Anwendung separat:

- App-Container
- App-Versionen
- App-spezifische ENV-Dateien
- App-spezifische Volumes
- App-spezifische Datenbanknamen
- App-spezifische Redis-Datenbanken / Keys, sofern relevant
- App-spezifische Buckets in MinIO

---

## Empfohlener Stack

### Shared Infra Stack

- `postgres`
- `redis`
- `minio`
- `traefik`
- `prometheus`
- `grafana`
- `loki`
- `promtail`

### Optional später

- `infisical` für zentrales Secret Management
- `tailscale` für privaten Remote-Zugriff vom Smartphone / Laptop
- `uptime-kuma` für Healthchecks
- `netdata` für Host-/Container-Übersicht
- `pgadmin` oder `adminer` nur falls wirklich nötig
- `restic` als zusätzliche Backup-Strategie

---

## Best Practice für neue Anwendungen

Wenn eine neue Anwendung an den Shared Stack angeschlossen wird, wird **nicht** einfach blind gestartet. Stattdessen gilt ein klarer Ablauf.

### Reihenfolge

1. neue Anwendung fachlich und technisch einordnen
2. prüfen, ob Postgres / Redis / MinIO benötigt wird
3. in Postgres **eigene DB + eigener User** anlegen
4. in MinIO **eigenen Bucket** anlegen, falls S3 benötigt wird
5. App-ENV mit internen Hostnamen befüllen
6. App an dasselbe Docker-Netzwerk hängen
7. Reverse-Proxy-Labels ergänzen
8. App starten
9. Healthcheck / Login / Schreibtest durchführen
10. Backup- und Restore-Fähigkeit prüfen

---

## Docker-Netzwerk anlegen

Der Shared Stack und alle App-Stacks sollten dasselbe externe Docker-Netzwerk verwenden.

```bash
docker network create infra_net
```

Prüfen:

```bash
docker network ls
```

---

## Postgres: Datenbanken und Benutzer anlegen

### In den Postgres-Container einloggen

```bash
docker exec -it infra-postgres psql -U "$POSTGRES_USER"
```

Falls kein ENV im Shell-Kontext geladen ist, alternativ direkt:

```bash
docker exec -it infra-postgres psql -U postgres
```

### Beispiel: DB + User für Paperless anlegen

```sql
CREATE USER paperless_user WITH ENCRYPTED PASSWORD 'CHANGE_ME_STRONG';
CREATE DATABASE paperless_db OWNER paperless_user;
GRANT ALL PRIVILEGES ON DATABASE paperless_db TO paperless_user;
```

### Beispiel: DB + User für Twenty CRM

```sql
CREATE USER twenty_user WITH ENCRYPTED PASSWORD 'CHANGE_ME_STRONG';
CREATE DATABASE twenty_db OWNER twenty_user;
GRANT ALL PRIVILEGES ON DATABASE twenty_db TO twenty_user;
```

### Datenbanken auflisten

```sql
\l
```

### Benutzer auflisten

```sql
\du
```

---

## Redis: Nutzung

Redis muss in vielen Fällen **nicht** pro Anwendung separat instanziiert werden.

Die Anwendung greift typischerweise einfach auf zu:

- Host: `redis`
- Port: `6379`

Falls Auth aktiviert ist, wird zusätzlich ein Passwort gesetzt.

Beispiel Redis URL:

```text
redis://:REDIS_PASSWORD@redis:6379/0
```

Optional können unterschiedliche DB-Indizes verwendet werden, falls die App das unterstützt.

---

## MinIO: Buckets anlegen

### MinIO Web UI

- URL intern über Traefik oder Port: `http://minio.local` bzw. `http://localhost:9001`
- dort Buckets manuell anlegen

### Per MinIO Client (`mc`)

Client lokal installieren oder temporär im Container nutzen.

Alias setzen:

```bash
mc alias set local http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
```

Bucket anlegen:

```bash
mc mb local/paperless-documents
mc mb local/twenty-uploads
mc mb local/shared-backups
```

Buckets auflisten:

```bash
mc ls local
```

Optional Versioning aktivieren:

```bash
mc version enable local/shared-backups
```

---

## Welche ENV-Infos braucht die App?

Je nach App unterschiedlich, aber typische Felder sind:

### Für Postgres

```env
DB_HOST=postgres
DB_PORT=5432
DB_NAME=paperless_db
DB_USER=paperless_user
DB_PASSWORD=CHANGE_ME_STRONG
```

oder als URL:

```env
DATABASE_URL=postgresql://paperless_user:CHANGE_ME_STRONG@postgres:5432/paperless_db
```

### Für Redis

```env
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=CHANGE_ME
REDIS_URL=redis://:CHANGE_ME@redis:6379/0
```

### Für MinIO / S3

```env
S3_ENDPOINT=minio:9000
S3_ACCESS_KEY=CHANGE_ME
S3_SECRET_KEY=CHANGE_ME
S3_BUCKET=paperless-documents
S3_REGION=us-east-1
S3_USE_SSL=false
```

### Für Reverse Proxy / Traefik per Docker Labels

Beispiel innerhalb des App-Compose:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.paperless.rule=Host(`paperless.local`)
  - traefik.http.routers.paperless.entrypoints=web
  - traefik.http.services.paperless.loadbalancer.server.port=8000
```

---

## Beispiel: App an Shared Infra anschließen

```yaml
services:
  myapp:
    image: example/app:latest
    env_file:
      - .env
    networks:
      - infra_net
    labels:
      - traefik.enable=true
      - traefik.http.routers.myapp.rule=Host(`myapp.local`)
      - traefik.http.routers.myapp.entrypoints=web
      - traefik.http.services.myapp.loadbalancer.server.port=8080

networks:
  infra_net:
    external: true
```

---

## Daten von Datenbank A nach Datenbank B übertragen

Das hängt davon ab, ob du meinst:

1. **eine komplette Datenbank migrieren**
2. **einzelne Tabellen exportieren/importieren**
3. **Daten zwischen zwei Anwendungen synchronisieren**

### Variante 1: komplette Postgres-DB dumpen und in neue DB einspielen

Dump erzeugen:

```bash
docker exec -t infra-postgres pg_dump -U postgres -d source_db > source_db.sql
```

Neue Zieldatenbank anlegen und Import:

```bash
cat source_db.sql | docker exec -i infra-postgres psql -U postgres -d target_db
```

### Variante 2: Custom Dump

```bash
docker exec -t infra-postgres pg_dump -U postgres -Fc -d source_db > source_db.dump
```

Restore:

```bash
cat source_db.dump | docker exec -i infra-postgres pg_restore -U postgres -d target_db --clean --if-exists
```

### Variante 3: einzelne Tabellen exportieren

CSV-Export aus Postgres:

```sql
COPY my_table TO '/tmp/my_table.csv' WITH CSV HEADER;
```

Danach Datei aus Container kopieren:

```bash
docker cp infra-postgres:/tmp/my_table.csv ./my_table.csv
```

CSV wieder importieren:

```sql
COPY my_table FROM '/tmp/my_table.csv' WITH CSV HEADER;
```

### Variante 4: Sync zwischen Anwendungen

Wenn Daten fachlich zwischen App A und App B ausgetauscht werden sollen, ist **direkter DB-zu-DB-Schreibzugriff meist nicht Best Practice**.

Besser:

- API-basierte Synchronisation
- ETL-Job / Script
- n8n Workflow
- periodischer Export/Import

Direkte Cross-App-DB-Schreibzugriffe führen oft zu:

- Kopplung
- Update-Risiken
- kaputten Datenmodellen
- schwieriger Fehlersuche

---

## Backup-Strategie

Ein gutes Setup braucht **mehr als nur Backups**. Es braucht eine **Restore-fähige Strategie**.

### Was gesichert werden sollte

- Postgres Datenbanken
- MinIO Daten / Buckets
- App-Volumes
- ENV-Dateien / Compose-Dateien / Konfigurationen
- Grafana Dashboards / Provisioning, falls angepasst
- Loki/Prometheus-Daten optional je nach Wichtigkeit

### Manuelle Postgres-Backups

Alle DBs dumpen:

```bash
docker exec -t infra-postgres pg_dumpall -U postgres > postgres_all.sql
```

Einzelne DB dumpen:

```bash
docker exec -t infra-postgres pg_dump -U postgres -d paperless_db > paperless_db.sql
```

Compressed Custom Dump:

```bash
docker exec -t infra-postgres pg_dump -U postgres -Fc -d paperless_db > paperless_db.dump
```

### Restore Postgres

```bash
cat paperless_db.sql | docker exec -i infra-postgres psql -U postgres -d paperless_db
```

oder bei Custom Dump:

```bash
cat paperless_db.dump | docker exec -i infra-postgres pg_restore -U postgres -d paperless_db --clean --if-exists
```

### MinIO / Dateien sichern

#### Variante A: rsync auf lokales oder extern gemountetes Ziel

```bash
rsync -avh --delete /path/to/data/ /path/to/backup/
```

Geeignet für:

- lokale Spiegelung
- externe USB-Platte
- NAS-Mount

#### Variante B: rclone zu Cloud oder anderem S3-Ziel

```bash
rclone sync /path/to/data remote:backup-bucket/path --progress
```

Geeignet für:

- Offsite-Backups
- S3 / Backblaze / Hetzner Storage Box / andere Ziele

#### Variante C: MinIO Bucket zu Bucket / Remote sync

```bash
mc mirror local/shared-backups remote/shared-backups
```

---

## Automatisierte Backups

### Shell-Script Beispiel

```bash
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/backups/postgres/$(date +%F)"
mkdir -p "$BACKUP_DIR"

docker exec -t infra-postgres pg_dumpall -U postgres > "$BACKUP_DIR/postgres_all.sql"
```

### Cronjob Beispiel

```cron
0 2 * * * /opt/scripts/backup-postgres.sh
```

### Sinnvolle Struktur

```text
/backups
  /postgres
    /2026-03-16
  /minio
    /2026-03-16
  /volumes
    /2026-03-16
  /configs
    /2026-03-16
```

### Retention mit `find`

Beispiel: Backups älter als 14 Tage löschen

```bash
find /backups/postgres -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} \;
```

> Vorsicht: destruktiver Befehl. Vorher immer mit `echo` oder ohne `-exec rm -rf` testen.

Trockentest:

```bash
find /backups/postgres -mindepth 1 -maxdepth 1 -type d -mtime +14
```

---

## Monitoring-Komponenten erklärt

### Prometheus

Sammelt **Metriken** als Zeitreihen:

- CPU
- RAM
- HTTP Requests
- DB-Metriken
- Container-Metriken

### Grafana

Visualisiert Metriken und Logs in Dashboards.

### Loki

Sammelt **Logs** zentral.

### Promtail

Liest Logdateien ein und schiebt sie zu Loki.

---

## State of the Art?

Für ein kleines bis mittleres Self-Hosted-Setup ist die Kombination aus:

- Traefik
- Postgres
- Redis
- MinIO
- Prometheus
- Grafana
- Loki

absolut solide und modern.

Es ist kein übertriebenes Enterprise-Monster, aber bereits sehr professionell.

Wichtig ist nur: **State of the art heißt nicht automatisch sofort alles maximal ausbauen.**

Pragmatische Reihenfolge bleibt:

1. Shared Infra lauffähig machen
2. eine App sauber anbinden
3. Backups und Restore testen
4. Monitoring sinnvoll auswerten
5. privaten Remote-Zugriff ergänzen
6. Secret Management später professionalisieren

---

## Empfohlene Vorgehensweise

### Phase 1 – Fundament

- Docker-Netzwerk anlegen
- Shared Infra Stack starten
- Traefik Dashboard prüfen
- Postgres Zugriff testen
- Redis Zugriff testen
- MinIO Zugriff testen
- Grafana / Prometheus / Loki prüfen

### Phase 2 – Referenz-App migrieren

- eine App auswählen, z. B. Paperless
- DB + User anlegen
- ggf. Bucket anlegen
- ENV umbauen
- App ins `infra_net` hängen
- Ports entfernen, nur Traefik nutzen
- Login, CRUD, Datei-Upload testen

### Phase 3 – Backup & Restore

- DB Backup Script bauen
- MinIO / Volumes sichern
- Restore in Testumgebung prüfen
- Retention definieren
- Offsite-Strategie definieren

### Phase 4 – Standardisieren

- Template für neue Apps definieren
- Namenskonventionen definieren
- Bucket-Namensmuster definieren
- DB-User-Schema definieren
- Dokumentation in Obsidian festhalten

### Phase 5 – Später

- Tailscale einführen
- Infisical evaluieren
- Uptime Kuma ergänzen
- Alerting in Grafana einrichten
- ggf. NAS / Dauerbetrieb ergänzen

---

## Namenskonventionen

### Datenbanken

- `paperless_db`
- `twenty_db`
- `directus_db`
- `grafana_db` falls nötig

### Datenbank-User

- `paperless_user`
- `twenty_user`
- `directus_user`

### Buckets

- `paperless-documents`
- `twenty-uploads`
- `shared-backups`
- `raw-imports`

### Docker Container

- `infra-postgres`
- `infra-redis`
- `infra-minio`
- `infra-traefik`
- `infra-prometheus`
- `infra-grafana`
- `infra-loki`

---

## Mögliche blinde Flecken

- Backup ohne Restore-Test
- zu frühes Secret-Management als Sidequest
- zu viele Services gleichzeitig migrieren
- Logging ohne sinnvolle Retention
- zu wenig Disk-Space für Prometheus / Loki / MinIO
- fehlende Dokumentation der DB-User, Buckets und Domains
- zu offene Exponierung des Traefik Dashboards
- App braucht doch persistenten lokalen Volume-Speicher zusätzlich zu S3
- App erwartet Migrationsrechte auf DB-Schema
- manche Apps brauchen zusätzliche Worker / Cron-Container

---

## Entscheidungsempfehlung

Für die aktuelle Situation ist die empfohlene Leitlinie:

- **Variante B für eigene, wiederkehrende Apps**
- **Variante A oder striktere Isolation für Kundenprojekte**
- **Traefik als Reverse Proxy**
- **Tailscale später für privaten Remote-Zugriff**
- **Infisical vorerst Backlog, nicht sofort umsetzen**

---

## Tasks / Backlog

```tasks
not done
path includes Architektur
```

- [ ] `infra_net` als zentrales Docker-Netzwerk anlegen
- [ ] Shared Infra Stack lokal starten
- [ ] Zugriff auf Traefik Dashboard prüfen
- [ ] Zugriff auf MinIO API und Console prüfen
- [ ] Postgres Login testen
- [ ] Redis Login / Verbindung testen
- [ ] Grafana Login prüfen
- [ ] Prometheus Targets prüfen
- [ ] Loki Log-Ingestion prüfen
- [ ] Referenz-App für Migration auswählen
- [ ] Für Referenz-App DB + User in Postgres anlegen
- [ ] Für Referenz-App Bucket in MinIO anlegen
- [ ] ENV der Referenz-App auf Shared Infra umstellen
- [ ] Referenz-App an `infra_net` anbinden
- [ ] Lokale Portfreigaben der Referenz-App reduzieren oder entfernen
- [ ] Traefik Labels für Referenz-App ergänzen
- [ ] End-to-End-Test der Referenz-App durchführen
- [ ] Postgres Backup-Script erstellen
- [ ] MinIO / Volume Backup-Strategie definieren
- [ ] Restore-Test für Postgres durchführen
- [ ] Restore-Test für Dateien / Buckets durchführen
- [ ] Retention-Strategie definieren
- [ ] Offsite-Backup mit `rclone` evaluieren
- [ ] App-Onboarding-Template in Obsidian dokumentieren
- [ ] Namenskonventionen final festlegen
- [ ] Tailscale als privates Zugriffsmodell evaluieren
- [ ] Infisical im Backlog belassen und später bewerten
- [ ] Uptime Kuma optional ergänzen
- [ ] Alerting in Grafana später ergänzen
- [ ] Ressourcenverbrauch des Stacks nach Inbetriebnahme messen
- [ ] Disk-Nutzung für Loki, Prometheus und MinIO überwachen
