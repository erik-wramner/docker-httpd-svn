FROM debian:stretch-slim
LABEL name="httpd-svn" \
      description="Apache httpd with Subversion" \
      maintainer="erik.wramner@codemint.com" \
      version="2.4.39-1.11.1-01"

ENV HTTPD_VERSION 2.4.39
ENV HTTPD_SHA256 b4ca9d05773aa59b54d66cd8f4744b945289f084d3be17d7981d1783a5decfa2
ENV SVN_VERSION 1.11.1
ENV SVN_SHA512 2d082f715bf592ffc6a19311a9320dbae2ff0ee126b0472ce1c3f10e9aee670f43d894889430e6d093620f7b69c611e9a26773bc7a2f8b599ec37540ecd84a8d
ENV HTTPD_PREFIX /usr/local/apache2
ENV PATH $HTTPD_PREFIX/bin:$PATH

RUN groupadd -r httpd && useradd -r -g httpd httpd \
    && mkdir -p /svn/repos \
    && mkdir -p /svn/config \
    && mkdir -p /svn/backup \
    && chown -R httpd:httpd /svn/repos
COPY conf/* /svn/config/
VOLUME ["/svn"]

WORKDIR $HTTPD_PREFIX

# https://httpd.apache.org/security/vulnerabilities_24.html
ENV HTTPD_PATCHES=""

ENV APACHE_DIST_URLS \
# https://issues.apache.org/jira/browse/INFRA-8753?focusedCommentId=14735394#comment-14735394
    https://www.apache.org/dyn/closer.cgi?action=download&filename= \
# if the version is outdated (or we're grabbing the .asc file), we might have to pull from the dist/archive :/
    https://www-us.apache.org/dist/ \
    https://www.apache.org/dist/ \
    https://archive.apache.org/dist/

# see https://httpd.apache.org/docs/2.4/install.html#requirements
# plus libsqlite3-dev for svn
RUN set -eux; \
    runtimeDeps=" \
        ca-certificates \
        bzip2 \
        libsqlite3-0 \
        ssl-cert \
        zlib1g \
        libapr1 \
        libaprutil1 \
        libaprutil1-ldap \
        liblua5.2 \
        libxml2 \
    "; \
    buildDeps=" \
        dpkg-dev \
        dirmngr \
        gcc \
        gnupg \
        libapr1-dev \
        libaprutil1-dev \
        liblua5.2-dev \
        libnghttp2-dev \
        libpcre3-dev \
        libssl-dev \
        libsqlite3-dev \
        libxml2-dev \
        zlib1g-dev \
        make \
        wget \
    "; \
    usefulTools=" \
        net-tools \
    "; \
    apt-get update; \
    apt-get install -y --no-install-recommends -V $buildDeps $runtimeDeps $usefulTools; \
    rm -r /var/lib/apt/lists/*; \
    \
    ddist() { \
        local f="$1"; shift; \
        local distFile="$1"; shift; \
        local success=; \
        local distUrl=; \
        for distUrl in $APACHE_DIST_URLS; do \
            if wget -O "$f" "$distUrl$distFile" && [ -s "$f" ]; then \
                success=1; \
                break; \
            fi; \
        done; \
        [ -n "$success" ]; \
    }; \
    \
    ddist 'httpd.tar.bz2' "httpd/httpd-$HTTPD_VERSION.tar.bz2"; \
    echo "$HTTPD_SHA256 *httpd.tar.bz2" | sha256sum -c -; \
    ddist 'subversion.tar.bz2' "subversion/subversion-$SVN_VERSION.tar.bz2"; \
    echo "$SVN_SHA512 *subversion.tar.bz2" | sha512sum -c -; \
    \
# see https://httpd.apache.org/download.cgi#verify
    ddist 'httpd.tar.bz2.asc' "httpd/httpd-$HTTPD_VERSION.tar.bz2.asc"; \
    ddist 'subversion.tar.bz2.asc' "subversion/subversion-$SVN_VERSION.tar.bz2.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    echo "disable-ipv6" >> $GNUPGHOME/dirmngr.conf; \
    for key in \
# gpg: key 791485A8: public key "Jim Jagielski (Release Signing Key) <jim@apache.org>" imported
        A93D62ECC3C8EA12DB220EC934EA76E6791485A8 \
# gpg: key 995E35221AD84DFF: public key "Daniel Ruggeri (http://home.apache.org/~druggeri/) <druggeri@apache.org>" imported
        B9E8213AEFB861AF35A41F2C995E35221AD84DFF \
    ; do \
        gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
    done; \
    gpg --batch --verify httpd.tar.bz2.asc httpd.tar.bz2; \
    wget -O subversion.asc https://people.apache.org/keys/group/subversion.asc; \
    gpg --import subversion.asc; \
    gpg --batch --verify subversion.tar.bz2.asc subversion.tar.bz2; \
    rm -rf "$GNUPGHOME" httpd.tar.bz2.asc subversion.asc subversion.tar.bz2.asc; \
    \
    mkdir -p src; \
    tar -xf httpd.tar.bz2 -C src --strip-components=1; \
    rm httpd.tar.bz2; \
    cd src; \
    \
    patches() { \
        while [ "$#" -gt 0 ]; do \
            local patchFile="$1"; shift; \
            local patchSha256="$1"; shift; \
            ddist "$patchFile" "httpd/patches/apply_to_$HTTPD_VERSION/$patchFile"; \
            echo "$patchSha256 *$patchFile" | sha256sum -c -; \
            patch -p0 < "$patchFile"; \
            rm -f "$patchFile"; \
        done; \
    }; \
    patches $HTTPD_PATCHES; \
    \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    ./configure \
        --build="$gnuArch" \
        --prefix="$HTTPD_PREFIX" \
        --enable-mods-shared=reallyall \
        --enable-mpms-shared=all \
    ; \
    make -j "$(nproc)"; \
    make install; \
    cd ..; \
    \
    mkdir -p src-svn; \
    tar -xf subversion.tar.bz2 -C src-svn --strip-components=1; \
    rm subversion.tar.bz2; \
    cd src-svn; \
    ./configure --with-lz4=internal --with-utf8proc=internal \
      --enable-mod-activation --with-apxs \
      --with-apache-libexecdir=/usr/local/apache2/modules; \
    make; \
    make install; \
    \
    cd ..; \
    rm -r src src-svn man manual; \
    apt-get purge -y --auto-remove $buildDeps; \
    make-ssl-cert generate-default-snakeoil; \
    mkdir -p /etc/ssl/localcerts; \
    ln -s /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/localcerts/server.key; \
    ln -s /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/ssl/localcerts/server.crt; \
    rm -f $HTTPD_PREFIX/conf/httpd.conf; \
    ln -s /svn/config/httpd.conf $HTTPD_PREFIX/conf/httpd.conf

COPY scripts/*.sh /usr/local/bin/

EXPOSE 80 443
CMD ["httpd-foreground.sh"]
