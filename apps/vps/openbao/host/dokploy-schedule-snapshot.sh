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
GARAGE_FAILED=0
if ! docker run --rm \
  -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  -v "$BACKUP_DIR:/data:ro" \
  amazon/aws-cli \
  --cli-connect-timeout 10 --cli-read-timeout 30 \
  --endpoint-url "$ENDPOINT" s3 cp "/data/$SNAP_NAME" "s3://$BUCKET/openbao/$SNAP_NAME"; then
  echo "WARNING: Garage upload failed (is homelab reachable?). Continuing to offsite backup..." >&2
  GARAGE_FAILED=1
else
  echo "[$(date -u '+%F %TZ')] 4. Managing Garage retention (keeping last 14 backups)..."
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
fi

# Tier 2: Offsite backup to Backblaze B2 (client-side encrypted by OpenBao)
B2_FAILED=0
if [ -n "${B2_ENDPOINT_URL:-}" ] && [ -n "${B2_BUCKET:-}" ]; then
  echo "[$(date -u '+%F %TZ')] 5. Uploading to Backblaze B2 (s3://$B2_BUCKET/openbao/$SNAP_NAME)..."
  if ! docker run --rm \
    -e AWS_ACCESS_KEY_ID="${B2_ACCESS_KEY_ID:?}" \
    -e AWS_SECRET_ACCESS_KEY="${B2_SECRET_ACCESS_KEY:?}" \
    -e AWS_DEFAULT_REGION="${B2_REGION:-eu-central-003}" \
    -v "$BACKUP_DIR:/data:ro" \
    amazon/aws-cli \
    --endpoint-url "$B2_ENDPOINT_URL" s3 cp "/data/$SNAP_NAME" "s3://$B2_BUCKET/openbao/$SNAP_NAME"; then
    echo "ERROR: Backblaze B2 upload failed." >&2
    B2_FAILED=1
  else
    echo "[$(date -u '+%F %TZ')] 6. Managing B2 retention (keeping last 14 backups)..."
    docker run --rm \
      -e AWS_ACCESS_KEY_ID="${B2_ACCESS_KEY_ID:?}" \
      -e AWS_SECRET_ACCESS_KEY="${B2_SECRET_ACCESS_KEY:?}" \
      -e AWS_DEFAULT_REGION="${B2_REGION:-eu-central-003}" \
      amazon/aws-cli \
      --endpoint-url "$B2_ENDPOINT_URL" s3 ls "s3://$B2_BUCKET/openbao/" | sort | head -n -14 | while read -r line; do
      old_file=$(echo "$line" | awk '{print $4}')
      if [ -n "$old_file" ]; then
        echo "Pruning old B2 backup: s3://$B2_BUCKET/openbao/$old_file"
        docker run --rm \
          -e AWS_ACCESS_KEY_ID="${B2_ACCESS_KEY_ID:?}" \
          -e AWS_SECRET_ACCESS_KEY="${B2_SECRET_ACCESS_KEY:?}" \
          -e AWS_DEFAULT_REGION="${B2_REGION:-eu-central-003}" \
          amazon/aws-cli \
          --endpoint-url "$B2_ENDPOINT_URL" s3 rm "s3://$B2_BUCKET/openbao/$old_file"
      fi
    done
  fi
else
  echo "[$(date -u '+%F %TZ')] 5. Backblaze B2 not configured in $CONF, skipping Tier 2."
fi

if [ "$GARAGE_FAILED" -ne 0 ] && [ "$B2_FAILED" -ne 0 ]; then
  echo "ERROR: Both Garage and Backblaze B2 uploads failed." >&2
  exit 1
elif [ "$B2_FAILED" -ne 0 ]; then
  echo "ERROR: Backblaze B2 offsite backup failed." >&2
  exit 1
fi

echo "[$(date -u '+%F %TZ')] === Backup completed successfully ==="
