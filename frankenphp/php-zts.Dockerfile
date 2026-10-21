ARG ALPINE_VERSION=3.24
FROM alpine:${ALPINE_VERSION}

ENV PHPIZE_DEPS="autoconf dpkg-dev dpkg file g++ gcc libc-dev make pkgconf re2c" \
    PHP_INI_DIR=/usr/local/etc/php \
    PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64" \
    PHP_LDFLAGS="-Wl,-O1 -pie" \
    PHP_VERSION=8.3.36 \
    PHP_URL=https://www.php.net/distributions/php-8.3.36.tar.xz \
    PHP_ASC_URL=https://www.php.net/distributions/php-8.3.36.tar.xz.asc \
    PHP_SHA256=dd54693aa334c5c4d72e9aee96b082c2473750a18a6c1d105789c93a3b1692fd \
    GPG_KEYS="1198C0117593497A5EC5C199286AF1F9897469DC C28D937575603EB4ABB725861C0779DC5C0A9DE4 AFD8691FDAEDF03BDF6E460563F15A9B715376CA"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"

RUN apk add --no-cache ca-certificates curl openssl tar xz; \
    adduser -u 82 -D -S -G www-data www-data; \
    mkdir -p "$PHP_INI_DIR/conf.d" /var/www/html; \
    chown www-data:www-data /var/www/html; \
    chmod 1777 /var/www/html

ARG DOCKER_PHP_SCRIPTS_COMMIT=e3eaff845f7a9f7259c31da54dce0320b47a3bbd
RUN set -eux; \
    scriptsUrl="https://raw.githubusercontent.com/docker-library/php/${DOCKER_PHP_SCRIPTS_COMMIT}/8.3/alpine3.24/zts"; \
    curl -fsSL "$scriptsUrl/docker-php-entrypoint" -o /usr/local/bin/docker-php-entrypoint; \
    curl -fsSL "$scriptsUrl/docker-php-ext-configure" -o /usr/local/bin/docker-php-ext-configure; \
    curl -fsSL "$scriptsUrl/docker-php-ext-enable" -o /usr/local/bin/docker-php-ext-enable; \
    curl -fsSL "$scriptsUrl/docker-php-ext-install" -o /usr/local/bin/docker-php-ext-install; \
    curl -fsSL "$scriptsUrl/docker-php-source" -o /usr/local/bin/docker-php-source; \
    echo '153f186d1abf12b85c4f524b9c6b1b0009364fbabc0dad4db9aaba8fab016a42  /usr/local/bin/docker-php-entrypoint' | sha256sum -c -; \
    echo '2464740142f245e2ff4539b9773fc37b7637407ba569da9d1961f91a13623edd  /usr/local/bin/docker-php-ext-configure' | sha256sum -c -; \
    echo '861e94e4199f770f433cf5b3dca26fecb14401170a1140c41b79f9c9713cdc7f  /usr/local/bin/docker-php-ext-enable' | sha256sum -c -; \
    echo '3486e85b6a1626f63a6b22254b940b6158515cdcb7fb29ec62e805e46330c51d  /usr/local/bin/docker-php-ext-install' | sha256sum -c -; \
    echo '35db863f9c436fd8d04c25262a9fc5c78daa0d79efd1a606f23bbc4e2980c736  /usr/local/bin/docker-php-source' | sha256sum -c -; \
    chmod +x /usr/local/bin/docker-php-*

RUN set -eux; \
    apk add --no-cache --virtual .fetch-deps gnupg; \
    mkdir -p /usr/src; \
    cd /usr/src; \
    curl -fsSL -o php.tar.xz "$PHP_URL"; \
    echo "$PHP_SHA256 *php.tar.xz" | sha256sum -c -; \
    curl -fsSL -o php.tar.xz.asc "$PHP_ASC_URL"; \
    export GNUPGHOME="$(mktemp -d)"; \
    for key in $GPG_KEYS; do gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; done; \
    gpg --batch --verify php.tar.xz.asc php.tar.xz; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME"; \
    apk del --no-network .fetch-deps

RUN set -eux; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        argon2-dev coreutils curl-dev gnu-libiconv-dev libsodium-dev \
        libxml2-dev linux-headers oniguruma-dev openssl-dev readline-dev sqlite-dev; \
    rm -vf /usr/include/iconv.h; \
    export CFLAGS="$PHP_CFLAGS" CPPFLAGS="$PHP_CPPFLAGS" LDFLAGS="$PHP_LDFLAGS" \
        PHP_BUILD_PROVIDER='https://github.com/docker-library/php' PHP_UNAME='Linux - Docker'; \
    docker-php-source extract; \
    cd /usr/src/php; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    case "$gnuArch" in \
        'i686-linux-'*) export CFLAGS="$CFLAGS -msse2 -mfpmath=sse" CPPFLAGS="$CPPFLAGS -msse2 -mfpmath=sse" ;; \
    esac; \
    ./configure \
        --build="$gnuArch" \
        --sysconfdir="${PHP_INI_DIR%/php}" \
        --with-config-file-path="$PHP_INI_DIR" \
        --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
        --enable-option-checking=fatal \
        --with-mhash \
        --with-pic \
        --enable-mbstring \
        --enable-mysqlnd \
        --with-password-argon2 \
        --with-sodium=shared \
        --with-pdo-sqlite=/usr \
        --with-sqlite3=/usr \
        --with-curl \
        --with-iconv=/usr \
        --with-openssl \
        --with-readline \
        --with-zlib \
        --enable-phpdbg \
        --enable-phpdbg-readline \
        --with-pear \
        --enable-embed \
        --enable-zts \
        --disable-zend-signals; \
    make -j "$(nproc)"; \
    find -type f -name '*.a' -delete; \
    make install; \
    find /usr/local -type f -perm '/0111' -exec sh -euxc 'strip --strip-all "$@" || :' -- '{}' +; \
    make clean; \
    cp -v php.ini-* "$PHP_INI_DIR/"; \
    cd /; \
    docker-php-source delete; \
    runDeps="$(scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
        | tr ',' '\n' | sort -u \
        | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }')"; \
    apk add --no-cache $runDeps; \
    apk del --no-network .build-deps; \
    pecl update-channels; \
    rm -rf /tmp/pear ~/.pearrc; \
    php --version

RUN docker-php-ext-enable opcache sodium

LABEL org.opencontainers.image.title="PHP 8.3.36 ZTS base for FrankenPHP" \
      org.opencontainers.image.version="8.3.36"

ENTRYPOINT ["docker-php-entrypoint"]
CMD ["php", "-a"]
