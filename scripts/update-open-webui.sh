#!/bin/bash
# Update open-webui Docker container to latest image.
# Pulls ghcr.io/open-webui/open-webui:main and restarts the container only if
# a new image is available. Safe to run while the container is live.

set -euo pipefail

LOG_FILE="/var/log/sysadmin/open-webui-update.log"
STATUS_FILE="/var/log/sysadmin/open-webui-update-status.json"
IMAGE="ghcr.io/open-webui/open-webui:main"
CONTAINER="open-webui"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

write_status() {
    local result="$1"
    local message="$2"
    cat > "$STATUS_FILE" <<JSON
{
  "last_run": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "result": "$result",
  "message": "$message"
}
JSON
}

log "=== open-webui update check starting ==="

old_digest=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE" 2>/dev/null || echo "none")
log "Current digest: $old_digest"

log "Pulling $IMAGE..."
docker pull "$IMAGE" >> "$LOG_FILE" 2>&1

new_digest=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE" 2>/dev/null || echo "none")
log "New digest:     $new_digest"

if [[ "$old_digest" == "$new_digest" ]]; then
    log "No update available — container unchanged"
    write_status "no-update" "Image up to date as of $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    log "=== open-webui update check complete ==="
    exit 0
fi

log "New image available — updating container..."

if docker ps -q -f "name=^${CONTAINER}$" | grep -q .; then
    log "Stopping $CONTAINER..."
    docker stop "$CONTAINER" >> "$LOG_FILE" 2>&1
fi

if docker ps -aq -f "name=^${CONTAINER}$" | grep -q .; then
    log "Removing old $CONTAINER container..."
    docker rm "$CONTAINER" >> "$LOG_FILE" 2>&1
fi

log "Starting new $CONTAINER container..."
docker run -d \
    --name "$CONTAINER" \
    --network=host \
    -v open-webui:/app/backend/data \
    --restart always \
    -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
    "$IMAGE" >> "$LOG_FILE" 2>&1

sleep 5

if docker ps -q -f "name=^${CONTAINER}$" | grep -q .; then
    log "✓ $CONTAINER updated and running successfully"
    write_status "updated" "Updated to ${new_digest##*@} at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
else
    log "ERROR: $CONTAINER failed to start after update"
    write_status "failed" "Container failed to start after update at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    exit 1
fi

log "=== open-webui update complete ==="
