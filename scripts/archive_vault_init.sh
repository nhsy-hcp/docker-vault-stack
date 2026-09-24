#!/bin/bash
# archive_vault_init.sh - Move vault-init.json into the backup folder before it is
# overwritten (task init) or removed (task down), so older snapshots stay restorable.

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-.backups}"

if [ ! -f vault-init.json ]; then
    exit 0
fi

mkdir -p "$BACKUP_DIR"
dest="$BACKUP_DIR/vault-init-$(date +"%Y%m%d-%H%M%S").json"
install -m 600 vault-init.json "$dest"
rm vault-init.json
echo "Archived vault-init.json to $dest"
