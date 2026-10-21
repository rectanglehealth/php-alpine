ARG ALPINE_VERSION=3.24
FROM alpine:${ALPINE_VERSION}

ARG ALPINE_VERSION
ARG PHP_VERSION=8.5.12
ARG PHP_SERIES=8.5
ARG PHP_SHA256=08bc2eba2a588654ade1357174aa646b761556c862dda0678345ee29ed481209
ARG PHP_GPG_KEYS="1198C0117593497A5EC5C199286AF1F9897469DC 49D9AF6BC72A80D6691719C8AA23F5BE9C7097D4 D95C03BC702BE9515344AE3374E44BC9067701A5"

# Kept in the runtime image so downstream images can use docker-php-ext-*.
ENV PHPIZE_DEPS="autoconf dpkg-dev dpkg file g++ gcc libc-dev make pkgconf re2c" \
    PHP_INI_DIR=/usr/local/etc/php \
    PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64" \
    PHP_LDFLAGS="-Wl,-O1 -pie" \
    PHP_VERSION=${PHP_VERSION} \
    PHP_URL=https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz \
    PHP_ASC_URL=https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz.asc \
    PHP_SHA256=${PHP_SHA256}
ENV PHP_CPPFLAGS="$PHP_CFLAGS"

RUN apk add --no-cache ca-certificates curl openssl tar xz; \
    adduser -u 82 -D -S -G www-data www-data; \
    mkdir -p "$PHP_INI_DIR/conf.d" /var/www/html; \
    chown www-data:www-data /var/www/html; \
    chmod 1777 /var/www/html

# Exact helper scripts shared by the official PHP Alpine FPM images.
ARG DOCKER_PHP_SCRIPTS_COMMIT=e3eaff845f7a9f7259c31da54dce0320b47a3bbd
RUN set -eux; \
    scriptsUrl="https://raw.githubusercontent.com/docker-library/php/${DOCKER_PHP_SCRIPTS_COMMIT}/${PHP_SERIES}/alpine3.24/fpm"; \
    curl -fsSL "$scriptsUrl/docker-php-entrypoint" -o /usr/local/bin/docker-php-entrypoint; \
    curl -fsSL "$scriptsUrl/docker-php-ext-configure" -o /usr/local/bin/docker-php-ext-configure; \
    curl -fsSL "$scriptsUrl/docker-php-ext-enable" -o /usr/local/bin/docker-php-ext-enable; \
    curl -fsSL "$scriptsUrl/docker-php-ext-install" -o /usr/local/bin/docker-php-ext-install; \
    curl -fsSL "$scriptsUrl/docker-php-source" -o /usr/local/bin/docker-php-source; \
    echo 'eeda8bf8df95a81bcfd9019259fd6e26f4b94cb26ad2d83c2051d73b20df5627  /usr/local/bin/docker-php-entrypoint' | sha256sum -c -; \
    echo '2464740142f245e2ff4539b9773fc37b7637407ba569da9d1961f91a13623edd  /usr/local/bin/docker-php-ext-configure' | sha256sum -c -; \
    echo '861e94e4199f770f433cf5b3dca26fecb14401170a1140c41b79f9c9713cdc7f  /usr/local/bin/docker-php-ext-enable' | sha256sum -c -; \
    echo '3486e85b6a1626f63a6b22254b940b6158515cdcb7fb29ec62e805e46330c51d  /usr/local/bin/docker-php-ext-install' | sha256sum -c -; \
    echo '35db863f9c436fd8d04c25262a9fc5c78daa0d79efd1a606f23bbc4e2980c736  /usr/local/bin/docker-php-source' | sha256sum -c -; \
    chmod +x /usr/local/bin/docker-php-*

ENV GPG_KEYS=${PHP_GPG_KEYS}

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
    pcreJitFlag=; \
    case "$PHP_VERSION:$gnuArch" in \
        8.2.*:riscv64-linux-musl) pcreJitFlag='--without-pcre-jit' ;; \
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
        --disable-phpdbg \
        --with-pear \
        $pcreJitFlag \
        --disable-cgi \
        --enable-fpm \
        --with-fpm-user=www-data \
        --with-fpm-group=www-data; \
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

# OPcache is mandatory and built in as of PHP 8.5. Earlier releases still
# build it as a shared module, matching their official Docker image recipes.
RUN set -eux; \
    if [ "$PHP_SERIES" = '8.5' ]; then \
        docker-php-ext-enable sodium; \
    else \
        docker-php-ext-enable opcache sodium; \
    fi

ENTRYPOINT ["docker-php-entrypoint"]
WORKDIR /var/www/html

RUN set -eux; \
    cd "${PHP_INI_DIR%/php}"; \
    cp -v php-fpm.conf.default php-fpm.conf; \
    cp -v php-fpm.d/www.conf.default php-fpm.d/www.conf; \
    grep -E '^listen = 127.0.0.1:9000' php-fpm.d/www.conf; \
    sed -ri 's/^(listen = 127.0.0.1:9000)/;\1/' php-fpm.d/www.conf; \
    { \
        echo '[global]'; \
        echo 'error_log = /proc/self/fd/2'; \
        echo 'log_limit = 8192'; \
        echo; \
        echo '[www]'; \
        echo 'access.log = /proc/self/fd/2'; \
        echo 'clear_env = no'; \
        echo 'catch_workers_output = yes'; \
        echo 'decorate_workers_output = no'; \
        echo 'listen = 9000'; \
    } | tee php-fpm.d/docker.conf; \
    { echo '[global]'; echo 'daemonize = no'; echo; echo '[www]'; } | tee php-fpm.d/zz-docker.conf; \
    echo 'fastcgi.logging = Off' > "$PHP_INI_DIR/conf.d/docker-fpm.ini"

LABEL org.opencontainers.image.title="Alpine PHP-FPM base" \
      org.opencontainers.image.description="PHP FPM compiled from source on Alpine" \
      org.opencontainers.image.version="${PHP_VERSION}" \
      org.opencontainers.image.base.name="alpine:${ALPINE_VERSION}"

STOPSIGNAL SIGQUIT
EXPOSE 9000
CMD ["php-fpm"]
