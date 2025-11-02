#!/bin/bash
# Immich S3 Backup Script
# Place this in /usr/local/bin/immich-backup.sh

set -e

# Configuration
IMMICH_ROOT="/var/lib/immich"
POSTGRES_CONTAINER="immich_postgres"
S3_BUCKET="your-immich-backups"
S3_PREFIX="immich-backups"
BACKUP_DIR="/tmp/immich-backup-latest"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ARCHIVE_SNAPSHOTS=true  # Set to false to disable timestamped snapshots

# Logging
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting Immich backup process..."

# Clean and recreate backup directory
rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL database
log "Backing up PostgreSQL database..."
docker exec -t "$POSTGRES_CONTAINER" pg_dumpall -c -U postgres >"$BACKUP_DIR/database.sql"

# Backup Immich upload directory
log "Backing up upload directory..."
tar -czf "$BACKUP_DIR/upload.tar.gz" -C "$IMMICH_ROOT" upload/

# Backup Immich configuration (if exists)
if [ -d "$IMMICH_ROOT/config" ]; then
  log "Backing up configuration..."
  tar -czf "$BACKUP_DIR/config.tar.gz" -C "$IMMICH_ROOT" config/
fi

# Create a manifest file
log "Creating backup manifest..."
cat >"$BACKUP_DIR/manifest.txt" <<EOF
Backup Date: $(date)
Hostname: $(hostname)
Immich Version: $(docker exec immich_server cat /usr/src/app/package.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]' || echo "unknown")
Files:
$(ls -lh "$BACKUP_DIR")
EOF

# Sync to S3 (primary sync location - always current)
log "Syncing backup to S3..."
aws s3 sync "$BACKUP_DIR" "s3://$S3_BUCKET/$S3_PREFIX/latest/" \
  --storage-class INTELLIGENT_TIERING \
  --delete \
  --no-progress

# Optionally create a timestamped snapshot for point-in-time recovery
if [ "$ARCHIVE_SNAPSHOTS" = true ]; then
  log "Creating timestamped snapshot..."
  aws s3 sync "$BACKUP_DIR" "s3://$S3_BUCKET/$S3_PREFIX/snapshots/$TIMESTAMP/" \
    --storage-class INTELLIGENT_TIERING \
    --no-progress
fi

# Verify upload
if [ $? -eq 0 ]; then
  log "Backup successfully synced to s3://$S3_BUCKET/$S3_PREFIX/latest/"
  [ "$ARCHIVE_SNAPSHOTS" = true ] && log "Snapshot saved to s3://$S3_BUCKET/$S3_PREFIX/snapshots/$TIMESTAMP/"
else
  log "ERROR: Backup sync failed!"
  exit 1
fi

# Cleanup
log "Cleaning up temporary files..."
rm -rf "$BACKUP_DIR"

log "Backup completed successfully!"
