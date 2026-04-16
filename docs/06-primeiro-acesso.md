# 06. Primeiro acesso ao n8n

Depois do Basic Auth (passo 05.6), o n8n pede pra criar o **primeiro usuário owner**.

## 6.1 Criar owner

Formulário do n8n:
- Email
- Nome
- Sobrenome
- Senha

Essa senha é **dentro** do n8n (camada aplicação). Diferente do Basic Auth (camada Caddy).

Depois de criar o owner:
- Você pode **desligar o Basic Auth** se quiser (`N8N_BASIC_AUTH_ACTIVE=false` e reiniciar). O n8n já tem auth próprio a partir daqui.
- Ou mantém o Basic Auth como segunda camada.

## 6.2 Configurar timezone

Settings > **Personal Settings** > Timezone: `America/Sao_Paulo`.

## 6.3 Criar primeiro workflow (hello world)

1. **Workflows** > **Create Workflow**
2. Add trigger: **Manual Trigger**
3. Add node: **Set** > preenche um campo `message = "Hello n8n!"`
4. **Execute Workflow**
5. Deve retornar `{ "message": "Hello n8n!" }`

## 6.4 Webhook público

Para testar webhook externo:

1. Add trigger: **Webhook**
2. Method: POST, Path: `/teste`
3. Active: **toggle ON** (top right)
4. URL de produção vai aparecer: `https://n8n.seusite.com.br/webhook/teste`
5. Do seu laptop:

```bash
curl -X POST https://n8n.seusite.com.br/webhook/teste \
  -H "Content-Type: application/json" \
  -d '{"foo":"bar"}'
```

Deve aparecer execução no painel.

## 6.5 Ideias pra estudar (sugestões)

- **Telegram bot** recebendo mensagens e respondendo via OpenAI
- **Webhook Stripe** -> Google Sheets
- **RSS feed** -> Discord channel
- **Form do site** -> Email + Notion page
- **Cron job** pra scraping diário de notícias

Comunidade em https://community.n8n.io é ativa.

## 6.6 Atualizar n8n

Quando sair versão nova:

```bash
ssh ubuntu@<ip>
cd /opt/n8n
sudo docker compose pull n8n
sudo docker compose up -d n8n
```

**Sempre faça backup antes** (ver passo 07).

## Próximo

[07. Backup e manutenção](./07-backup-e-manutencao.md)
