#!/bin/bash
# Snapshot streaming, token renewal, S3 upload and bucket listing verified live 2026-10-29.
# Configuration file permissions: /etc/dokploy/snapshot.env must be mode 600, root only.
set -euo pipefail

CONF="/etc/dokploy/snapshot.env"
if [ ! -f "$CONF" ]; then
  echo "ERROR: Configuration file $CONF not found." >&2
  exit 1
fi
. "$CONF"

if [ -z "${BAO_TOKEN:-}" ]; then
  echo "ERROR: BAO_TOKEN is not set in $CONF." >&2
  exit 1
fi

BAO_ADDR="https://${BAO_DOMAIN:?}:8200"
RESOLVE="${BAO_DOMAIN}:8200:${TAILSCALE_IP:?}"
ENDPOINT="${AWS_ENDPOINT_URL:?}"
BUCKET="${S3_BUCKET:-dockploy}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SNAP_NAME="openbao-${TIMESTAMP}.snap"

BACKUP_DIR="/etc/dokploy/backups/openbao"
mkdir -p -m 700 "$BACKUP_DIR"
trap 'rm -rf "$BACKUP_DIR"' EXIT

SNAP_PATH="${BACKUP_DIR}/${SNAP_NAME}"

echo "[$(date -u '+%F %TZ')] === Starting OpenBao Raft Snapshot Backup ==="

echo "[$(date -u '+%F %TZ')] 1. Renewing snapshot token..."
curl -f -s --resolve "$RESOLVE" -X POST -H "X-Vault-Token: $BAO_TOKEN" "$BAO_ADDR/v1/auth/token/renew-self" >/dev/null

if [ -n "${DOKPLOY_BAO_TOKEN:-}" ]; then
  echo "[$(date -u '+%F %TZ')] 1b. Renewing Dokploy OpenBao provider token..."
  curl -f -s --resolve "$RESOLVE" -X POST -H "X-Vault-Token: $DOKPLOY_BAO_TOKEN" "$BAO_ADDR/v1/auth/token/renew-self" >/dev/null
fi

echo "[$(date -u '+%F %TZ')] 2. Fetching Raft snapshot from OpenBao..."
curl -f -s --resolve "$RESOLVE" -H "X-Vault-Token: $BAO_TOKEN" "$BAO_ADDR/v1/sys/storage/raft/snapshot" -o "$SNAP_PATH"

SIZE=$(stat -c%s "$SNAP_PATH" 2>/dev/null || wc -c < "$SNAP_PATH")
echo "[$(date -u '+%F %TZ')] Snapshot saved to $SNAP_PATH (${SIZE} bytes)"

if [ "$SIZE" -lt 1000 ]; then
  echo "ERROR: Snapshot size is suspiciously small (${SIZE} bytes). Aborting." >&2
  exit 1
fi

echo "[$(date -u '+%F %TZ')] 3. Uploading to Garage S3 (s3://$BUCKET/openbao/$SNAP_NAME)..."
docker run --rm \
  -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  -v "$BACKUP_DIR:/data:ro" \
  amazon/aws-cli \
  --endpoint-url "$ENDPOINT" s3 cp "/data/$SNAP_NAME" "s3://$BUCKET/openbao/$SNAP_NAME"

echo "[$(date -u '+%F %TZ')] 4. Managing retention (keeping last 14 backups)..."
docker run --rm \
  -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  amazon/aws-cli \
  --endpoint-url "$ENDPOINT" s3 ls "s3://$BUCKET/openbao/" | sort | head -n -14 | while read -r line; do
  old_file=$(echo "$line" | awk '{print $4}')
  if [ -n "$old_file" ]; then
    echo "Pruning old backup: s3://$BUCKET/openbao/$old_file"
    docker run --rm \
      -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
      -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
      amazon/aws-cli \
      --endpoint-url "$ENDPOINT" s3 rm "s3://$BUCKET/openbao/$old_file"
  fi
done

echo "[$(date -u '+%F %TZ')] === Backup completed successfully ==="
