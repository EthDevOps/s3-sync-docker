#!/bin/sh

echo "Adding S3 source..."
/usr/bin/mc alias set s3_source ${SOURCE_ENDPOINT} ${SOURCE_ACCESS_KEY} ${SOURCE_SECRET_KEY}

echo "Adding S3 destination..."
/usr/bin/mc alias set s3_destination ${DESTINATION_ENDPOINT} ${DESTINATION_ACCESS_KEY} ${DESTINATION_SECRET_KEY}

echo "Verifying source..."
/usr/bin/mc admin info s3_source

echo "Verifying source..."
/usr/bin/mc admin info s3_destination

echo "Start mirror..."
/usr/bin/mc mirror --overwrite ${MINIO_EXTRA_OPTS} s3_source/${SOURCE_BUCKET} s3_destination/${DESTINATION_BUCKET} && curl ${HEALTHCHECK_URL}
