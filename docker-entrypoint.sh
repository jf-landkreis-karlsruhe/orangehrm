#!/bin/bash
set -e

CONF_FILE="/var/www/html/lib/confs/Conf.php"
CLI_CONFIG="/var/www/html/installer/cli_install_config.yaml"

# ---------------------------------------------------------------------------
# First-boot: run the CLI installer to configure the database connection and
# write lib/confs/Conf.php. On subsequent starts the file already exists and
# we skip straight to starting Apache.
# ---------------------------------------------------------------------------
if [ ! -f "$CONF_FILE" ]; then
    echo "[entrypoint] First boot detected – running installer..."

    # Required env vars (fail fast if missing)
    : "${ORANGEHRM_DB_HOST:?ORANGEHRM_DB_HOST is required}"
    : "${ORANGEHRM_DB_NAME:?ORANGEHRM_DB_NAME is required}"
    : "${ORANGEHRM_DB_USER:?ORANGEHRM_DB_USER is required}"
    : "${ORANGEHRM_DB_PASSWORD:?ORANGEHRM_DB_PASSWORD is required}"

    # Optional with defaults
    ORANGEHRM_DB_PORT="${ORANGEHRM_DB_PORT:-3306}"
    ORANGEHRM_ADMIN_USER="${ORANGEHRM_ADMIN_USER:-Admin}"
    ORANGEHRM_ADMIN_PASSWORD="${ORANGEHRM_ADMIN_PASSWORD:-Ohrm@1423}"

    # Wait for the database to be reachable (up to 60s)
    echo "[entrypoint] Waiting for database at ${ORANGEHRM_DB_HOST}:${ORANGEHRM_DB_PORT}..."
    for i in $(seq 1 30); do
        if php -r "
            try {
                new PDO(
                    'mysql:host=${ORANGEHRM_DB_HOST};port=${ORANGEHRM_DB_PORT};dbname=${ORANGEHRM_DB_NAME}',
                    '${ORANGEHRM_DB_USER}',
                    '${ORANGEHRM_DB_PASSWORD}',
                    [PDO::ATTR_TIMEOUT => 3]
                );
                exit(0);
            } catch (Exception \$e) {
                exit(1);
            }
        " 2>/dev/null; then
            echo "[entrypoint] Database is ready."
            break
        fi
        if [ "$i" -eq 30 ]; then
            echo "[entrypoint] ERROR: Database not reachable after 60s. Aborting."
            exit 1
        fi
        echo "[entrypoint] Attempt $i/30 – database not ready, retrying in 2s..."
        sleep 2
    done

    # Write cli_install_config.yaml from env vars (the installer always reads
    # from this fixed path, so we overwrite it in-place)
    cat > "$CLI_CONFIG" <<EOF
database:
  hostName: ${ORANGEHRM_DB_HOST}
  hostPort: ${ORANGEHRM_DB_PORT}
  databaseName: ${ORANGEHRM_DB_NAME}
  privilegedDatabaseUser: ${ORANGEHRM_DB_USER}
  privilegedDatabasePassword: ${ORANGEHRM_DB_PASSWORD}
  useSameDbUserForOrangeHRM: y
  orangehrmDatabaseUser: ~
  orangehrmDatabasePassword: ~
  isExistingDatabase: y
  enableDataEncryption: n

organization:
  name: OrangeHRM
  country: US

admin:
  adminUserName: ${ORANGEHRM_ADMIN_USER}
  adminPassword: ${ORANGEHRM_ADMIN_PASSWORD}
  adminEmployeeFirstName: OrangeHRM
  adminEmployeeLastName: Admin
  workEmail: admin@example.com
  contactNumber: ~
  registrationConsent: true

license:
  agree: y
EOF

    php -d memory_limit=512M /var/www/html/installer/cli_install.php

    echo "[entrypoint] Installation complete."
else
    echo "[entrypoint] Existing installation detected – skipping installer."
fi

# Hand off to Apache (the default CMD from the base image)
exec "$@"
