#!/bin/sh
echo "Generating rclone config..."
TMPL="/etc/rclone.conf.tmpl"
if [ -n "$RCLONE_TMPL" ]; then
    echo "== USING CUSTOM TEMPLATE: $RCLONE_TMPL =="
    TMPL="$RCLONE_TMPL"
fi
cat $TMPL | envsubst > /etc/rclone.conf

echo "Running rclone sync..."
DEBUG=""

if [[ "$MINIO_DEBUG" == "1" ]]; then
    echo "== DEBUG ENABLED =="
    DEBUG="--debug"
fi

if [[ "$MINIO_OVERWRITE" == "1" ]]; then
    echo "== OVERWRITE ENABLED =="
    OVERWRITE="--overwrite"
fi

BW_LIMIT=""

if [ -n "$BANDWIDTH_LIMIT" ]; then
  echo "== BANDWIDTH LIMITER ENABLED ($BANDWIDTH_LIMIT) =="
  BW_LIMIT="--bwlimit=$BANDWIDTH_LIMIT"
fi

if [ -n "$DO_ATOMIC" ]; then
  echo "== ATOMIC MODE ENABLED =="
  echo "=> Syncing from source..."
  rclone --progress $BW_LIMIT --config=/etc/rclone.conf sync sync_src:${SOURCE_BUCKET} sync_dst:${DESTINATION_TMP_BUCKET} --compare-dest=sync_dst:${DESTINATION_BUCKET}
  echo "=> Moving..."
  rclone --config=/etc/rclone.conf move sync_dst:${DESTINATION_TMP_BUCKET} sync_dst:${DESTINATION_BUCKET}
else
  echo "=> Syncing from source..."
  rclone --progress $BW_LIMIT --config=/etc/rclone.conf sync sync_src:${SOURCE_BUCKET} sync_dst:${DESTINATION_BUCKET}
fi
curl ${HEALTHCHECK_URL}
