#!/bin/sh
set -e

# This script runs only once on first container start (when PGDATA is empty).
# On subsequent starts with an existing volume, PostgreSQL skips this directory.

# ---------------------------------------------------------------------------
# Create PostGIS template database
# ---------------------------------------------------------------------------

# Check if template_postgis already exists (safety guard for edge cases)
DB_EXISTS=$(psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --tuples-only --no-align \
    -c "SELECT 1 FROM pg_database WHERE datname = 'template_postgis';")

if [ "$DB_EXISTS" = "1" ]; then
    echo "template_postgis already exists, skipping creation."
else
    echo "Creating template_postgis..."
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        CREATE DATABASE template_postgis;
        UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template_postgis';
EOSQL
fi

# ---------------------------------------------------------------------------
# Enable extensions in template_postgis and $POSTGRES_DB
# ---------------------------------------------------------------------------
for DB in template_postgis "$POSTGRES_DB"; do
    echo "Loading extensions into ${DB}..."
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname="$DB" <<-EOSQL
        CREATE EXTENSION IF NOT EXISTS postgis CASCADE;
        CREATE EXTENSION IF NOT EXISTS postgis_topology CASCADE;
        CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
EOSQL
done

echo "Initialization complete."