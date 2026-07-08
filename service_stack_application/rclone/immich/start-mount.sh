#!/usr/bin/env bash
# =============================================================================
# start-mount.sh — Start rclone mount on host (macFUSE)
# =============================================================================
# Usage: ./start-mount.sh
# Run ONCE after boot. The mount runs in the background until unmounted.
# =============================================================================
set -euo pipefail

# --- Absolute Pfade (keine relativen Berechnungen) ------------------------
MOUNT_POINT="/Users/patrickreuver/_workspace/04_docker/mnt_rclone/mounts/immich/dropbox"
RCLONE_CONFIG="/Users/patrickreuver/_workspace/04_docker/mnt_rclone/config/rclone.conf"
REMOTE="Dropbox"
LOG_FILE="/tmp/rclone-immich-dropbox.log"

# --- Check dependencies ----------------------------------------------------
if ! command -v rclone &>/dev/null; then
  echo "✗ rclone not found. Install: brew install rclone"
  exit 1
fi

# --- Check if already mounted ----------------------------------------------
if mount | grep -q "$MOUNT_POINT" 2>/dev/null; then
  echo "✓ Mount already active at $MOUNT_POINT"
  exit 0
fi

# --- Create mount point if missing -----------------------------------------
mkdir -p "$MOUNT_POINT"

# --- Start mount -----------------------------------------------------------
echo "Starting rclone mount: $REMOTE → $MOUNT_POINT"
echo "  Config: $RCLONE_CONFIG"
echo "  Log:    $LOG_FILE"
echo ""

rclone mount "$REMOTE:" "$MOUNT_POINT" \
  --config="$RCLONE_CONFIG" \
  --vfs-cache-mode=writes \
  --read-only \
  --log-level=INFO \
  --stats=5m \
  --daemon \
  >> "$LOG_FILE" 2>&1

# --- Wait and verify -------------------------------------------------------
sleep 3
if mount | grep -q "$MOUNT_POINT" 2>/dev/null; then
  echo "✅ Mount erfolgreich"
  echo "   Inhalt: $(ls "$MOUNT_POINT" 2>/dev/null | head -5 | tr '\n' ' ')"
  echo ""
  echo "   Nach Neustart erneut ausführen."
else
  echo "✗ Mount fehlgeschlagen. Log prüfen: $LOG_FILE"
  tail -5 "$LOG_FILE"
  exit 1
fi
