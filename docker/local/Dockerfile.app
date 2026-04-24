# Local "live app" image: takes the current working tree, installs PHP and JS
# deps, builds the Vue clients, and serves the app via Apache.
#
# Build with: make local-build
# Run with:   make local-up   (http://localhost:8080)

ARG BASE_IMAGE=orangehrm-local-base:latest
FROM ${BASE_IMAGE}

WORKDIR /var/www/html

# Copy the application source (everything needed to install + build).
# .dockerignore keeps node_modules, vendor, dist out.
COPY index.php .htaccess ./
COPY web ./web
COPY installer ./installer
COPY src ./src
COPY bin ./bin

# PHP deps (production)
RUN composer install -d src --no-dev --optimize-autoloader --classmap-authoritative

# Build Vue clients with the bundled Yarn 4 (.yarn/releases)
RUN cd src/client && yarn install --immutable && yarn build
RUN cd installer/client && yarn install --immutable && yarn build

# Drop dev artifacts to keep the image lean
RUN rm -rf src/client/node_modules installer/client/node_modules

# Permissions for writable runtime dirs
RUN mkdir -p lib/confs/cryptokeys src/cache src/log src/config/proxy \
    && chown www-data:www-data . \
    && chown -R www-data:www-data lib/confs src/cache src/log src/config \
    && chmod -R 775 lib/confs src/cache src/log src/config

VOLUME ["/var/www/html/lib/confs", "/var/www/html/src/cache", "/var/www/html/src/log"]

# Reuse the production entrypoint (runs cli_install.php on first boot using
# ORANGEHRM_DB_* / ORANGEHRM_ADMIN_* env vars). The local wrapper additionally
# tails Monolog logs to stderr so they show up in `make local-logs`.
COPY docker-entrypoint.sh /usr/local/bin/orangehrm-entrypoint.sh
COPY docker/local/local-entrypoint.sh /usr/local/bin/local-entrypoint.sh
RUN chmod +x /usr/local/bin/orangehrm-entrypoint.sh /usr/local/bin/local-entrypoint.sh

ENTRYPOINT ["local-entrypoint.sh"]
CMD ["apache2-foreground"]
