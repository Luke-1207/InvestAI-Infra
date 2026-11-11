#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

for repo in ../../InvestAI-API ../../InvestAI-IA ..; do
  git -C "$repo" pull --ff-only
done

docker compose -f docker-compose.prod.yml up -d --build
docker image prune -f
docker compose -f docker-compose.prod.yml ps
