FROM debian:jessie-backports
LABEL name="httpd-svn" \
      description="Apache httpd with Subversion" \
      maintainer="erik.wramner@codemint.com" \
      version="2.4.34-1.10.2-01"

ENV HTTPD_VERSION 2.4.34
ENV HTTPD_SHA256 fa53c95631febb08a9de41fd2864cfff815cf62d9306723ab0d4b8d7aa1638f0
ENV SVN_VERSION 1.10.2
ENV SVN_SHA512  ccbe860ec93a198745e40620cb7e005a85797e344a99ddbc0e24c32ad846976eae35cf5b3d62ba5751b998f0d40bbebbba72f484d92c92693bbb2112c989b129
ENV NGHTTP2_VERSION 1.18.1-1
ENV OPENSSL_VERSION 1.0.2l-1~bpo8+1
ENV HTTPD_PREFIX /usr/local/apache2
ENV PATH $HTTPD_PREFIX/bin:$PATH

RUN groupadd -r httpd && useradd -r -g httpd httpd \
    && mkdir -p /svn/repos \
    && mkdir -p /svn/config \
    && mkdir -p /svn/backup \
    && chown -R httpd:httpd /svn/repos
VOLUME ["/svn"]

WORKDIR $HTTPD_PREFIX

RUN { \
        echo 'deb http://deb.debian.org/debian stretch main'; \
    } > /etc/apt/sources.list.d/stretch.list \
    && { \
# add a negative "Pin-Priority" so that we never ever get packages from stretch unless we explicitly request them
        echo 'Package: *'; \
        echo 'Pin: release n=stretch'; \
        echo 'Pin-Priority: -10'; \
        echo; \
# except nghttp2, which is the reason we're here
        echo 'Package: libnghttp2*'; \
        echo "Pin: version $NGHTTP2_VERSION"; \
        echo 'Pin-Priority: 990'; \
        echo; \
    } > /etc/apt/preferences.d/unstable-nghttp2

# install httpd runtime dependencies
# https://httpd.apache.org/docs/2.4/install.html#requirements
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libapr1 \
        libaprutil1 \
        libaprutil1-ldap \
        libapr1-dev \
        libaprutil1-dev \
        liblua5.2-0 \
        libnghttp2-14=$NGHTTP2_VERSION \
        libpcre++0 \
        libssl1.0.0=$OPENSSL_VERSION \
        libxml2 \
    && rm -r /var/lib/apt/lists/*

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
    \
    # mod_http2 mod_lua mod_proxy_html mod_xml2enc
    # https://anonscm.debian.org/cgit/pkg-apache/apache2.git/tree/debian/control?id=adb6f181257af28ee67af15fc49d2699a0080d4c
    \
    runtimeDeps=" \
        ca-certificates \
        bzip2 \
        libsqlite3-0 \
        ssl-cert \
        zlib1g \
    "; \
    buildDeps=" \
        dpkg-dev \
        gcc \
        liblua5.2-dev \
        libnghttp2-dev=$NGHTTP2_VERSION \
        libpcre++-dev \
        libssl-dev=$OPENSSL_VERSION \
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
    for key in \
# gpg: key 791485A8: public key "Jim Jagielski (Release Signing Key) <jim@apache.org>" imported
        A93D62ECC3C8EA12DB220EC934EA76E6791485A8 \
# gpg: key 995E35221AD84DFF: public key "Daniel Ruggeri (http://home.apache.org/~druggeri/) <druggeri@apache.org>" imported
        B9E8213AEFB861AF35A41F2C995E35221AD84DFF \
    ; do \
        gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
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
    ln -s /etc/ssl/private/ssl-cert-snakeoil.key /usr/local/apache2/conf/server.key; \
    ln -s /etc/ssl/certs/ssl-cert-snakeoil.pem /usr/local/apache2/conf/server.crt

COPY scripts/*.sh /usr/local/bin/
COPY httpd-conf/httpd.conf $HTTPD_PREFIX/conf/
COPY svn-conf/* /svn/config/

EXPOSE 80 443
CMD ["httpd-foreground.sh"]
