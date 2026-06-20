# CLAI 2026 — Setup do Ambiente Padronizado (Bootstrap)

> **Para que serve este documento:** garantir que **toda pessoa (e todo agente de IA)** que entra no projeto monte **exatamente o mesmo ambiente**, podendo trabalhar **em paralelo** sem divergência de versões, configuração ou dados.
>
> **Princípio:** *"clonou → rodou um comando → ambiente pronto e igual ao de todo mundo".*
>
> Este é o **primeiro documento a ser executado**. Só depois dele se começa a codar (ver `ESPECIFICACAO_FINAL_MVP.md`).

---

## 0. O que "ambiente igual para todos" exige

Reprodutibilidade tem **quatro camadas**, e este doc cobre todas:

| Camada | Como padronizamos |
|--------|-------------------|
| **Runtime** | Versão exata do Python (3.11.x) + venv local `.venv` |
| **Dependências** | `requirements.txt` com **versões fixadas** (pinned) — todos instalam o mesmo |
| **Configuração** | `.env` derivado de `.env.example` (mesmas chaves para todos) |
| **Dados/Nuvem (GCP)** | **Projeto GCP único e compartilhado** + cada dev autentica com a própria conta (ADC) + **namespace por dev** para não colidir |

---

## 1. Pré-requisitos por máquina (instalar uma vez)

Cada pessoa precisa ter, **antes** de rodar o bootstrap:

| Ferramenta | Versão | Verificar |
|-----------|--------|-----------|
| **Python** | **3.11.x** (fixo — não usar 3.12/3.13 no MVP) | `python --version` |
| **Git** | qualquer recente | `git --version` |
| **Google Cloud CLI (`gcloud`)** | recente | `gcloud --version` |
| **Claude Code** | recente | — |
| (Opcional) **uv** | acelera instalação | `uv --version` |

> **Atenção à versão do Python:** o ambiente foi validado em **3.11.4**. Divergir de versão maior é a causa nº 1 de "na minha máquina funciona". Padronize em 3.11.x.

---

## 2. O que é versionado × ignorado

**Versionado no Git (igual para todos):**
`clai/` (código) · `rxconfig.py` · `requirements.txt` · `.env.example` · `.gitignore` · `scripts/` · `Especificações do projeto/` · `CLAUDE.md`

**Nunca versionado (`.gitignore`):**
`.venv/` · `.env` · `.web/` (build do Reflex) · `__pycache__/` · `*.pyc` · chaves de Service Account (`*.json` de credencial) · `reflex_install.log` · `.reflex/`

---

## 3. Runbook de bootstrap (o que a IA executa primeiro)

> **Idempotente:** rodar de novo não quebra nada. Em uma máquina nova, a IA deve executar os passos 1→7 na ordem. No Windows use a coluna **PowerShell**; em macOS/Linux, **bash**.

### Passo 1 — Obter o código
```bash
git clone <URL_DO_REPO> CLAI_2026
cd CLAI_2026
```

### Passo 2 — Criar o virtualenv (Python 3.11)
| PowerShell (Windows) | bash (macOS/Linux) |
|----------------------|--------------------|
| `python -m venv .venv` | `python3.11 -m venv .venv` |

### Passo 3 — Instalar dependências fixadas
| PowerShell | bash |
|-----------|------|
| `.\.venv\Scripts\python.exe -m pip install --upgrade pip` | `./.venv/bin/python -m pip install --upgrade pip` |
| `.\.venv\Scripts\python.exe -m pip install -r requirements.txt` | `./.venv/bin/python -m pip install -r requirements.txt` |

> Sempre chamar o Python **pelo caminho do venv** (`.venv\Scripts\python.exe`) em vez de depender de `activate` — funciona igual em qualquer terminal/agente.

### Passo 4 — Configuração (`.env`)
```bash
# copiar o template e preencher os valores
cp .env.example .env            # PowerShell: Copy-Item .env.example .env
```
Preencher no `.env` (ver seção 5 para os valores combinados do time):
```
GCP_PROJECT_ID=...
GCP_REGION=southamerica-east1
GCP_DATASET=clai
GCS_BUCKET=clai-dev
GEMINI_API_KEY=...            # ou usar Vertex/ADC (ver seção 5)
DEV_NAMESPACE=<seu_usuario>   # isola seus dados de dev (ver seção 6)
```

### Passo 5 — Autenticar no GCP (cada dev com a própria conta)
```bash
gcloud auth application-default login        # gera as Application Default Credentials (ADC)
gcloud config set project <GCP_PROJECT_ID>   # mesmo project_id para todos
```
> Assim ninguém compartilha chave: cada pessoa usa seu login Google, e o **acesso** é concedido por IAM no projeto compartilhado.

### Passo 6 — Inicializar o Reflex (idempotente)
```bash
.venv\Scripts\python.exe -m reflex init      # só cria o que faltar; não sobrescreve código
```

### Passo 7 — Validar que o ambiente está OK
```bash
.venv\Scripts\python.exe -m reflex run       # sobe em http://localhost:3000
```
Se a página abrir, **ambiente pronto**. (Ver checklist na seção 9.)

### Passo 8 (opcional) — Seed de dados de dev
```bash
.venv\Scripts\python.exe scripts\seed.py     # popula riscos/incidentes de exemplo no SEU namespace
```

---

## 4. Reprodutibilidade de dependências

