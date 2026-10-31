#!/usr/bin/env bash
# Sobe o ambiente local do zero: containers, usuário dono do n8n, credenciais e workflows publicados.
#
#   scripts/dev-up.sh mock    # OpenAI e Telegram falsos + Mailpit: roda sem nenhuma chave (padrão)
#   scripts/dev-up.sh real    # usa OPENAI_API_KEY, TELEGRAM_BOT_TOKEN etc. do seu ambiente
#
# Depois: n8n em http://localhost:5678 (dev@example.com / DevOps12345) e e-mails em http://localhost:8025
set -euo pipefail
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.."

MODO="${1:-mock}"
if [ "$MODO" = "mock" ]; then
  PERFIL=(--profile mock)
  CRED_FLAG=(--mock)
  export OPS_DB_PASSWORD="${OPS_DB_PASSWORD:-ops_app_dev}" OPS_MEMORIA_PASSWORD="${OPS_MEMORIA_PASSWORD:-ops_memoria_dev}"
else
  PERFIL=()
  CRED_FLAG=()
  export OPS_DB_PASSWORD="${OPS_DB_PASSWORD:-ops_app_dev}" OPS_MEMORIA_PASSWORD="${OPS_MEMORIA_PASSWORD:-ops_memoria_dev}"
fi

COMPOSE=(docker compose -f docker-compose.dev.yml "${PERFIL[@]}")

echo "→ subindo containers"
"${COMPOSE[@]}" up -d --build

echo "→ aguardando o n8n"
for _ in $(seq 1 90); do
  curl -fs http://localhost:5678/healthz/readiness >/dev/null 2>&1 && break
  sleep 2
done

echo "→ criando o usuário dono (ignorado se já existir)"
curl -s -o /dev/null -X POST http://localhost:5678/rest/owner/setup \
  -H 'content-type: application/json' \
  -d '{"email":"dev@example.com","firstName":"Dev","lastName":"Ops","password":"DevOps12345"}' || true

echo "→ gerando credenciais ($MODO)"
node scripts/seed-credentials.mjs "${CRED_FLAG[@]}" > .credentials.dev.json

bash scripts/importar-no-n8n.sh "$("${COMPOSE[@]}" ps -q n8n)" .credentials.dev.json

echo
echo "n8n:     http://localhost:5678   (dev@example.com / DevOps12345)"
echo "Mailpit: http://localhost:8025"
echo "Form:    http://localhost:5678/form/nova-demanda"
