#!/bin/bash
# Builds the image and runs mirror-s3.sh with stub rclone/curl to check exit
# codes and Healthchecks pings for a good and a failing sync. Needs docker.
set -u
cd "$(dirname "$0")"
IMG=s3-sync-test:local
docker build -q -t $IMG . >/dev/null || { echo "build failed"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

printf '#!/bin/sh\necho "rclone $*" >> /out/calls\n[ "$FAIL_RCLONE" = 1 ] && exit 7\nexit 0\n' > "$T/rclone"
printf '#!/bin/sh\nfor a; do u=$a; done\necho "curl $u" >> /out/calls\n' > "$T/curl"
chmod +x "$T/rclone" "$T/curl"

run() {
  : > "$T/calls"
  docker run --rm -e FAIL_RCLONE="$1" -e HEALTHCHECK_URL=https://hc/ping/x \
    -e SOURCE_BUCKET=src -e DESTINATION_BUCKET=dst \
    -v "$T/rclone:/usr/bin/rclone:ro" -v "$T/curl:/usr/bin/curl:ro" -v "$T:/out" \
    $IMG >/dev/null 2>&1
}

fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

run 0; rc=$?
check "good sync exits 0"          '[ $rc -eq 0 ]'
check "good sync pings success"    'grep -qx "curl https://hc/ping/x" "$T/calls"'

run 1; rc=$?
check "failed sync exits non-zero" '[ $rc -ne 0 ]'
check "failed sync pings /fail"    'grep -qx "curl https://hc/ping/x/fail" "$T/calls"'
check "failed sync no success ping" '! grep -qx "curl https://hc/ping/x" "$T/calls"'

exit $fail