- O `requirements.txt` deve ter **versões fixas** (ex.: `reflex==0.9.5.post2`), não faixas (`>=`). Isso garante que todos instalem **exatamente o mesmo**.
- Ao adicionar uma dependência: instale, **fixe a versão** e **commite o `requirements.txt`** no mesmo PR. Avise o time para reinstalar (`pip install -r requirements.txt`).
- (Opcional, recomendado) usar **`uv`** para resolver/instalar mais rápido e gerar lock determinístico (`uv pip compile`). Não é obrigatório, mas acelera o time.

---

## 5. GCP compartilhado (modelo de acesso)

Como o projeto roda na **conta pessoal do dono** (não corporativo), o modelo é:

- **Um único `GCP_PROJECT_ID`** para todo o time (recursos: dataset BigQuery `clai`, bucket `clai-dev`, banco Firestore, Vertex).
- **Cada dev** acessa com a **própria conta Google** via ADC (passo 5) — o dono concede papéis IAM mínimos a cada e-mail (BigQuery Data Editor, Storage Object Admin, Firestore User, Vertex AI User).
- **Gemini:** definir no time **um** caminho e documentar no `.env.example`:
  - **(a) API do Gemini** (`google-genai` + `GEMINI_API_KEY`) — chave única do dono, mais simples; **ou**
  - **(b) Vertex AI** (mesmo SDK, auth por ADC) — sem API key, usa o login GCP de cada um.

> ⚠️ **Free tier compartilhado:** com várias pessoas no mesmo projeto, **a quota gratuita é somada entre todos**. Reforça os guardrails da seção 9 do `ESPECIFICACAO_FINAL_MVP.md` (budget alert, endpoint Vertex desligado quando ocioso, modelos `flash`/`flash-lite`).

---

## 6. Trabalho simultâneo sem pisar no pé do outro

### 6.1 Código (Git)
- Branch por feature: `feat/<modulo>-<descricao>` (ex.: `feat/planejamento-correlacao`).
- `main` sempre estável; merge via Pull Request + revisão.
- Combinar **divisão por módulo** (ver `ESPECIFICACAO_FINAL_MVP.md`): Planejamento / Abertura / Campo / Fechamento / FUP — reduz conflito.

### 6.2 Dados de dev (GCP compartilhado)
Para não misturar dados de teste entre devs no mesmo projeto, usar **namespace por pessoa** via `DEV_NAMESPACE`:
- BigQuery: tabelas/datasets com sufixo do dev em dev (ex.: dataset `clai_dev_vitor`), ou uma coluna `namespace`.
- Firestore: prefixo de coleção (ex.: `vitor__trabalhos`).
- Cloud Storage: prefixo de caminho (ex.: `dev/<DEV_NAMESPACE>/...`).
- O código deve **ler o prefixo do `.env`** (`DEV_NAMESPACE`) e aplicá-lo nos clients GCP, de modo que a mesma base de código isole automaticamente os dados de cada um.

---

## 7. Convenções de código (uniformidade)

| Item | Padrão |
|------|--------|
| Formatação/lint | **ruff** (format + lint) — configurar `ruff.toml`; rodar antes do commit |
| Estilo | snake_case em Python; componentes Reflex e States por módulo (ver estrutura da spec) |
| Tipos | type hints + Pydantic nos `models/` |
| Idioma | código/identificadores em inglês; textos de UI em pt-BR |
| Commits | mensagens curtas e descritivas; 1 assunto por PR |

> (Opcional) configurar **pre-commit** para rodar `ruff` automaticamente — garante que todo mundo commita no mesmo padrão.

---

## 8. Arquivos-base que precisam existir no repo

A IA, no primeiro setup, deve garantir que estes arquivos existam (criar se faltarem):

| Arquivo | Papel |
|---------|-------|
| `requirements.txt` | dependências fixadas (seção 4) |
| `.env.example` | todas as chaves de config, sem valores secretos |
| `.gitignore` | itens da seção 2 |
| `rxconfig.py` | config do Reflex (gerado pelo `reflex init`) |
| `scripts/setup.ps1` / `scripts/setup.sh` | bootstrap em **um comando** (encapsula passos 2–7) |
| `scripts/vector_search.py` | `start`/`stop` do índice Vertex (guardrail de custo) |
| `scripts/seed.py` | dados de exemplo no namespace do dev |
| `CLAUDE.md` | instruções do projeto carregadas automaticamente pela IA |

---

## 9. Checklist "ambiente pronto" (Definition of Ready)

- [ ] `python --version` → 3.11.x
- [ ] `.venv` criado e dependências instaladas sem erro
- [ ] `.env` preenchido (project, região, dataset, bucket, namespace, Gemini)
- [ ] `gcloud auth application-default login` feito e `project` setado
- [ ] `reflex run` sobe a app em `localhost:3000`
- [ ] Acesso ao GCP validado (consegue listar o dataset/bucket)
- [ ] `ruff` instalado e rodando

Quando todos os itens estiverem ✅, o ambiente está **idêntico ao do time** e pronto para desenvolver.

---

## 10. Troubleshooting comum

| Sintoma | Causa provável | Solução |
|---------|----------------|---------|
| `activate` não persiste no terminal/agente | shell não mantém estado | chamar `\.venv\Scripts\python.exe` direto |
| Erro de parser no PowerShell ao chamar exe entre aspas | falta o operador `&` | `& ".\.venv\Scripts\python.exe" ...` |
| Versões divergentes entre devs | `requirements.txt` com faixas | fixar versões e reinstalar |
| `PermissionDenied` no GCP | IAM não concedido | dono adiciona o e-mail aos papéis (seção 5) |
| Custo subindo | endpoint Vertex ligado | `scripts/vector_search.py stop` |
| Dados de dev misturados | sem namespace | preencher `DEV_NAMESPACE` no `.env` |
