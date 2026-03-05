FROM php:8.3-cli-bookworm

# Build arguments for user mapping
ARG UID=1000
ARG GID=1000

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    unzip \
    libzip-dev \
    libfreetype6-dev \
    libjpeg-dev \
    libpng-dev \
    libldap2-dev \
    libicu-dev \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure ldap --with-libdir=lib/$(uname -m)-linux-gnu/ \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        zip \
        gd \
        ldap \
        intl \
        opcache

# Install Xdebug for coverage and debugging
RUN pecl install xdebug-3.3.1 \
    && docker-php-ext-enable xdebug

# Configure Xdebug
RUN echo "xdebug.mode=coverage,debug" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.start_with_request=trigger" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.client_port=9003" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Configure Composer cache directory
ENV COMPOSER_HOME=/tmp/composer-cache

# Create user with matching UID/GID from host
RUN groupadd -g ${GID} orangehrm \
    && useradd -u ${UID} -g orangehrm -m -s /bin/bash orangehrm

# Set working directory
WORKDIR /app

# Switch to non-root user
USER orangehrm

# Set PHP memory limit for tests
ENV PHP_MEMORY_LIMIT=1G
