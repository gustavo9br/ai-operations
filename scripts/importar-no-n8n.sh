#!/usr/bin/env bash
# Importa credenciais e workflows num n8n que já está rodando em um container Docker e publica os workflows.
#
# Uso:
#   scripts/importar-no-n8n.sh <container-n8n> <arquivo-de-credenciais.json>
# Exemplos:
#   node scripts/seed-credentials.mjs --mock > .credentials.dev.json
#   scripts/importar-no-n8n.sh ai-operations-n8n-1 .credentials.dev.json
#
# No Swarm/Portainer, descubra o container com:  docker ps --filter name=aiops_n8n -q
set -euo pipefail
# Git Bash (Windows) reescreve argumentos que começam com "/"; isso quebraria os caminhos dentro do container.
export MSYS_NO_PATHCONV=1

CONTAINER="${1:?informe o nome ou ID do container do n8n}"
CREDS="${2:?informe o arquivo de credenciais gerado por seed-credentials.mjs}"
RAIZ="$(dirname "$0")/.." # caminho relativo de propósito: o docker.exe do Windows não entende /c/Users/...

echo "→ copiando arquivos para o container"
docker exec "$CONTAINER" mkdir -p /tmp/import/workflows
docker cp "$CREDS" "$CONTAINER:/tmp/import/credentials.json"
docker cp "$RAIZ/workflows/." "$CONTAINER:/tmp/import/workflows/"

echo "→ importando credenciais"
docker exec "$CONTAINER" n8n import:credentials --input=/tmp/import/credentials.json

echo "→ importando workflows"
docker exec "$CONTAINER" n8n import:workflow --separate --input=/tmp/import/workflows

echo "→ publicando workflows"
# O de erros primeiro, porque os demais apontam para ele como "Error Workflow".
for id in aiopsErrHandler1 aiopsTriagem0001 aiopsSlaWatch001 aiopsConcluir001; do
  docker exec "$CONTAINER" n8n publish:workflow --id="$id"
done

docker exec "$CONTAINER" rm -rf /tmp/import
echo "→ reiniciando o n8n para registrar os webhooks"
docker restart "$CONTAINER" >/dev/null
echo "Pronto. Abra o n8n e confira os 4 workflows publicados."
