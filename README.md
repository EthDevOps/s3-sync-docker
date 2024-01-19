# s3-sync-docker

A docker image to syncronise two S3-compatible storage buckets.
It syncornizes only from the source to the destination.

Sync is using the [minio-client](https://min.io/docs/minio/linux/reference/minio-mc.html)'s `mirror` command.

## Configuration

All configuration is done via environment variables:

- `SOURCE_ENDPOINT` - Host for the source (eg. `http://localhost:9000`)
- `SOURCE_ACCESS_KEY` - Access-key/username for the source
- `SOURCE_SECRET_KEY` - Secretkey/password for the source
- `SOURCE_BUCKET` - The bucket on the source to replicate
- `DESTINATION_ENDPOINT` - Host for the destination (eg. `http://localhost:9000`)
- `DESTINATION_ACCESS_KEY` - Access-key/username for the destination
- `DESTINATION_SECRET_KEY` - Secretkey/password for the destination
- `DESTINATION_BUCKET` - The bucket on the destination to replicate
- `MINIO_EXTRA_ARGS` - Additiona arguments to pass to the underlying `mc mirror` command
- `HEALTHCHECK_URL` - URL to ping after the run

## Monitoring

