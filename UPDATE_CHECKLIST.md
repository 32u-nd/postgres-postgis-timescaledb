# Version Update Checklist

## 1. Check Release Compatibility

- [ ] Verify the new **PostgreSQL** version is available as an Alpine Docker image
      `https://hub.docker.com/_/postgres/tags`
- [ ] Verify **PostGIS** supports the new PostgreSQL major version
      (PostGIS 3.6+ required for PostgreSQL 18+)
- [ ] Verify **TimescaleDB** supports the new PostgreSQL major version
      `https://docs.timescale.com/self-hosted/latest/upgrades/`
- [ ] Check Alpine version compatibility with `clang`/`llvm` packages
      (package names like `clang19`, `llvm19` are version-specific)

## 2. Update SHA256 Checksums

- [ ] Recalculate **PostGIS** SHA256 (GitHub archive hash differs from OSGeo tarball):
      ```bash
      curl -sL https://github.com/postgis/postgis/archive/refs/tags/<version>.tar.gz | sha256sum
      ```
- [ ] Recalculate **TimescaleDB** SHA256:
      ```bash
      curl -sL https://github.com/timescale/timescaledb/archive/<version>.tar.gz | sha256sum
      ```
- [ ] Update `ARG POSTGIS_SHA256` and `ARG TIMESCALEDB_SHA256` in the Dockerfile

## 3. Update Dockerfile

- [ ] Update `FROM postgres:<version>-alpine<version>`
- [ ] Update `ARG ALPINE_VERSION`, `POSTGIS_VERSION`, `TIMESCALEDB_VERSION`
- [ ] Update `LABEL` fields (`image.version`, `image.description`, `image.base.name`)
- [ ] Check if `clang`/`llvm` package names need updating (e.g. `clang19` → `clang20`)
      and update the hardcoded `/usr/bin/clang-19` path in the `sed` command accordingly
- [ ] On **PostgreSQL major version upgrade**: check if `ENV PGDATA` path needs updating
      (PG18+: `/var/lib/postgresql/<major>/docker`)

## 4. Build & Test

- [ ] Build the image:
  ````bash
  docker build -t myimage:test .
  ````
- [ ] Run and verify all extensions load correctly:
  ````bash
  docker run --rm -e POSTGRES_PASSWORD=test -e POSTGRES_DB=testdb myimage:test postgres --version

  docker exec <container> psql -U postgres -d testdb -c "SELECT PostGIS_Full_Version();"
  docker exec <container> psql -U postgres -d testdb -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';"
  ````

## 5. Data Migration (major version upgrades only)

- [ ] **Never** reuse an existing data volume across a PostgreSQL major version upgrade
- [ ] Use `pg_upgrade` or dump/restore to migrate data:
  ````bash
  pg_dumpall -U postgres > backup.sql
  # start new container, then:
  psql -U postgres < backup.sql
  ````
- [ ] Update volume mount path if `PGDATA` changed