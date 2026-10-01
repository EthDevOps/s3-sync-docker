#!/bin/sh
# Fail on any error so a broken sync can never report success. No -x: it would
# print CRYPT_PASSWORD and other secrets into the job logs.
set -eo pipefail

# busybox ash has no ERR trap; ping /fail from EXIT when the script failed
trap 'rc=$?; if [ $rc -ne 0 ]; then echo "Sync FAILED (exit $rc)"; [ -n "$HEALTHCHECK_URL" ] && curl -fsS -m 10 --retry 3 "$HEALTHCHECK_URL/fail" >/dev/null || true; fi' EXIT

echo "Generating rclone config..."
TMPL="/etc/rclone.conf.tmpl"
if [ -n "$RCLONE_TMPL" ]; then
    echo "== USING CUSTOM TEMPLATE: $RCLONE_TMPL =="
    TMPL="$RCLONE_TMPL"
fi
cat $TMPL | envsubst > /etc/rclone.conf

# Client-side encryption (rclone crypt). The crypt remote wraps the destination,
# so the destination only ever holds ciphertext. File/dir names stay readable
# (".bin" suffix) to keep restores and bucket watchers simple.
DST="sync_dst"
if [ -n "$CRYPT_PASSWORD" ]; then
    [ -n "$CRYPT_SALT" ] || { echo "=> ERROR: CRYPT_PASSWORD set without CRYPT_SALT"; exit 1; }
    echo "== CRYPT ENCRYPTION ENABLED =="
    cat >> /etc/rclone.conf <<EOC

[sync_crypt]
type = crypt
remote = sync_dst:
password = $(rclone obscure "$CRYPT_PASSWORD")
password2 = $(rclone obscure "$CRYPT_SALT")
filename_encryption = off
directory_name_encryption = false
EOC
    DST="sync_crypt"
elif [ -z "$RCLONE_TMPL" ]; then
    # The built-in template targets B2 (offsite) - never ship plaintext there
    echo "=> ERROR: built-in B2 template requires CRYPT_PASSWORD/CRYPT_SALT"
    exit 1
else
    echo "== CRYPT ENCRYPTION DISABLED (custom template, no CRYPT_PASSWORD) =="
fi

echo "Running rclone sync..."
DEBUG=""

if [[ "$MINIO_DEBUG" == "1" ]]; then
    echo "== DEBUG ENABLED =="
    DEBUG="--debug"
fi

BW_LIMIT=""

if [ -n "$BANDWIDTH_LIMIT" ]; then
  echo "== BANDWIDTH LIMITER ENABLED ($BANDWIDTH_LIMIT) =="
  BW_LIMIT="--bwlimit=$BANDWIDTH_LIMIT"
fi

if [ -n "$DO_ATOMIC" ]; then
  echo "== ATOMIC MODE ENABLED =="
  echo "=> Syncing from source..."
  rclone --progress $BW_LIMIT --config=/etc/rclone.conf sync sync_src:${SOURCE_BUCKET} ${DST}:${DESTINATION_TMP_BUCKET} --compare-dest=${DST}:${DESTINATION_BUCKET} ${EXTRA_SYNC_ARGS}
  echo "=> Moving..."
  rclone --config=/etc/rclone.conf move ${DST}:${DESTINATION_TMP_BUCKET} ${DST}:${DESTINATION_BUCKET}
else
  echo "=> Syncing from source..."
  rclone --progress $BW_LIMIT --config=/etc/rclone.conf sync sync_src:${SOURCE_BUCKET} ${DST}:${DESTINATION_BUCKET} ${EXTRA_SYNC_ARGS}
fi

# The sync already succeeded; a failed ping must not fail the job
if [ -n "$HEALTHCHECK_URL" ]; then
    curl -fsS -m 10 --retry 3 "$HEALTHCHECK_URL" || echo "WARN: Healthchecks ping failed"
fi
