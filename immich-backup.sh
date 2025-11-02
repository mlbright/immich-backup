#!/bin/bash
# Immich S3 Backup Script
# Place this in /usr/local/bin/immich-backup.sh

set -e

# Configuration
IMMICH_USER="immich"
IMMICH_ROOT="/home/$IMMICH_USER/Immich"
LIBRARY="$IMMICH_ROOT/library"
POSTGRES="$IMMICH_ROOT/postgres"
S3_BUCKET="immich-backups"

# Logging
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting Immich backup process..."

# Sync to S3 (primary sync location - always current)
log "Syncing to S3..."

# Sync configuration files
aws s3 sync "$IMMICH_ROOT/*" "s3://$S3_BUCKET/latest" \
  --storage-class INTELLIGENT_TIERING \
  --delete \
  --no-progress

# Sync media library
log "Syncing media library..."
aws s3 sync "$LIBRARY/" "s3://$S3_BUCKET/latest/library/" \
  --storage-class INTELLIGENT_TIERING \
  --delete \
  --no-progress

log "Backup completed successfully!"