FROM postgres:17-alpine

# Esquema e dados de exemplo ficam fora de docker-entrypoint-initdb.d de propósito:
# quem roda é o 10-ops.sh, que antes cria o papel ops_app e o banco "ops".
COPY sql/ /opt/ops-sql/
COPY init/ /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/*.sh
