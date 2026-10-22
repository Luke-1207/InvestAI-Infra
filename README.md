# InvestAI: Infraestrutura

Repositório de orquestração do InvestAI. Não contém código de aplicação, só o Docker Compose e a configuração de ambiente. O código fica em três repositórios separados:

- [InvestAI-API](https://github.com/Luke-1207/InvestAI-API): Java 21 e Spring Boot
- [InvestAI-IA](https://github.com/Luke-1207/InvestAI-IA): Python e FastAPI
- [investai-frontend](https://github.com/Luke-1207/investai-frontend): Angular 19, servido por nginx

## Pré-requisitos

Clone os quatro repositórios na mesma pasta pai, como irmãos:

```
sua-pasta/
├── InvestAI-API/
├── InvestAI-IA/
├── investai-frontend/
└── InvestAI-Infra/   <- você está aqui
```

O Compose constrói as imagens a partir do que está nessas pastas, então deixe cada repositório na branch que quer subir (normalmente `develop`, atualizada com `git pull`).

## Como rodar

1. Copie `.env.example` para `.env` e preencha os valores reais (chaves de API e senhas).
2. Libere as portas 4200, 8080, 8000, 5672 e 15672 (pare o `ng serve`, a API no IDE e containers avulsos de RabbitMQ).
3. `docker compose up -d --build`
4. Acompanhe com `docker compose ps` e `docker compose logs -f api`.

## Endereços

| Serviço | URL |
|---|---|
| Aplicação web | http://localhost:4200 |
| API (Swagger) | http://localhost:8080/investai-api/swagger-ui/index.html |
| Microsserviço de IA | http://localhost:8000/health |
| Painel do RabbitMQ | http://localhost:15672 |
| PostgreSQL | localhost:5433 |

## Comandos úteis

- Atualizar depois de mudar código: `docker compose up -d --build`
- Forçar build sem cache: `docker compose build --no-cache` e depois `docker compose up -d --force-recreate`
- Parar tudo mantendo os dados: `docker compose down`
- Parar e apagar o banco: `docker compose down -v` (apaga o volume `postgres_data`)

## Estrutura

- `docker-compose.yml`: orquestra PostgreSQL, RabbitMQ, a API, o microsserviço de IA e o frontend
- `.env.example`: todas as variáveis necessárias, documentadas
