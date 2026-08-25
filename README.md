# InvestAI — Infraestrutura

Repositório de orquestração do InvestAI (TCC). Não contém código de aplicação — só
Docker Compose e configuração de ambiente. O código vive em dois repositórios separados:

- [InvestAI-API](https://github.com/SEU_USUARIO/InvestAI-API) — Java/Spring Boot
- [InvestAI-IA](https://github.com/SEU_USUARIO/InvestAI-IA) — Python/FastAPI

## Pré-requisitos

Clone os três repositórios **na mesma pasta pai**, como irmãos:

\`\`\`
sua-pasta/
├── InvestAI-API/
├── InvestAI-IA/
└── InvestAI-Infra/   <- você está aqui
\`\`\`

## Como rodar

1. Copie \`.env.example\` para \`.env\` e preencha os valores reais (chaves de API, senhas).
2. \`docker compose up\`

## Estrutura

- \`docker-compose.yml\` — orquestra Postgres, RabbitMQ, InvestAI-API e InvestAI-IA
- \`.env.example\` — todas as variáveis necessárias, documentadas