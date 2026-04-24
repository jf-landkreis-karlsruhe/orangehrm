#!/bin/bash
# Local-only entrypoint wrapper: stream Monolog application logs to the
# container's stderr so `docker logs` / `make local-logs` shows them.
# Then delegate to the production docker-entrypoint.sh.
set -e

LOG_DIR="/var/www/html/src/log"
mkdir -p "$LOG_DIR"

# Pre-create the files Monolog will write to so `tail -F` can attach
# immediately (touch is a no-op if they already exist on the volume).
touch \
    "$LOG_DIR/orangehrm.log" \
    "$LOG_DIR/installer.log" \
    "$LOG_DIR/LDAP.log" \
    "$LOG_DIR/performance.log" 2>/dev/null || true

chown -R www-data:www-data "$LOG_DIR" 2>/dev/null || true

# Background tail; --pid=1 would be nicer but we don't know Apache's PID yet,
# so let it die naturally when the container stops.
tail -n 0 -F "$LOG_DIR"/*.log 2>/dev/null | sed -u 's|^|[php] |' >&2 &

exec /usr/local/bin/orangehrm-entrypoint.sh "$@"
