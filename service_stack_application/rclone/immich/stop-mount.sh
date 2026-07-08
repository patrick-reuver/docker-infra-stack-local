#!/usr/bin/env bash
# =============================================================================
# stop-mount.sh — Stop rclone host mount (macFUSE)
# =============================================================================
# Usage: ./stop-mount.sh
# Unmounts the rclone FUSE mount and cleans up.
# =============================================================================
set -euo pipefail

MOUNT_POINT="/Users/patrickreuver/_workspace/04_docker/mnt_rclone/mounts/immich/dropbox"

echo "Stopping rclone mount at $MOUNT_POINT"

if mount | grep -q "$MOUNT_POINT" 2>/dev/null; then
  umount "$MOUNT_POINT" 2>/dev/null && echo "✅ Mount removed" || echo "⚠ umount failed (trying force)"

  # Fallback: force unmount
  if mount | grep -q "$MOUNT_POINT" 2>/dev/null; then
    diskutil unmount force "$MOUNT_POINT" 2>/dev/null && echo "✅ Force unmount successful"
  fi
else
  echo "✓ No mount active at $MOUNT_POINT"
fi

echo ""
echo "Done."
