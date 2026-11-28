# Docker Sandbox workload for this repo: Claude Code plus the native dev
# toolchain, close to CI (.github/workflows/test.yml): PHP + extensions,
# Composer 2, Node 20 / Yarn 4 via corepack, MariaDB on 127.0.0.1 (root/root).
# The template also ships Docker CLI and a private engine for `make local-*`.

FROM docker/sandbox-templates:claude-code

USER root

# The template is Ubuntu 26.04, which only ships PHP 8.5 (ondrej/php has no
# 8.3 for it either). 8.5 is covered by the php_test CI matrix; CI's main jobs
# and php-cs-fixer use 8.3. OPcache is built into PHP 8.5.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        make \
        unzip \
        git \
        curl \
        ca-certificates \
        php8.5-cli \
        php8.5-mysql \
        php8.5-zip \
        php8.5-gd \
        php8.5-ldap \
        php8.5-intl \
        php8.5-curl \
        php8.5-mbstring \
        php8.5-xml \
        php8.5-xdebug \
        mariadb-server \
        mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# The Makefile runs php-cs-fix --php php8.3 (matches CI); alias it to 8.5.
RUN ln -s /usr/bin/php8.5 /usr/local/bin/php8.3

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Node 20 + corepack (Yarn 4 comes from each workspace's .yarn/releases).
# Ubuntu's nodejs 22 has a higher version, so raise NodeSource's own pin
# (600) above 1000 to allow the downgrade.
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && printf 'Package: nodejs\nPin: origin deb.nodesource.com\nPin-Priority: 1001\n' \
        > /etc/apt/preferences.d/nodejs \
    && apt-get install -y --no-install-recommends --allow-downgrades nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable
RUN node -v | grep -q '^v20\.' \
    || { echo "expected Node 20 first on PATH, got $(node -v)" >&2; exit 1; }

# MariaDB: password login root/root over TCP, as in CI and
# installer/cli_install_config.yaml; sudo mysql keeps working via unix_socket.
RUN mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld \
    && (mysqld_safe --skip-syslog > /dev/null 2>&1 &) \
    && until mysqladmin ping --silent; do sleep 1; done \
    && mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('root') OR unix_socket; FLUSH PRIVILEGES;" \
    && mysqladmin -uroot -proot shutdown

COPY orangehrm-agent /usr/local/bin/orangehrm-agent
RUN chmod 0755 /usr/local/bin/orangehrm-agent

# ORANGEHRM_SANDBOX switches the Makefile to native tools.
ENV ORANGEHRM_SANDBOX=1 \
    XDEBUG_MODE=off \
    CI=1 \
    COREPACK_ENABLE_STRICT=0 \
    COREPACK_ENABLE_AUTO_PIN=0

USER agent
ENTRYPOINT ["/usr/local/bin/orangehrm-agent"]
CMD []
