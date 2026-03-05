<img width="40%" alt='OrangeHRM' src='https://raw.githubusercontent.com/wiki/orangehrm/orangehrm/logos/logo.svg#gh-light-mode-only'/><img width="40%" alt='OrangeHRM' src='https://raw.githubusercontent.com/wiki/orangehrm/orangehrm/logos/logo_dark_mode.svg#gh-dark-mode-only'/>

[![Docker Pulls](https://img.shields.io/docker/pulls/orangehrm/orangehrm.svg)](https://hub.docker.com/r/orangehrm/orangehrm) [![SourceForge Downloads](https://img.shields.io/sourceforge/dm/orangehrm.svg)](https://sourceforge.net/projects/orangehrm/) [![SourceForge Downloads](https://img.shields.io/sourceforge/dt/orangehrm.svg)](https://sourceforge.net/projects/orangehrm/)

# OrangeHRM Starter Application

OrangeHRM is a comprehensive Human Resource Management (HRM) System that captures all the essential functionalities required for any enterprise. Copyright (C) 2006 OrangeHRM Inc., http://www.orangehrm.com/

OrangeHRM is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.

OrangeHRM is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

## Getting started

### Docker Installation (Recommended)

The easiest way to run OrangeHRM is using Docker. Images are automatically built and published to GitHub Container Registry (GHCR) for each release.

**Pull and run the latest version:**
```bash
docker pull ghcr.io/jf-landkreis-karlsruhe/orangehrm:latest
docker run -d -p 80:80 ghcr.io/jf-landkreis-karlsruhe/orangehrm:latest
```

**Pull a specific version:**
```bash
docker pull ghcr.io/jf-landkreis-karlsruhe/orangehrm:5.8
docker run -d -p 80:80 ghcr.io/jf-landkreis-karlsruhe/orangehrm:5.8
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
### Quick Start

```bash
# 1. Clone the repository (if not already done)
git clone <repository-url>
cd orangehrm

# 2. Install all dependencies (PHP + Node)
make install

# 3. Start the database
make db-up

# 4. Install OrangeHRM
make db-install

# 5. Run tests to verify everything works
make test
```

That's it! You now have a fully functional development environment.

### Available Commands

The Makefile provides convenient shortcuts for common tasks:

#### Setup & Installation
| Command | Description |
|---------|-------------|
| `make install` | Install all dependencies (PHP + Node) |
| `make install-php` | Install PHP dependencies with Composer |
| `make install-node` | Install Node dependencies with Yarn |

#### Testing
| Command | Description |
|---------|-------------|
| `make test` | Run all tests (PHPUnit + Jest) |
| `make test-php` | Run PHPUnit tests |
| `make test-php-coverage` | Run PHPUnit with code coverage |
| `make test-node` | Run Jest tests (Vue unit tests) |
| `make test-node-coverage` | Run Jest with code coverage |

#### Linting
| Command | Description |
|---------|-------------|
| `make lint` | Run all linters (PHP + Node) |
| `make lint-php` | Check PHP coding standards |
| `make lint-php-fix` | Fix PHP coding standards |
| `make lint-node` | Check Node/Vue code with ESLint |

#### Building
| Command | Description |
|---------|-------------|
| `make build` | Full OrangeHRM build (like CI) |
| `make build-client` | Build Vue client only |
| `make build-installer` | Build installer client only |

#### Database
| Command | Description |
|---------|-------------|
| `make db-up` | Start MariaDB container |
| `make db-down` | Stop MariaDB container |
| `make db-install` | Install OrangeHRM via CLI |
| `make db-reset` | Reset database |

#### Development
| Command | Description |
|---------|-------------|
| `make shell-php` | Open interactive PHP shell |
| `make shell-node` | Open interactive Node shell |
| `make clean` | Clean generated files and caches |
| `make help` | Show all available commands |

### Development Workflows

#### Daily Development

```bash
# Make code changes in your editor...

# Run relevant tests
make test-php        # After PHP changes
make test-node       # After Vue changes

# Check code style
make lint

# Build to verify everything works
make build
```

#### Persistent MySQL Data

By default, MariaDB uses tmpfs (RAM) for fast tests without persistence. To enable persistence:

```yaml
# Edit docker-compose.dev.yml
# Replace tmpfs with a volume:
volumes:
  - mysql-data:/var/lib/mysql
```

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
