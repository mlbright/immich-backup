#!/bin/bash
# Immich S3 Backup Script
# Place this in /usr/local/bin/immich-backup.sh

set -e

# Configuration
S3_BUCKET="immich-backups"

# Logging
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting Immich backup process..."

IMMICH_USER="$(whoami)"
IMMICH_ROOT="/home/$IMMICH_USER/Immich"

# Sync to S3 (primary sync location - always current)
log "Syncing to S3..."

# Sync configuration files
config_files=("docker-compose.yml" ".env" "hwaccel.ml.yml" "hwaccel.transcoding.yml")
for file in "${config_files[@]}"; do
  if [ -f "$IMMICH_ROOT/$file" ]; then
    aws s3 cp "$IMMICH_ROOT/$file" "s3://$S3_BUCKET/latest/$file" \
      --storage-class INTELLIGENT_TIERING \
      --no-progress
  fi
done

# # Sync media library
# log "Syncing media library..."
# aws s3 sync "$IMMICH_ROOT/library/" "s3://$S3_BUCKET/latest/library/" \
#   --storage-class INTELLIGENT_TIERING \
#   --delete \
#   --no-progress

# Sync PostgreSQL database

sudo docker compose down

aws s3 sync "$IMMICH_ROOT/postgres/" "s3://$S3_BUCKET/latest/postgres/" \
  --storage-class INTELLIGENT_TIERING \
  --delete \
  --no-progress

sudo docker compose up -d

log "Backup completed successfully!"