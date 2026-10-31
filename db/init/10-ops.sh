#!/bin/sh
# Roda uma única vez, quando o volume do Postgres é criado.
# Cria o papel de aplicação (privilégio mínimo) e o banco "ops" com esquema e dados de exemplo.
set -eu

: "${OPS_APP_PASSWORD:?defina OPS_APP_PASSWORD}"
OPS_MEMORIA_PASSWORD="${OPS_MEMORIA_PASSWORD:-$OPS_APP_PASSWORD}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE ROLE ops_app LOGIN PASSWORD '${OPS_APP_PASSWORD}';
    CREATE ROLE ops_memoria LOGIN PASSWORD '${OPS_MEMORIA_PASSWORD}';
    CREATE DATABASE ops OWNER "${POSTGRES_USER}";
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname ops -f /opt/ops-sql/schema.sql
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname ops -f /opt/ops-sql/seed.sql
