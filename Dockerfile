# Stage 1: Build Vue assets (main app + installer)
FROM node:20-bookworm AS node-builder

WORKDIR /build

# Copy src/client and installer/client fully (yarn binary is in .yarn/releases/)
COPY src/client ./src/client
COPY installer/client ./installer/client

# Install and build main app
RUN cd src/client && yarn install --immutable && yarn build

# Install and build installer client
RUN cd installer/client && yarn install --immutable && yarn build


# Stage 2: Install PHP production dependencies
FROM composer:2 AS composer-builder

WORKDIR /build

COPY src /build/src
COPY bin /build/bin
COPY installer /build/installer

RUN composer install --no-dev --optimize-autoloader --classmap-authoritative --ignore-platform-reqs -d src


# Stage 3: Runtime image
FROM php:8.3-apache-bookworm

# Install system dependencies and PHP extensions
RUN set -ex; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libjpeg-dev \
        libpng-dev \
        libzip-dev \
        libldap2-dev \
        libicu-dev \
    ; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-configure ldap --with-libdir=lib/$(uname -m)-linux-gnu/; \
    docker-php-ext-install -j"$(nproc)" \
        gd \
        opcache \
        intl \
        pdo_mysql \
        zip \
        ldap \
    ; \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
        | sort -u \
        | xargs -r dpkg-query -S \
        | cut -d: -f1 \
        | sort -u \
        | xargs -rt apt-mark manual; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

# Use production php.ini and configure opcache
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=60'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Enable Apache mod_rewrite and headers, suppress ServerName warning
RUN a2enmod rewrite headers \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

WORKDIR /var/www/html

# Copy application source (runtime files only)
COPY index.php .htaccess ./
COPY web/index.php web/.htaccess web/images web/robots.txt ./web/
COPY installer ./installer
COPY src/lib ./src/lib
COPY src/plugins ./src/plugins
COPY src/config ./src/config
COPY bin ./bin

# Copy built assets from node-builder
COPY --from=node-builder /build/web/dist ./web/dist
COPY --from=node-builder /build/installer/client/dist ./installer/client/dist

# Copy PHP production dependencies from composer-builder
COPY --from=composer-builder /build/src/vendor ./src/vendor

# Create writable directories and set permissions
RUN mkdir -p lib/confs/cryptokeys src/cache src/log src/config/proxy \
    && chown www-data:www-data . \
    && chown -R www-data:www-data lib/confs src/cache src/log src/config \
    && chmod -R 775 lib/confs src/cache src/log src/config

VOLUME ["/var/www/html/lib/confs", "/var/www/html/src/cache", "/var/www/html/src/log"]

# Entrypoint: runs the CLI installer on first boot, then starts Apache
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
