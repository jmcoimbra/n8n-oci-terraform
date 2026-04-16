# 01. Pré-requisitos

Antes de começar, tenha:

## Contas e acesso

- **Conta Oracle Cloud Infrastructure (OCI)** com tier Always Free ativado
  - Cartão de crédito internacional para verificação (não é cobrado)
  - IP residencial limpo (VPN pode causar bloqueio da conta nova)
  - Home region: `sa-saopaulo-1` (São Paulo) ou `sa-vinhedo-1` (Vinhedo). Se ARM A1 estiver esgotado, use `us-ashburn-1`
- **Domínio registrado** (registro.br, Cloudflare, GoDaddy, Namecheap etc) com acesso ao painel de DNS
- **Git + conta no GitHub** para clonar este repo

## Ferramentas locais

Instale no seu laptop (macOS via Homebrew, Linux via pacote da distro):

```bash
# macOS
brew install terraform oci-cli

# Ubuntu/Debian
sudo apt install -y terraform
curl -L -o /tmp/install-oci.sh https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh
bash /tmp/install-oci.sh --accept-all-defaults
```

Valide:

```bash
terraform version   # >= 1.5
oci --version       # >= 3.40
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519  # se ainda não tiver
```

## Conhecimento mínimo

Não precisa ser expert. Você vai aprender nessa jornada. Ter noção de:

- Terminal (cd, ls, ssh)
- Git básico (clone, pull)
- DNS básico (o que é A record)
- Docker básico (o que é container)

## Custos esperados

| Item | Custo |
|---|---|
| VM A1.Flex (1 OCPU / 6 GB) | **R$ 0** (Always Free) |
| Boot volume 50 GB | **R$ 0** (Always Free) |
| VCN + IGW + rede | **R$ 0** |
| OCI Vault + secrets (software-backed) | **R$ 0** |
| IP público reservado | **R$ 0** |
| Outbound traffic até 10 TB/mês | **R$ 0** |
| **Total mensal** | **R$ 0** |

Só começa a pagar se passar dos limites Always Free. Para n8n em estudo, não acontece.

## Próximo

[02. Criar conta OCI](./02-criar-conta-oci.md)
