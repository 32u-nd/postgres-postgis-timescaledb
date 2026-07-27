# =================================================================
# PostgreSQL 18.4 + PostGIS 3.6.4 + TimescaleDB 2.28.3 on Alpine 3.23
# =================================================================

# final image size ~ 550 MB

FROM postgres:18.4-alpine3.23

# All versions and checksums in one place — overridable via --build-arg
ARG ALPINE_VERSION=v3.23
ARG POSTGIS_VERSION=3.6.4
ARG POSTGIS_SHA256=4f80e1a4d227f088ae818f79180debd5894c075615823e0f556f73479cf1f200
ARG TIMESCALEDB_VERSION=2.28.3
ARG TIMESCALEDB_SHA256=c9f95c8865f71244cdd333076284377e83dad62f85679fbf1c94ba48a7d67334

# PG18: PGDATA path is now version-specific (/var/lib/postgresql/18/docker)
# Volumes should be mounted to /var/lib/postgresql (without /data)
ENV PGDATA=/var/lib/postgresql/18/docker

# OCI-compliant image labels
LABEL org.opencontainers.image.title="PostgreSQL + PostGIS + TimescaleDB" \
      org.opencontainers.image.description="PostgreSQL 18.4 with PostGIS ${POSTGIS_VERSION} and TimescaleDB ${TIMESCALEDB_VERSION} on Alpine ${ALPINE_VERSION}" \
      org.opencontainers.image.version="18.4" \
      org.opencontainers.image.base.name="postgres:18.4-alpine${ALPINE_VERSION}" \
      org.opencontainers.image.authors="https://github.com/32u-nd"

# ---------------------------------------------------------------------------
# Build PostGIS and TimescaleDB in a single RUN layer:
# Build dependencies are installed once and removed at the end, so they do
# not persist in any intermediate layer of the final image.
# ---------------------------------------------------------------------------
RUN set -eux \
    \
    # --- Build dependencies (shared by both extensions) ---
    && apk add --no-cache --virtual .build-deps \
        --repository "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION}/main" \
        --repository "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION}/community" \
        autoconf \
        automake \
        build-base \
        ca-certificates \
        clang21 \
        clang21-dev \
        cmake \
        coreutils \
        dpkg \
        dpkg-dev \
        file \
        g++ \
        gcc \
        gdal-dev \
        geos-dev \
        git \
        json-c-dev \
        krb5-dev \
        libc-dev \
        libtool \
        libxml2-dev \
        llvm21 \
        llvm21-dev \
        make \
        openssl \
        openssl-dev \
        perl \
        postgresql-dev \
        proj-dev \
        protobuf-c-dev \
        tar \
        util-linux-dev \
    \
    # --- Runtime dependencies (persist in the final image) ---
    && apk add --no-cache --virtual .postgis-rundeps \
        --repository "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION}/main" \
        --repository "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION}/community" \
        gdal \
        geos \
        json-c \
        proj \
        protobuf-c \
    \
    # --- Prepare LLVM/Clang for PostgreSQL extension builds ---
    # Makefile.global contains the hardcoded compiler from the PG build (clang-21).
    # The clang21 package provides /usr/bin/clang-21, but llvm-lto only exists
    # under /usr/lib/llvm21/bin/ — create symlinks into PATH.
    && ln -sf /usr/lib/llvm21/bin/llvm-lto  /usr/local/bin/llvm-lto \
    && ln -sf /usr/lib/llvm21/bin/llvm-lto2 /usr/local/bin/llvm-lto2 \
    && MAKEFILE_GLOBAL=$(dirname "$(dirname "$(pg_config --pgxs)")")/Makefile.global \
    && sed -i "s|^CLANG *=.*|CLANG = /usr/bin/clang-21|" "${MAKEFILE_GLOBAL}" \
    \
    # =========================================================================
    # PostGIS
    # =========================================================================
    && wget -q -O postgis.tar.gz \
        "https://github.com/postgis/postgis/archive/refs/tags/${POSTGIS_VERSION}.tar.gz" \
    && echo "${POSTGIS_SHA256}  postgis.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/src/postgis \
    && tar --extract --file postgis.tar.gz \
           --directory /usr/src/postgis \
           --strip-components 1 \
    && rm postgis.tar.gz \
    && cd /usr/src/postgis \
    && ./autogen.sh \
    && ./configure --without-sfcgal \
    && make -j"$(nproc)" \
    && make install \
    && cd / \
    && rm -rf /usr/src/postgis \
    \
    # =========================================================================
    # TimescaleDB
    # =========================================================================
    && wget -q -O timescaledb.tar.gz \
        "https://github.com/timescale/timescaledb/archive/${TIMESCALEDB_VERSION}.tar.gz" \
    && echo "${TIMESCALEDB_SHA256}  timescaledb.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/src/timescaledb \
    && tar --extract --file timescaledb.tar.gz \
           --directory /usr/src/timescaledb \
           --strip-components 1 \
    && rm timescaledb.tar.gz \
    && cd /usr/src/timescaledb \
    && ./bootstrap \
        -DPROJECT_INSTALL_METHOD="docker" \
        -DREGRESS_CHECKS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
    && cd ./build \
    && make -j"$(nproc)" \
    && make install \
    && cd / \
    && rm -rf /usr/src/timescaledb \
    \
    # --- Remove build dependencies ---
    && apk del .build-deps \
    \
    # --- Register TimescaleDB in shared_preload_libraries ---
    && sed -r -i \
        "s/[#]*\s*(shared_preload_libraries)\s*=\s*'(.*)'/\1 = 'timescaledb,\2'/;s/,'/'/" \
        /usr/local/share/postgresql/postgresql.conf.sample

COPY ./init-db.sh /docker-entrypoint-initdb.d/init-db.sh