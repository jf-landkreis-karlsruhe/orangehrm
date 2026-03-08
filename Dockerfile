# Stage 1: Build Vue assets (main app + installer)
FROM node:20-bookworm AS node-builder

RUN corepack enable \
    && COREPACK_ENABLE_STRICT=0 corepack prepare yarn@4.1.0 --activate

WORKDIR /build

# Install main app dependencies
COPY src/client/package.json src/client/yarn.lock* src/client/.yarnrc.yml* ./src/client/
COPY src/client/.yarn ./src/client/.yarn
RUN cd src/client && yarn install --immutable

# Install installer client dependencies
COPY installer/client/package.json installer/client/yarn.lock* installer/client/.yarnrc.yml* ./installer/client/
COPY installer/client/.yarn ./installer/client/.yarn
RUN cd installer/client && yarn install --immutable

# Copy source and build
COPY src/client ./src/client
RUN cd src/client && yarn build

COPY installer/client ./installer/client
RUN cd installer/client && yarn build


# Stage 2: Install PHP production dependencies
FROM composer:2 AS composer-builder

WORKDIR /build

COPY src/composer.json src/composer.lock ./src/
COPY src /build/src

RUN composer install --no-dev --optimize-autoloader --classmap-authoritative -d src

COPY devTools/core/composer.json devTools/core/composer.lock ./devTools/core/
COPY devTools/core /build/devTools/core

RUN composer install --no-dev --optimize-autoloader -d devTools/core


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

# Enable Apache mod_rewrite
RUN a2enmod rewrite headers

WORKDIR /var/www/html

# Copy application source (runtime files only)
COPY index.php .htaccess ./
COPY web/index.php web/.htaccess web/images web/robots.txt ./web/
COPY installer ./installer
COPY src/lib ./src/lib
COPY src/plugins ./src/plugins
COPY src/config ./src/config
COPY bin ./bin
COPY lib ./lib

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
