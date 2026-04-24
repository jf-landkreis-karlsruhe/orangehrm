<img width="40%" alt='OrangeHRM' src='https://raw.githubusercontent.com/wiki/orangehrm/orangehrm/logos/logo.svg#gh-light-mode-only'/><img width="40%" alt='OrangeHRM' src='https://raw.githubusercontent.com/wiki/orangehrm/orangehrm/logos/logo_dark_mode.svg#gh-dark-mode-only'/>

[![Docker Pulls](https://img.shields.io/docker/pulls/orangehrm/orangehrm.svg)](https://hub.docker.com/r/orangehrm/orangehrm) [![SourceForge Downloads](https://img.shields.io/sourceforge/dm/orangehrm.svg)](https://sourceforge.net/projects/orangehrm/) [![SourceForge Downloads](https://img.shields.io/sourceforge/dt/orangehrm.svg)](https://sourceforge.net/projects/orangehrm/)

# OrangeHRM Starter Application

OrangeHRM is a comprehensive Human Resource Management (HRM) System that captures all the essential functionalities required for any enterprise. Copyright (C) 2006 OrangeHRM Inc., http://www.orangehrm.com/

OrangeHRM is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.

OrangeHRM is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

## Getting started

### Docker Installation (Recommended)

The easiest way to run OrangeHRM is using Docker. Images are automatically built and published to GitHub Container Registry (GHCR) for each release.

**Using Docker Compose (recommended):**

```bash
# Create a .env file with your secrets
cat > .env <<'EOF'
MYSQL_ROOT_PASSWORD=change-me-root
ORANGEHRM_DB_NAME=orangehrm
ORANGEHRM_DB_USER=orangehrm
ORANGEHRM_DB_PASSWORD=change-me
EOF

# Start OrangeHRM + MariaDB
docker compose up -d
```

Open http://localhost in your browser. On first boot the installer runs automatically — this takes ~30 seconds. Subsequent starts are instant.

**Default login credentials:**
| Field | Value |
|-------|-------|
| Username | `Admin` |
| Password | `Ohrm@1423` |

Override the admin credentials on first boot via env vars:
```bash
ORANGEHRM_ADMIN_USER=MyAdmin
ORANGEHRM_ADMIN_PASSWORD=MySecret123
```

**Environment variables:**

| Variable | Required | Default | Description |
|---|---|---|---|
| `ORANGEHRM_DB_HOST` | yes | — | Database hostname |
| `ORANGEHRM_DB_NAME` | yes | — | Database name |
| `ORANGEHRM_DB_USER` | yes | — | Database username |
| `ORANGEHRM_DB_PASSWORD` | yes | — | Database password |
| `ORANGEHRM_DB_PORT` | no | `3306` | Database port |
| `ORANGEHRM_ADMIN_USER` | no | `Admin` | Admin username (first boot only) |
| `ORANGEHRM_ADMIN_PASSWORD` | no | `Ohrm@1423` | Admin password (first boot only) |

**Pull a specific version:**
```bash
docker pull ghcr.io/jf-landkreis-karlsruhe/orangehrm:5.8
```

**Available platforms:**
- `linux/amd64` (x86_64)
- `linux/arm64` (ARM 64-bit)

Docker images are automatically built and published when a new Git tag is pushed (e.g., `v5.8`, `v5.9.0`).

### Manual Installation

- Download the latest version of OrangeHRM Starter [here](https://sourceforge.net/projects/orangehrm/files/latest/download).

- Prerequisites and environment set up for installing OrangeHRM Starter:
  - [Install on Linux](https://starterhelp.orangehrm.com/hc/en-us/articles/6187572000540-Prerequisites-for-installing-OrangeHRM-Starter-in-Linux)
  - [Install on Windows](https://starterhelp.orangehrm.com/hc/en-us/articles/6187576427804-Prerequisites-for-installing-OrangeHRM-Starter-in-Windows)

- Install OrangeHRM using the web installer:
  - [OrangeHRM Starter Installation Guide](https://starterhelp.orangehrm.com/hc/en-us/articles/5295915003666-OrangeHRM-Starter-Installation-Guide)
  - [OrangeHRM Starter Upgrade Guide](https://starterhelp.orangehrm.com/hc/en-us/articles/6937346912402-OrangeHRM-Starter-Upgrade-Guide-For-5x-versions-)

- For further information on how to use the product please refer to the User Guides, Tutorial videos, and FAQs available on [Help Portal](https://starterhelp.orangehrm.com)

## Local Development with Docker

Two independent workflows ship in this fork:

1. **Tools containers** (`docker/dev/`) — pre-built PHP and Node images with all dependencies installed. Your working tree is bind-mounted in, so PHPUnit, Jest, and the linters run against the code on your disk; `fix-php` / `fix-js` write changes back to the host.
2. **Local live app** (`docker/local/`) — a base image plus an app image that bakes the current code, runs `composer install` and `yarn build`, and serves the result via Apache. No mount, no live reload — exactly what would ship.

### One-time setup

```bash
make build-dev-images   # builds php-tools and node-tools images
```

Re-run after changing `composer.lock` or any `yarn.lock`. Follow up with `make dev-down` to discard the cached `vendor/` and `node_modules` volumes.

### Running tests

```bash
make test-php                     # PHPUnit (test DB is set up automatically on first run)
make test-php ARGS="--testsuite Pim"
make test-js                      # Jest unit tests in src/client
make test-js  ARGS="--watch"
```

The test DB is installed once per dev session into `mariadb-test` (tmpfs). It is rebuilt automatically after `make dev-down`.

### Linting and formatting

```bash
make lint        # lint-php + lint-js (read-only)
make fix-php     # apply PHP coding-standard fixes
make fix-js      # apply ESLint --fix in all JS workspaces
```

### Local live app

```bash
make local-build   # build the base image (cached) and the app image from current code
make local-up      # http://localhost:8080  (first boot installs OrangeHRM, ~30s)
make local-logs    # tail app logs
make local-down    # stop (DB + install state are preserved in named volumes)
make local-reset   # stop and wipe DB + install state (next local-up reinstalls)
```

**Default login credentials:**
| Field | Value |
|-------|-------|
| Username | `Admin` |
| Password | `Ohrm@1423` |

Override the admin credentials before the first `make local-up`:
```bash
ORANGEHRM_ADMIN_USER=MyAdmin ORANGEHRM_ADMIN_PASSWORD=MySecret123 make local-up
```

### All make targets

Run `make help`.

## OrangeHRM Mobile App

<a href="https://play.google.com/store/apps/details?id=com.orangehrm.opensource" target="_blank">
<img height="54" alt='Get it on Google Play'
    src='https://raw.githubusercontent.com/wiki/orangehrm/orangehrm/mobile/play_store_cropped_en_US_2022_08_04.png'/>
</a>
<a href="https://apps.apple.com/us/app/orangehrm/id1527247547" target="_blank">
<img height="54" alt='Download on the App Store'
    src='https://raw.githubusercontent.com/wiki/orangehrm/orangehrm/mobile/app_store_en_US.svg'/>
</a>

## Resources

### Demo
Live demo is available at : https://opensource-demo.orangehrmlive.com

### Releases
Sourceforge : https://sourceforge.net/p/orangehrm

### Website
https://www.orangehrm.com/

## Help & Support
Submit your help requests through [OrangeHRM Help Portal](https://starterhelp.orangehrm.com/hc/en-us/requests/new) or Email to [ossupport@orangehrm.com](mailto:ossupport@orangehrm.com)

## License 
GNU General Public License
