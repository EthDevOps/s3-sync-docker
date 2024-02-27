#!/bin/sh
echo "Generating rclone config..."
TMPL="/etc/rclone.conf.tmp"
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
rclone --progress $BW_LIMIT --config=/etc/rclone.conf sync sync_src:${SOURCE_BUCKET} sync_dst:${DESTINATION_BUCKET} && curl ${HEALTHCHECK_URL}
