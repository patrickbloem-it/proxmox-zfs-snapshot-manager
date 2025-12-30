#!/bin/bash
#
# ZFS Snapshot Manager for Proxmox VE
# Automated snapshot creation and rotation with GFS-style retention
#
# Author: Patrick Bloem <https://github.com/patrickbloem-it>
# License: MIT
# Version: 1.0.0

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ==================== CONFIGURATION ====================
DATASET="${1:-}"
LOG_FACILITY="${LOG_FACILITY:-local0}"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
RETENTION_HOURLY="${RETENTION_HOURLY:-24}"
RETENTION_DAILY="${RETENTION_DAILY:-7}"

# ==================== FUNCTIONS ====================

log() {
    local message="$1"
    logger -t "zfs-snapshot" -p "${LOG_FACILITY}.info" "$message"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $message"
}

error_exit() {
    local message="$1"
    logger -t "zfs-snapshot" -p "${LOG_FACILITY}.err" "ERROR: $message"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $message" >&2
    exit 1
}

usage() {
    cat << EOF
Usage: $0 <dataset>

Arguments:
  dataset       ZFS dataset to snapshot (e.g., rpool/data)

Environment Variables:
  RETENTION_HOURLY    Number of hourly snapshots to keep (default: 24)
  RETENTION_DAILY     Number of daily snapshots to keep (default: 7)
  LOG_FACILITY        Syslog facility (default: local0)

Example:
  $0 rpool/data
  RETENTION_HOURLY=48 $0 rpool/backups

EOF
    exit 1
}

# ==================== MAIN ====================

# Validate arguments
if [ -z "$DATASET" ]; then
    echo "ERROR: No dataset specified" >&2
    usage
fi

log "Starting snapshot operation for dataset: $DATASET"

# Verify dataset exists
if ! zfs list -H -o name "$DATASET" &>/dev/null; then
    error_exit "Dataset $DATASET not found. Check 'zfs list' output."
fi

# Create snapshot
SNAPSHOT_NAME="${DATASET}@auto-hourly-${TIMESTAMP}"
log "Creating recursive snapshot: $SNAPSHOT_NAME"

if ! zfs snapshot -r "$SNAPSHOT_NAME" 2>&1 | logger -t "zfs-snapshot" -p "${LOG_FACILITY}.info"; then
    error_exit "Failed to create snapshot $SNAPSHOT_NAME"
fi

log "Snapshot created successfully"

# Prune old hourly snapshots
log "Pruning old snapshots (retention policy: keep last $RETENTION_HOURLY hourly)"

SNAPSHOTS_TO_DELETE=$(zfs list -H -t snapshot -o name -s creation \
    | grep "^${DATASET}@auto-hourly-" \
    | head -n -"$RETENTION_HOURLY" || true)

if [ -n "$SNAPSHOTS_TO_DELETE" ]; then
    echo "$SNAPSHOTS_TO_DELETE" | while IFS= read -r old_snap; do
        log "Destroying old snapshot: $old_snap"
        if ! zfs destroy "$old_snap" 2>&1 | logger -t "zfs-snapshot" -p "${LOG_FACILITY}.info"; then
            log "Warning: Could not destroy $old_snap (may be in use or cloned)"
        fi
    done
else
    log "No snapshots to prune (current count within retention policy)"
fi

# Final summary
CURRENT_COUNT=$(zfs list -H -t snapshot -o name | grep -c "^${DATASET}@auto-hourly-" || echo "0")
log "Snapshot rotation completed successfully. Current hourly snapshot count: $CURRENT_COUNT"

exit 0
