# Rclone Immich Mounts (Host-macFUSE)

Rclone läuft auf dem **Host** (macOS) via macFUSE, nicht im Docker-Container.
Grund: Docker for Mac kann FUSE-Mounts nicht zwischen Containern teilen.

## Voraussetzung

```bash
brew install --cask macfuse
```

Einmal in Systemeinstellungen → Sicherheit → Erlauben bestätigen.

## Struktur

```text
docker-infra-stack/service_stack_application/rclone/immich/
├── start-mount.sh          → Mount starten
├── stop-mount.sh           → Mount stoppen
├── config.yaml             → Mount-Konfiguration (für Referenz)
├── local.rclone-immich-dropbox.plist → Launchd-Autostart (optional)

04_docker/mnt_rclone/
├── config/
│   └── rclone.conf         → Rclone-Konfiguration (OAuth-Token)
└── mounts/immich/
    └── dropbox/            → Dropbox-Mount-Ziel (hier landen die Dateien)
```

## Einrichtung (einmalig)

```bash
# 1. Autorisiere Dropbox (falls nicht geschehen)
cd /path/to/rclone/immich
./start-mount.sh
```

macFUSE fragt beim ersten Mount um Erlaubnis → bestätigen.

## Täglicher Betrieb

```bash
# Mount starten (nach Neustart)
./start-mount.sh

# Mount stoppen
./stop-mount.sh

# Status prüfen
mount | grep dropbox
```

## Autostart (optional)

```bash
cp local.rclone-immich-dropbox.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/local.rclone-immich-dropbox.plist
```

## Integration mit Immich

Der Host-Pfad `04_docker/mnt_rclone/mounts/immich/dropbox` wird als
Bind-Mount in den `immich-server`-Container gegeben → sichtbar unter `/mnt/dropbox`.

In Immich WebUI: Administration → External Libraries → `/mnt/dropbox` hinzufügen.

## Secret-Management

Der Dropbox-OAuth-Token liegt in der `rclone.conf` im Config-Volume.
Für den Wiederherstellungsfall ist er in Infisical unter `RCLONE_DROPBOX_TOKEN` gesichert.

## Fehlersuche

```bash
# MacFUSE geladen?
mount | grep macfuse

# Log prüfen
cat /tmp/rclone-immich-dropbox.log

# Direkter Test
ls /Users/.../04_docker/mnt_rclone/mounts/immich/dropbox/ | head
```
