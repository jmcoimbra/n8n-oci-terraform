# n8n no Oracle Cloud Always Free (Terraform)

Stack completa para subir [n8n](https://n8n.io) em uma VM Oracle Cloud Infrastructure **gratuita pra sempre**, com Terraform do começo ao fim. Secrets no OCI Vault. TLS automático via Caddy + Let's Encrypt. Postgres persistente. Zero cartão de crédito cobrado.

**Público-alvo:** devs em início de carreira que querem estudar automação/AI workflows sem pagar hosting.

**Custo esperado:** R$ 0/mês (dentro do Always Free tier).

## O que você ganha

- VM Ubuntu 22.04 ARM (1 OCPU / 6 GB RAM) em São Paulo
- n8n + Postgres 16 rodando em Docker
- Caddy com HTTPS automático (Let's Encrypt)
- Secrets criptografados no OCI Vault, lidos pela VM via instance principal (sem chave API na VM)
- IP público reservado (não muda em reboot)
- Firewall em duas camadas (security list + ufw)
- Fail2ban pra SSH
- Backup diário automático (postgres live + n8n_data) com upload offsite para Object Storage por default

## Arquitetura

```
Internet
   |
   v
[Cloudflare/DNS]  n8n.seusite.com.br --A--> 132.226.xxx.xxx
   |
   v
[OCI VCN - Public Subnet]
   |
   v
[VM A1.Flex Ubuntu 22.04]
   |
   +-- Caddy (80/443) --> TLS automático
   |
   +-- n8n (5678)  --->  Postgres (5432)
   |
   +-- systemd n8n.service
   |
   +-- cloud-init fetch-secrets.sh --> [OCI Vault]
```

## SO suportados

macOS, Linux (Ubuntu, Fedora, Arch) e Windows (via WSL2 recomendado, ou nativo com Git Bash). Instruções completas em [docs/01-pre-requisitos.md](docs/01-pre-requisitos.md).

## Quickstart (caminho feliz)

```bash
# 1. Pré-requisitos (doc 01 tem comandos por SO)
# macOS:   brew install terraform oci-cli
# Linux:   apt/dnf/pacman install terraform + pip install oci-cli
# Windows: wsl --install -d Ubuntu-22.04 e seguir o caminho Linux

ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

# 2. Conta OCI + API key (doc 02)
# Cria conta em https://signup.cloud.oracle.com
# Gera API key em User Settings > API Keys
# Salva private key em ~/.oci/oci_api_key.pem

# 3. Configurar (doc 03)
git clone https://github.com/jmcoimbra/n8n-oci-terraform.git
cd n8n-oci-terraform/terraform
cp terraform.tfvars.example terraform.tfvars
# edita terraform.tfvars com seus OCIDs, domínio, chave SSH

# 4. Deploy (doc 05)
terraform init
terraform apply

# 5. Cria A record no DNS apontando pra output 'public_ip'

# 6. Aguarda 5 min, abre https://<seu-dominio>
```

## Documentação completa (PT-BR)

1. [Pré-requisitos](docs/01-pre-requisitos.md)
2. [Criar conta OCI e coletar credenciais](docs/02-criar-conta-oci.md)
3. [Configurar Terraform](docs/03-configurar-terraform.md)
4. [Variáveis e Vault (secrets)](docs/04-variaveis-e-vault.md)
5. [Deploy](docs/05-deploy.md)
6. [Primeiro acesso ao n8n](docs/06-primeiro-acesso.md)
7. [Backup e manutenção](docs/07-backup-e-manutencao.md)
8. [Troubleshooting](docs/08-troubleshooting.md)

## Estrutura do repo

```
n8n-oci-terraform/
├── README.md                           # este arquivo
├── LICENSE                             # MIT
├── terraform/
│   ├── versions.tf                     # providers e versões
│   ├── providers.tf                    # config OCI
│   ├── variables.tf                    # todas as variáveis de entrada
│   ├── outputs.tf                      # IP, SSH command, OCIDs dos secrets
│   ├── network.tf                      # VCN, IGW, subnet, security list
│   ├── compute.tf                      # A1.Flex instance + public IP reservado
│   ├── vault.tf                        # Vault, key, 3 secrets, dynamic group, policy
│   ├── cloud-init.yaml.tpl             # bootstrap da VM
│   └── terraform.tfvars.example        # template de configuração
├── docker/
│   ├── docker-compose.yml              # referência (cloud-init monta na VM)
│   ├── Caddyfile                       # referência
│   └── env.example                     # referência
├── scripts/
│   ├── backup.sh                       # dump postgres + tarball n8n_data
│   ├── restore.sh                      # restaura postgres de dump
│   └── health-check.sh                 # valida DNS/TLS/HTTP do seu laptop
└── docs/                               # guia passo a passo em PT-BR
```

## Limites Always Free usados por este setup

| Recurso | Usado | Limite |
|---|---|---|
| A1 OCPU | 1 | 4 |
| A1 RAM | 6 GB | 24 GB |
| Boot volume | 50 GB | 200 GB |
| VCN | 1 | 2 |
| Public IP reservado | 1 | 2 |
| Vault | 1 | ilimitado (software-backed) |
| Secrets | 3 versões | 150 versões |

Sobra espaço pra mais 3 VMs iguais se quiser expandir.

## Quando este repo **não** serve

- Se você precisa de SLA (vá pra AWS/GCP pagos ou n8n Cloud)
- Se você vai processar volume alto (n8n cloud self-hosted enterprise)
- Se você não tem tolerância a reclamação ocasional de instância (raro, mas pode)

## Segurança

- Nenhum secret commitado. Tudo no Vault, lido via instance principal
- `terraform.tfvars` no `.gitignore`
- `*.pem` no `.gitignore`
- Basic Auth no Caddy + auth própria do n8n (duas camadas)
- SSH por chave apenas (password auth desabilitado no Ubuntu default)
- Fail2ban ativo
- UFW + security list OCI (defense in depth)

## Ajuda e comunidade

Travou? Antes de pedir ajuda:

1. Rode `./scripts/health-check.sh <seu-dominio>` para isolar se é DNS, TLS ou app
2. Veja [docs/08-troubleshooting.md](docs/08-troubleshooting.md) (erros comuns com solução direta)
3. SSH na VM e `sudo journalctl -u n8n.service -f` + `docker compose logs --tail=100`

Se mesmo assim travar:

- **Este repo:** abra uma issue em https://github.com/jmcoimbra/n8n-oci-terraform/issues com output dos logs, versão do terraform, SO e passo onde travou
- **n8n (dúvidas de workflow):** https://community.n8n.io (comunidade oficial, respostas rápidas)
- **OCI (dúvidas de conta, cobrança, suspensão):** https://cloudcustomerconnect.oracle.com (fórum oficial Oracle) ou ticket em https://support.oracle.com
- **Terraform (erros de HCL, providers):** https://discuss.hashicorp.com/c/terraform-core

## Aprendendo n8n depois do deploy

- **Docs oficiais:** https://docs.n8n.io
- **Templates prontos:** https://n8n.io/workflows (500+ workflows pra estudar)
- **YouTube:** canal oficial do n8n tem tutoriais de 5-15 min por feature
- **Ideias pra portfolio:** ver `docs/06-primeiro-acesso.md` seção 6.5

## Contribuindo

Issues e PRs bem-vindos. Este repo é propositadamente pequeno e focado. Se quiser adicionar funcionalidades (ex: módulo pra observability, backup automático via Object Storage), mantenha opcional atrás de variável.

## Licença

MIT. Ver [LICENSE](LICENSE).
