#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [ $# -ne 1 ]; then
  echo "Uso: ./promover-gestor.sh email@do.usuario"
  exit 1
fi

set -a; source .env; set +a

docker compose -f docker-compose.prod.yml exec -T postgres \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 \
  -v email="$1" <<'SQL'
UPDATE usuarios SET role = 'GESTOR' WHERE email = :'email';
UPDATE usuarios SET ativo = false WHERE email = 'gestor@gmail.com';
SELECT nome, email, role, ativo FROM usuarios ORDER BY role, email;
SQL
