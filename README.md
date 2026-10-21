# Alpine PHP-FPM base image

PHP 8.2.35, 8.3.36, 8.4.27, and 8.5.12 compiled from their official source
tarballs on Alpine 3.24. These builds do not depend on Alpine PHP packages or
prebuilt `php:*` runtime images.

The build intentionally matches the official PHP Alpine FPM image:

- the same configure flags and built-in extensions;
- PHP CLI, PHP-FPM, PEAR, and PECL;
- OPcache and Sodium enabled by default;
- the official `docker-php-entrypoint` and `docker-php-ext-*` helpers;
- the standard PHP source archive retained for downstream extension builds;
- the standard FPM logging, environment, port, and graceful-stop behavior.

The PHP archive is authenticated with both its pinned SHA-256 checksum and the
PHP release-manager GPG signatures. The official Docker PHP helper scripts are
pinned to an upstream commit and individually checksummed.

## Build and verify

Build and test every supported release:

```sh
make test-all
```

Or build one release:

```sh
make test-8.2
make test-8.3
make test-8.4
make test-8.5
```

Each build produces an exact-patch tag and a minor-series alias:

| Release | Tags |
| --- | --- |
| PHP 8.2.35 | `alpine-php-fpm:8.2.35`, `alpine-php-fpm:8.2` |
| PHP 8.3.36 | `alpine-php-fpm:8.3.36`, `alpine-php-fpm:8.3` |
| PHP 8.4.27 | `alpine-php-fpm:8.4.27`, `alpine-php-fpm:8.4` |
| PHP 8.5.12 | `alpine-php-fpm:8.5.12`, `alpine-php-fpm:8.5` |

To use another repository name:

```sh
make test-all IMAGE_REPOSITORY=registry.example.com/alpine-php-fpm
```

## Publish to GHCR

The example GitHub Actions workflow can be started from the repository's
**Actions** tab with **Run workflow**. Select one of the supported exact PHP
versions and an x86 runner size from the dropdowns. The workflow uses a
version-specific BuildKit cache and publishes a `linux/amd64` image to:

```text
ghcr.io/OWNER/REPOSITORY:8.2.35
ghcr.io/OWNER/REPOSITORY:8.2
```

The tags reflect the selected release. Publishing to GHCR does not create a
GitHub Release or Git tag, so the workflow only requires package-write access
and is not affected by repository tag-creation restrictions.

The runner dropdown defaults to `ubuntu-latest`, which avoids waiting for an
unavailable larger-runner pool. Select `ubuntu-latest-16-cores` only after that
larger runner is available to the repository. Larger runners require an
organization on GitHub Team or GitHub Enterprise Cloud with billing enabled.

## FrankenPHP image

FrankenPHP is built and released separately from the PHP-FPM images because it
requires a thread-safe (ZTS) PHP build. The dedicated **Build and release
FrankenPHP image** workflow builds FrankenPHP 1.13.1 against PHP 8.3.36 ZTS on
Alpine 3.24 and publishes these AMD64 tags:

```text
ghcr.io/OWNER/frankenphp:1.13.1-php8.3.36-alpine3.24
ghcr.io/OWNER/frankenphp:1.13.1-php8.3.36-alpine
ghcr.io/OWNER/frankenphp:1.13.1-php8.3-alpine
```

Because Docker Hub's PHP 8.3.36 ZTS Alpine tag currently has an empty manifest,
the workflow first compiles an exact PHP 8.3.36 ZTS base from the authenticated
PHP source archive. It then builds the pinned FrankenPHP source commit using
that base and a pinned Go base-image digest. To build and verify the same image
locally:

```sh
make test-frankenphp
```

The workflow publishes the intermediate ZTS base as
`ghcr.io/OWNER/frankenphp:php-base-8.3.36-alpine3.24`; it exists only as the
input to the final FrankenPHP build.

Use the PHP-FPM images behind a FastCGI-capable web server on a private
container network, and do not publish FPM port 9000 directly to the internet.
FrankenPHP is the HTTP server itself and exposes ports 80, 443, 443/udp, and
2019 using its upstream defaults.
