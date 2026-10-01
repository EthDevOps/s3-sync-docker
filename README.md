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
- `CRYPT_PASSWORD` / `CRYPT_SALT` - enable client-side encryption ([rclone crypt](https://rclone.org/crypt/)) of everything written to the destination. **Required** with the built-in B2 template; optional with a custom `RCLONE_TMPL`.

## Encryption

With `CRYPT_PASSWORD` set, the destination is wrapped in an rclone crypt remote
(NaCl secretbox: XSalsa20 + Poly1305, so tampering is detected on read). File
names stay readable with a `.bin` suffix. Restore with any rclone using the same
password and salt:

```ini
[b2]
type = b2
account = <key id>
key = <app key>

[b2crypt]
type = crypt
remote = b2:
password = <rclone obscure PASSWORD>
password2 = <rclone obscure SALT>
filename_encryption = off
directory_name_encryption = false
```

`rclone copy b2crypt:<bucket>/<path> ./restore` decrypts;
`rclone cryptcheck <source> b2crypt:<bucket>` verifies a copy.

## Monitoring

