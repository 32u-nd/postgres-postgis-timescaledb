# PostgreSQL + PostGIS + TimescaleDB on Alpine

A minimal Docker image combining **PostgreSQL 18**, **PostGIS 3.6.1**, and **TimescaleDB 2.25.2**, built on Alpine Linux 3.23.

[![Build and Push Docker Image](https://github.com/<your-username>/<your-repo>/actions/workflows/build.yml/badge.svg)](https://github.com/<your-username>/<your-repo>/actions/workflows/build.yml)
![Platforms](https://img.shields.io/badge/platforms-amd64%20%7C%20arm64-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Included Versions

| Component    | Version |
|--------------|---------|
| PostgreSQL   | 18.3    |
| PostGIS      | 3.6.1   |
| TimescaleDB  | 2.25.2  |
| Alpine Linux | 3.23    |

## Quick Start

```bash
docker run -d \
  --name postgres \
  -e POSTGRES_PASSWORD=yourpassword \
  -e POSTGRES_DB=yourdb \
  -e POSTGRES_USER=youruser \
  -v pgdata:/var/lib/postgresql \
  -p 5432:5432 \
  ghcr.io/<your-username>/<your-repo>:latest
```

> **Note:** The volume must be mounted to `/var/lib/postgresql` (not `/var/lib/postgresql/data`).
> This is a breaking change introduced in PostgreSQL 18, where `PGDATA` is now version-specific
> (`/var/lib/postgresql/18/docker`).

## Docker Compose

```yaml
services:
  db:
    image: ghcr.io/<your-username>/<your-repo>:latest
    environment:
      POSTGRES_PASSWORD: yourpassword
      POSTGRES_DB: yourdb
      POSTGRES_USER: youruser
    volumes:
      - pgdata:/var/lib/postgresql
    ports:
      - "5432:5432"
    restart: unless-stopped

volumes:
  pgdata:
```

## Verify Extensions

```bash
# PostGIS
docker exec -it postgres psql -U youruser -d yourdb \
  -c "SELECT PostGIS_Full_Version();"

# TimescaleDB
docker exec -it postgres psql -U youruser -d yourdb \
  -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';"
```

## Initialization

On first start, `init-db.sh` is executed automatically and:

- Creates a `template_postgis` template database
- Enables `postgis`, `postgis_topology`, and `timescaledb` extensions in both
  `template_postgis` and `$POSTGRES_DB`

On subsequent starts with an existing volume, the script is skipped entirely by PostgreSQL.

## Build Arguments

All versions and checksums can be overridden at build time:

```bash
docker build \
  --build-arg POSTGIS_VERSION=3.6.1 \
  --build-arg POSTGIS_SHA256=<sha256> \
  --build-arg TIMESCALEDB_VERSION=2.25.2 \
  --build-arg TIMESCALEDB_SHA256=<sha256> \
  -t my-postgres .
```

Recalculate SHA256 checksums after a version change:

```bash
# PostGIS
curl -sL https://github.com/postgis/postgis/archive/refs/tags/<version>.tar.gz | sha256sum

# TimescaleDB
curl -sL https://github.com/timescale/timescaledb/archive/<version>.tar.gz | sha256sum
```

## Updating Versions

See [UPDATE_CHECKLIST.md](UPDATE_CHECKLIST.md) for a step-by-step guide on how to update
PostgreSQL, PostGIS, or TimescaleDB to a newer version.

## Licenses

This repository (Dockerfile and scripts) is licensed under the [MIT License](LICENSE).

The software included in the image is subject to its own licenses:

| Component   | License                                                                                      |
|-------------|----------------------------------------------------------------------------------------------|
| PostgreSQL  | [PostgreSQL License](https://www.postgresql.org/about/licence/)                             |
| PostGIS     | [GPL-2.0](https://git.osgeo.org/gitea/postgis/postgis/src/branch/master/COPYING)            |
| TimescaleDB | [Timescale License](https://github.com/timescale/timescaledb/blob/main/tsl/LICENSE-TIMESCALE) — Community Edition is free; some enterprise features require a commercial license |
| Alpine Linux | [Various](https://alpinelinux.org/alpine-linux-faq/#licensing)                             |
