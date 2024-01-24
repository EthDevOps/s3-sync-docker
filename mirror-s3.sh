#!/bin/sh
DEBUG=""

if [[ "$MINIO_DEBUG" == "1" ]]; then
    echo "== DEBUG ENABLED =="
    DEBUG="--debug"
fi


echo "Adding S3 source..."
/usr/bin/mc alias set s3_source ${SOURCE_ENDPOINT} ${SOURCE_ACCESS_KEY} ${SOURCE_SECRET_KEY}

echo "Adding S3 destination..."
/usr/bin/mc alias set s3_destination ${DESTINATION_ENDPOINT} ${DESTINATION_ACCESS_KEY} ${DESTINATION_SECRET_KEY}

echo "Start mirror..."
/usr/bin/mc ${DEBUG} mirror --overwrite ${MINIO_EXTRA_OPTS} s3_source/${SOURCE_BUCKET} s3_destination/${DESTINATION_BUCKET} && curl ${HEALTHCHECK_URL}
