#!/usr/bin/env bash
set -uo pipefail

ARQUIVO_LOG="smoke-test-resultado-$(date +%Y%m%d-%H%M%S).log"
FALHAS=0

log() {
    echo "$1" | tee -a "$ARQUIVO_LOG"
}

ok() {
    log "✅ OK — $1"
}

falhou() {
    log "❌ FALHOU — $1"
    FALHAS=$((FALHAS + 1))
}

aguardar_http() {
    local url=$1
    local tentativas=${2:-30}
    local intervalo=${3:-2}
    for _ in $(seq 1 "$tentativas"); do
        if curl -s -o /dev/null "$url" 2>/dev/null; then
            return 0
        fi
        sleep "$intervalo"
    done
    return 1
}

log "===== Smoke Test InvestAI — $(date) ====="
log ""

if [ ! -f .env ]; then
    log "❌ Arquivo .env não encontrado nessa pasta. Rode a partir de InvestAI-Infra."
    exit 1
fi
# shellcheck disable=SC1091
source .env

# ---------- 1. docker compose up --build sem erros ----------
log "--- 1. Subindo o stack completo (docker compose up --build) ---"
docker compose down -v >>"$ARQUIVO_LOG" 2>&1
if docker compose up --build -d >>"$ARQUIVO_LOG" 2>&1; then
    ok "docker compose up executou sem erro de build/subida"
else
    falhou "docker compose up retornou erro — veja $ARQUIVO_LOG"
    log ""
    log "===== Interrompido: sem o stack de pé, os próximos testes não fazem sentido ====="
    exit 1
fi

log "Aguardando postgres e rabbitmq ficarem healthy..."
for _ in $(seq 1 30); do
    STATUS=$(docker compose ps postgres rabbitmq 2>/dev/null)
    if echo "$STATUS" | grep -qi "postgres.*healthy" && echo "$STATUS" | grep -qi "rabbitmq.*healthy"; then
        break
    fi
    sleep 2
done

if echo "$STATUS" | grep -qi "postgres.*healthy" && echo "$STATUS" | grep -qi "rabbitmq.*healthy"; then
    ok "postgres e rabbitmq ficaram healthy"
else
    falhou "postgres e/ou rabbitmq não ficaram healthy a tempo"
    log "   Status atual:"
    log "$STATUS"
fi

log "Aguardando api e ia-service responderem..."
aguardar_http "http://localhost:8080/investai-api" 30 2 || true
aguardar_http "http://localhost:8000/health" 30 2 || true
log ""

# ---------- 2. Flyway aplicou todas as migrations ----------
log "--- 2. Verificando migrations do Flyway ---"
RESULTADO_MIGRATIONS=$(docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    -t -c "SELECT COUNT(*) FROM flyway_schema_history WHERE success = false;" 2>>"$ARQUIVO_LOG")
RESULTADO_MIGRATIONS=$(echo "$RESULTADO_MIGRATIONS" | tr -d '[:space:]')

if [ "$RESULTADO_MIGRATIONS" = "0" ]; then
    TOTAL=$(docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -t -c "SELECT COUNT(*) FROM flyway_schema_history;" 2>>"$ARQUIVO_LOG" | tr -d '[:space:]')
    ok "todas as $TOTAL migrations aplicadas com sucesso, nenhuma falha"
else
    falhou "existem $RESULTADO_MIGRATIONS migration(s) marcadas como falha"
fi
log ""

# ---------- 3. Filas RabbitMQ visíveis ----------
log "--- 3. Verificando filas do RabbitMQ ---"
RESPOSTA_FILAS=$(curl -s -u "${SPRING_RABBITMQ_USERNAME:-guest}:${SPRING_RABBITMQ_PASSWORD:-guest}" \
    http://localhost:15672/api/queues)

FILAS_ESPERADAS=("ia.ranking.request" "ia.ranking.response" "ia.resumo.request" "ia.resumo.response")
FILAS_OK=0
for FILA in "${FILAS_ESPERADAS[@]}"; do
    if echo "$RESPOSTA_FILAS" | grep -q "\"name\":\"$FILA\""; then
        FILAS_OK=$((FILAS_OK + 1))
    else
        log "   (fila ausente: $FILA)"
    fi
done

if [ "$FILAS_OK" -eq 4 ]; then
    ok "as 4 filas esperadas estão criadas e visíveis"
else
    falhou "só $FILAS_OK de 4 filas encontradas"
fi
log ""

# ---------- 4. GET /health do Python ----------
log "--- 4. Verificando /health do microsserviço IA ---"
RESPOSTA_HEALTH=$(curl -s http://localhost:8000/health)
log "   Resposta: $RESPOSTA_HEALTH"

if echo "$RESPOSTA_HEALTH" | grep -q '"status":"ok"' || echo "$RESPOSTA_HEALTH" | grep -q '"status": "ok"'; then
    ok "microsserviço IA respondeu status ok"
else
    falhou "microsserviço IA não respondeu status ok"
fi
log ""

# ---------- 5. POST /v1/auth/cadastro ----------
log "--- 5. Testando cadastro de usuário ---"
EMAIL_TESTE="smoke-test-$(date +%s)@investai.com"
RESPOSTA_CADASTRO=$(curl -s -w "\n%{http_code}" -X POST \
    http://localhost:8080/investai-api/v1/auth/cadastro \
    -H "Content-Type: application/json" \
    -d "{\"nome\":\"Teste Smoke\",\"email\":\"$EMAIL_TESTE\",\"senha\":\"SenhaForte123#\",\"confirmarSenha\":\"SenhaForte123#\"}")

CODIGO_HTTP=$(echo "$RESPOSTA_CADASTRO" | tail -n1)
CORPO_RESPOSTA=$(echo "$RESPOSTA_CADASTRO" | sed '$d')
log "   HTTP $CODIGO_HTTP — $CORPO_RESPOSTA"

if [ "$CODIGO_HTTP" = "200" ] || [ "$CODIGO_HTTP" = "201" ]; then
    ok "cadastro criado com sucesso (HTTP $CODIGO_HTTP)"
else
    falhou "cadastro retornou HTTP $CODIGO_HTTP (esperado 200/201)"
fi
log ""

# ---------- Resumo final ----------
log "===== Resumo ====="
if [ "$FALHAS" -eq 0 ]; then
    log "🎉 Todos os 5 testes passaram."
else
    log "⚠️  $FALHAS teste(s) falharam — veja os detalhes acima."
fi
log "Log completo salvo em: $ARQUIVO_LOG"

exit "$FALHAS"