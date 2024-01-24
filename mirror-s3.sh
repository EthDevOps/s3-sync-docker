#!/bin/sh
echo "Generating rclone config..."
envsubst < /etc/rclone.conf.tmpl > /etc/rclone.conf

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

rclone --progress --config=/etc/rclone.conf sync sync_src:${SOURCE_BUCKET} sync_dst:${DESTINATION_BUCKET} && curl ${HEALTHCHECK_URL}
