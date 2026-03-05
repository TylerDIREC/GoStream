#!/bin/sh
set -eu
CONFIG_PATH="${MKV_PROXY_CONFIG_PATH:-/config.json}"
SOURCE_PATH="${GOSTREAM_SOURCE_PATH:-/mnt/gostream-mkv-real}"
MOUNT_PATH="${GOSTREAM_MOUNT_PATH:-/mnt/gostream-mkv-virtual}"

mkdir -p "$SOURCE_PATH" "$MOUNT_PATH"
mkdir -p /logs
mkdir -p /usr/local/STATE

if mountpoint -q "$MOUNT_PATH" 2>/dev/null; then
  echo "Stale FUSE mount detected at $MOUNT_PATH, cleaning up..." >&2
  fusermount3 -uz "$MOUNT_PATH" || true
fi
if [ ! -f "$CONFIG_PATH" ]; then
  echo "Missing required config file at $CONFIG_PATH" >&2
  exit 1
fi

# Start health monitor
python3 /app/scripts/health-monitor.py &

# Start GoStream in background, wait for FUSE mount, then start Samba
/usr/local/bin/gostream "$SOURCE_PATH" "$MOUNT_PATH" &
GOSTREAM_PID=$!

# Wait for FUSE mount to become active
echo "Waiting for FUSE mount..." >&2
while ! mountpoint -q "$MOUNT_PATH" 2>/dev/null; do
  sleep 1
done
echo "FUSE mount ready, starting Samba..." >&2
smbd --no-process-group --daemon

# Keep container alive by waiting on GoStream
wait $GOSTREAM_PID