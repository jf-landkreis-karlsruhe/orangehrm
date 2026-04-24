# AGENTS.md

Fork of OrangeHRM. PHP 7.4/8.x monolith + Vue 3 SPA, dockerized dev workflow added by this fork. See `README.md` for user-facing setup; this file is for agent-specific gotchas.

## Repo shape

- PHP code lives in `src/plugins/orangehrm<Name>Plugin/` (~22 plugins). PSR-4 mapping is in `src/composer.json` (e.g. `orangehrmPimPlugin` → `OrangeHRM\Pim\…`; all entities collapse into `OrangeHRM\Entity\…`).
- Each plugin owns `Api/ Controller/ Dao/ Service/ entity/ test/ config/`. Plugin tests are wired into named suites in `phpunit.xml` (e.g. `--testsuite Pim`).
- Two independent JS apps with separate `package.json`/`yarn.lock` (Yarn 4 Berry via per-workspace `.yarn/releases`):
  - `src/client` → main Vue SPA, built to `web/dist`.
  - `installer/client` → installer UI, built to `installer/client/dist`.
- Two Composer roots: `src/` (app) and `devTools/core/` (CLI tools). No top-level package manifest.
- Cypress workspace `src/test/functional/` exists but local Cypress runs are out of scope (the CI workflow uses an external repo `orangehrm-os-dev-environment`).

## Two Docker workflows (added by this fork)

Always go through the Makefile. Never run `composer`, `phpunit`, `yarn`, or `php` on the host — they will not match the PHP 8.3 / Node 20 / extension setup.

1. **Tools containers** — `docker/dev/` (`Dockerfile.php-tools`, `Dockerfile.node-tools`, `docker-compose.yml`). Composer vendors and `node_modules` are baked **into the image at build time**; the working tree is bind-mounted to `/app` at runtime. The vendor and `node_modules` paths are anonymous volumes so the bind mount does not shadow them.
2. **Local live app** — `docker/local/` (`Dockerfile.base`, `Dockerfile.app`, `docker-compose.yml`). Base image has the runtime stack (PHP-Apache + Node + composer); the app image bakes the current source, runs `composer install` and `yarn build`, and serves via Apache. No mount, no live reload.

The production top-level `Dockerfile` and `docker_publish.yml` are unrelated to either of these and unchanged.

## First run

```
make build-dev-images   # build php-tools + node-tools images (bakes vendor + node_modules)
make test-php           # auto-installs the test DB on first run
```

After changing `composer.lock` or any `yarn.lock`, **rebuild and discard the cached vendor volumes**:

```
make build-dev-images && make dev-down
```

`make dev-down` removes the anonymous volumes that hold the previous vendor/node_modules — without it the new image's deps stay shadowed by the stale volumes.

## Test DB lifecycle

`make test-php` depends on `docker/dev/.test-db-installed` (a stamp file). The first invocation per dev session boots `mariadb-test` (tmpfs), runs `installer/cli_install.php`, then `i:create-test-db`. The stamp is wiped by `make dev-down` (because tmpfs is wiped anyway).

`make test-php` and `make test-js` accept extra arguments via `ARGS=`:

```
make test-php ARGS="--testsuite Pim"
make test-php ARGS="--filter testFoo src/plugins/orangehrmPimPlugin/test/Dao/SomeTest.php"
make test-js  ARGS="--coverage"
```

For raw PHPUnit access use `make shell-php` and call `php -d memory_limit=1G ./src/vendor/bin/phpunit ...` directly.

## Lint gotchas (CI will reject otherwise)

- `make lint-php` runs `php-cs-fix --php php8.3` (matches CI exactly).
- CI fails the lint job if running the fixer produces *any* diff (`git status --porcelain` check). Run `make fix-php` before pushing.
- `make lint-js` runs ESLint in all three JS workspaces; failing in any one fails the job. `vue-cli-service lint` is invoked with `--max-warnings=0`.
- Use `make fix-php` and `make fix-js` to write fixes back to the host (UID/GID is mapped at image build time via `.env`).

## API doc check

CI runs `php devTools/core/console.php generate-open-api-doc --throw` (no Make target). Run it inside `make shell-php` after touching API controllers or OpenAPI annotations.

## Doctrine / entity changes

Composer's `post-autoload-dump` regenerates proxies and clears cache (`bin/console orm:generate-proxies`, `bin/console cache:clear`). If you bypass composer (e.g. only edit entities), run those two manually inside `make shell-php`, otherwise stale proxies will mask the change.

## Installation state

Install state lives in `lib/confs/Conf.php` and `lib/confs/cryptokeys/`. The app considers itself uninstalled iff those are absent.

- The `make test-php` setup target `sed`-mutates `installer/cli_install_config.yaml` in place and restores it from `.bak` on exit. **If interrupted**, restore manually (`mv installer/cli_install_config.yaml.bak installer/cli_install_config.yaml`) before retrying.
- For the local live app, install state is held in named volumes (`confs`, `cache`, `logs`, `db`); `make local-reset` wipes them so the next `make local-up` re-runs `cli_install.php`.

## Local live app Make targets

- `make local-build` — builds `orangehrm-local-base:latest` (cached) then `orangehrm-local-app:latest` from the current code.
- `make local-up` / `make local-down` / `make local-logs` / `make local-reset`.
- The app image reuses the production `docker-entrypoint.sh`, so `ORANGEHRM_DB_*` and `ORANGEHRM_ADMIN_*` env vars work the same way as in production. The compose file pre-sets DB env vars; admin overrides come from the host environment.

## Production image / release

- Top-level `Dockerfile` is the 3-stage prod build (node-builder → composer-builder → `php:8.3-apache`). Not used by `make`.
- Pushing a `v*` tag triggers `.github/workflows/docker_publish.yml` → multi-arch (amd64/arm64) image to `ghcr.io/<repo>`.

## CI matrix

`.github/workflows/test.yml` runs PHPUnit + Jest twice (MySQL 5.7 and MariaDB 10.3) on PHP 8.3, plus a separate `composer_check` on PHP 8.3 and 8.4. Local `make test-php` only covers MariaDB 10.7.
