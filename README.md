# Alpine PHP-FPM base image

PHP 8.2.35, 8.3.36, and 8.4.27 compiled from their official source tarballs on
Alpine 3.24. These builds do not depend on Alpine PHP packages or prebuilt
`php:*` runtime images.

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
```

Each build produces an exact-patch tag and a minor-series alias:

| Release | Tags |
| --- | --- |
| PHP 8.2.35 | `alpine-php-fpm:8.2.35`, `alpine-php-fpm:8.2` |
| PHP 8.3.36 | `alpine-php-fpm:8.3.36`, `alpine-php-fpm:8.3` |
| PHP 8.4.27 | `alpine-php-fpm:8.4.27`, `alpine-php-fpm:8.4` |

To use another repository name:

```sh
make test-all IMAGE_REPOSITORY=registry.example.com/alpine-php-fpm
```

## Publish to GHCR

The example GitHub Actions workflow can be started from the repository's
**Actions** tab with **Run workflow**. Select one of the supported exact PHP
versions from the dropdown. The workflow builds on a 16-core x86 larger runner,
uses a version-specific BuildKit cache, and publishes a `linux/amd64` image to:

```text
ghcr.io/OWNER/REPOSITORY:8.2.35
ghcr.io/OWNER/REPOSITORY:8.2
```

The tags reflect the selected release. Publishing to GHCR does not create a
GitHub Release or Git tag, so the workflow only requires package-write access
and is not affected by repository tag-creation restrictions.

The workflow uses GitHub's `ubuntu-latest-16-cores` larger-runner label. Larger
runners require an organization on GitHub Team or GitHub Enterprise Cloud with
billing enabled. If your organization instead provisions a custom-named larger
runner, update the workflow's `runs-on` value to match that label.

Use this image behind a FastCGI-capable web server on a private container
network. Do not publish FPM port 9000 directly to the internet.
