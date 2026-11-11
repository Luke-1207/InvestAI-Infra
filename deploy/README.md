# Deploy do InvestAI na nuvem (gratuito)

| Parte | Onde roda | Endereço |
|---|---|---|
| Frontend (Angular) | Vercel | https://investai-tcc.vercel.app (fixo) |
| API, IA, PostgreSQL, RabbitMQ | VM Oracle Cloud Always Free, via Docker Compose | https://investai-tcc.duckdns.org |

O navegador só fala com a Vercel. A Vercel repassa tudo que começa com `/investai-api/` para a VM (configurado no `vercel.json` do frontend). Assim o link do frontend nunca muda, mesmo que a VM seja trocada: basta apontar o DuckDNS ou o `vercel.json` para o novo endereço.

## 1. VM na Oracle Cloud

1. Crie a conta em https://www.oracle.com/cloud/free/ (pede cartão só para verificação). Região: Brazil East (São Paulo) ou Brazil Southeast (Vinhedo). A região não pode ser trocada depois.
2. Compute > Instances > Create instance:
   - Image: Canonical Ubuntu 24.04
   - Shape: Ampere `VM.Standard.A1.Flex`, 2 OCPUs e 6 GB de memória
   - Baixe a chave SSH privada que ela gera
   - Se aparecer "Out of capacity", tente outro Availability Domain ou tente de novo mais tarde.
3. Na VCN da instância: Security Lists > Default > Add Ingress Rules: origem `0.0.0.0/0`, TCP, portas `80` e `443`.
4. Acesse a VM e libere as portas no firewall interno do Ubuntu da Oracle:

```bash
chmod 600 chave.key
ssh -i chave.key ubuntu@IP_DA_VM
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```

5. Instale o Docker e saia/entre de novo no SSH:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
exit
```

## 2. Domínio fixo no DuckDNS

1. Entre em https://www.duckdns.org com o GitHub.
2. Crie o subdomínio `investai-tcc` e coloque o IP público da VM.

## 3. Subir o backend

Crie um token no GitHub (Settings > Developer settings > Fine-grained tokens) só com leitura de *Contents* nos repositórios InvestAI-API, InvestAI-IA e InvestAI-Infra. Na VM:

```bash
git config --global credential.helper store
mkdir -p ~/investai && cd ~/investai
git clone -b develop https://github.com/Luke-1207/InvestAI-API.git
git clone -b develop https://github.com/Luke-1207/InvestAI-IA.git
git clone -b develop https://github.com/Luke-1207/InvestAI-Infra.git
# usuário: Luke-1207 / senha: o token

cd InvestAI-Infra/deploy
cp .env.example .env
nano .env
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml logs -f api
```

O primeiro build leva alguns minutos. Teste de fora:

```bash
curl -i -X POST https://investai-tcc.duckdns.org/investai-api/v1/auth/login \
  -H "Content-Type: application/json" -d '{"email":"x@x.com","senha":"errada"}'
```

Uma resposta 401 ou 400 em JSON quer dizer que HTTPS, Caddy e API estão funcionando.

## 4. Frontend na Vercel

1. Entre em https://vercel.com com o GitHub > Add New > Project > importe `investai-frontend`.
2. Project Name: `investai-tcc`. O link de produção será `https://investai-tcc.vercel.app`.
3. Framework Preset: Other. Build e pasta de saída já vêm do `vercel.json`.
4. Settings > Git > Production Branch: `main`. Deploy novo = merge da develop na main.
5. Se o subdomínio do DuckDNS ou o nome do projeto mudarem, ajuste `vercel.json` e `FRONTEND_URL` no `.env` da VM.

## 5. Usuários de avaliação

1. No link da Vercel, crie pelo cadastro as duas contas (uma comum e uma que vai virar gestor).
2. Na VM, promova a segunda e desative o gestor de desenvolvimento (`gestor@gmail.com`):

```bash
./promover-gestor.sh email.do.gestor@exemplo.com
```

3. Faça logout e login de novo com o gestor para o novo papel valer.

## 6. Atualizar depois

- Backend: `./atualizar.sh` na VM (git pull nos três repositórios e rebuild).
- Frontend: merge na branch de produção da Vercel.

## Dicas

- Crie um monitor gratuito no UptimeRobot para `https://investai-tcc.vercel.app` e para a URL do curl acima, a cada 5 minutos. Você recebe e-mail se cair.
- A Oracle pode recuperar instâncias Always Free ociosas (CPU, rede e memória abaixo de 20% por 7 dias). A VM de 6 GB com a stack rodando fica acima disso em memória.
