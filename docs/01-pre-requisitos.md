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

Você precisa de `terraform`, `oci-cli`, `git` e `ssh` no laptop. Escolha o caminho do seu SO:

### macOS

```bash
# Homebrew: https://brew.sh
brew install terraform oci-cli git
```

### Linux (Ubuntu/Debian)

```bash
# Terraform via repositório oficial HashiCorp
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform git

# OCI CLI via pip (recomendado, funciona em qualquer distro)
sudo apt-get install -y python3-pip
pip3 install --user oci-cli
```

### Linux (Fedora/RHEL)

```bash
sudo dnf install -y dnf-plugins-core git python3-pip
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
sudo dnf install -y terraform
pip3 install --user oci-cli
```

### Linux (Arch)

```bash
sudo pacman -S terraform git python-pip
pip install --user oci-cli
```

### Windows

Recomendação: **WSL2 (Windows Subsystem for Linux) com Ubuntu**. Todo o resto dos comandos do repo é `bash`, então evita bifurcação de docs e scripts.

```powershell
# Abra PowerShell como Administrador
wsl --install -d Ubuntu-22.04
# Reinicie a máquina, abra o Ubuntu no menu iniciar, crie seu usuário Linux.
# Dentro do WSL, siga a seção "Linux (Ubuntu/Debian)" acima.
```

Alternativa nativa sem WSL (funciona mas nos comandos SSH e scripts `.sh` você vai ter atrito):

```powershell
# Chocolatey: https://chocolatey.org/install
choco install terraform oci-cli git -y

# Ou winget:
winget install --id Hashicorp.Terraform
winget install --id Oracle.OCICLI
winget install --id Git.Git
```

No caminho nativo, rode os comandos `bash` em Git Bash (vem com o Git for Windows).

### Valide (qualquer SO)

```bash
terraform version   # >= 1.5
oci --version       # >= 3.40
git --version

# Gerar chave SSH (se ainda não tiver)
# macOS/Linux/WSL:
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
# Windows nativo (PowerShell):
ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\id_ed25519
```

## Convenção de paths neste repo

Todos os comandos nos docs usam paths Unix (`~/.oci/oci_api_key.pem`, `~/.ssh/id_ed25519`). Equivalências:

| Unix path | Windows nativo (PowerShell) | WSL2 |
|---|---|---|
| `~/.oci/oci_api_key.pem` | `$env:USERPROFILE\.oci\oci_api_key.pem` | igual ao Unix |
| `~/.ssh/id_ed25519` | `$env:USERPROFILE\.ssh\id_ed25519` | igual ao Unix |
| `chmod 600 <file>` | `icacls <file> /inheritance:r /grant:r "$($env:USERNAME):R"` | igual ao Unix |

Se estiver no Windows nativo e um comando no doc usar `~/`, traduza para `$env:USERPROFILE\`.

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
