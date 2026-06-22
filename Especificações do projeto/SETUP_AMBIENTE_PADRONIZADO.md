# CLAI 2026 — Setup do Ambiente Padronizado (Bootstrap)

> **Para que serve este documento:** garantir que **toda pessoa (e todo agente de IA)** que entra no projeto monte **exatamente o mesmo ambiente**, podendo trabalhar **em paralelo** sem divergência de versões, configuração ou dados.
>
> **Princípio:** *"clonou → rodou um comando → ambiente pronto e igual ao de todo mundo".*
>
> Arquitetura: **monorepo** com `backend/` (FastAPI/Python) e `frontend/` (React/Vite/TS). Este é o **primeiro documento a ser executado**. Só depois dele se começa a codar (ver `ESPECIFICACAO_FINAL_MVP.md`).

---

## 0. O que "ambiente igual para todos" exige

Reprodutibilidade tem **quatro camadas**, e este doc cobre todas:

| Camada | Como padronizamos |
|--------|-------------------|
| **Runtime** | Python **3.11.x** (backend, venv em `backend/.venv`) + **Node LTS** (frontend) |
| **Dependências** | `backend/requirements.txt` (versões fixas) + `frontend/package-lock.json` (lock do npm) |
| **Configuração** | `.env` (backend) e `frontend/.env` (`VITE_*`), ambos derivados de templates |
| **Dados/Nuvem (GCP)** | **Projeto GCP único e compartilhado** + cada dev autentica com a própria conta (ADC) + **namespace por dev** |

---

## 1. Pré-requisitos por máquina (instalar uma vez)

| Ferramenta | Versão | Verificar |
|-----------|--------|-----------|
| **Python** | **3.11.x** (fixo — não usar 3.12/3.13 no MVP) | `python --version` |
| **Node.js** | **LTS** (18 ou 20) + npm | `node --version` / `npm --version` |
| **Git** | qualquer recente | `git --version` |
| **Google Cloud CLI (`gcloud`)** | recente | `gcloud --version` |
| **Claude Code** | recente | — |
| (Opcional) **uv** | acelera instalação Python | `uv --version` |

> **Atenção à versão do Python:** o backend foi validado em **3.11.4**. Divergir de versão maior é a causa nº 1 de "na minha máquina funciona". Padronize em 3.11.x.

---

## 2. O que é versionado × ignorado

**Versionado no Git (igual para todos):**
`backend/` (código) · `backend/requirements.txt` · `frontend/` (código) · `frontend/package.json` · `frontend/package-lock.json` · `.env.example` · `frontend/.env.example` · `.gitignore` · `scripts/` · `Especificações do projeto/` · `CLAUDE.md`

**Nunca versionado (`.gitignore`):**
`backend/.venv/` · `.env` · `frontend/.env` · `frontend/node_modules/` · `frontend/dist/` · `__pycache__/` · `*.pyc` · chaves de Service Account (`*.json` de credencial) · `*.log`

---

## 3. Runbook de bootstrap (o que a IA executa primeiro)

> **Idempotente:** rodar de novo não quebra nada. No Windows use a coluna **PowerShell**; em macOS/Linux, **bash**.

### Passo 1 — Obter o código
```bash
git clone <URL_DO_REPO> clai-2026
cd clai-2026
```

### Passo 2 — Backend: venv (Python 3.11) + dependências
| PowerShell (Windows) | bash (macOS/Linux) |
|----------------------|--------------------|
| `python -m venv backend\.venv` | `python3.11 -m venv backend/.venv` |
| `& backend\.venv\Scripts\python.exe -m pip install --upgrade pip` | `backend/.venv/bin/python -m pip install --upgrade pip` |
| `& backend\.venv\Scripts\python.exe -m pip install -r backend\requirements.txt` | `backend/.venv/bin/python -m pip install -r backend/requirements.txt` |

> Sempre chamar o Python **pelo caminho do venv** em vez de depender de `activate` — funciona igual em qualquer terminal/agente.

### Passo 3 — Frontend: dependências (npm)
```bash
cd frontend
npm install          # instala a partir do package-lock.json (versões travadas)
cd ..
```

### Passo 4 — Configuração (`.env`)
```bash
# backend (raiz):
cp .env.example .env                      # PowerShell: Copy-Item .env.example .env
# frontend:
cp frontend/.env.example frontend/.env    # PowerShell: Copy-Item frontend\.env.example frontend\.env
```
Preencher no `.env` (raiz) os valores combinados do time:
```
GCP_PROJECT_ID=clai-2026-500018
GCP_REGION=southamerica-east1
GCP_DATASET=clai
GCS_BUCKET=clai-dev
GEMINI_API_KEY=...            # ou usar Vertex/ADC (ver seção 5)
DEV_NAMESPACE=<seu_usuario>   # isola seus dados de dev (ver seção 6)
```
E no `frontend/.env`:
```
VITE_API_BASE_URL=http://localhost:8000
```

### Passo 5 — Autenticar no GCP (cada dev com a própria conta)
```bash
gcloud auth application-default login        # gera as Application Default Credentials (ADC)
gcloud config set project clai-2026-500018   # mesmo project_id para todos
```
> Ninguém compartilha chave: cada pessoa usa seu login Google; o **acesso** é concedido por IAM no projeto compartilhado.

### Passo 6 — Validar o backend
```bash
cd backend
.venv\Scripts\python.exe -m uvicorn app.main:app --reload   # sobe em http://localhost:8000
```
Abrir `http://localhost:8000/docs` (Swagger) e `GET /health` → **backend OK**.

### Passo 7 — Validar o frontend
```bash
cd frontend
npm run dev          # sobe em http://localhost:5173
```
Se a página abrir e conseguir falar com a API, **ambiente pronto**. (Checklist na seção 9.)

### Passo 8 (opcional) — Seed de dados de dev
```bash
& backend\.venv\Scripts\python.exe backend\scripts\seed.py   # popula exemplos no SEU namespace
```

---

## 4. Reprodutibilidade de dependências

- **Backend:** `backend/requirements.txt` com **versões fixas** (ex.: `fastapi==0.x.y`), não faixas. Ao adicionar dep: instale, **fixe a versão** e **commite** no mesmo PR; avise o time para reinstalar.
- **Frontend:** **commitar o `frontend/package-lock.json`** — é ele que garante que todos instalem as mesmas versões. Use `npm ci` em CI/ambientes limpos.
- (Opcional) `uv` no backend para resolver/instalar mais rápido.

---

## 5. GCP compartilhado (modelo de acesso)

Como o projeto roda na **conta pessoal do dono** (não corporativo):

- **Um único `GCP_PROJECT_ID`** (`clai-2026-500018`) para todo o time (dataset BigQuery `clai`, bucket `clai-dev`, Firestore, Vertex).
- **Cada dev** acessa com a **própria conta Google** via ADC (passo 5); o dono concede papéis IAM mínimos a cada e-mail (BigQuery Data Editor, Storage Object Admin, Firestore User, Vertex AI User).
- **Gemini:** definir **um** caminho no time e documentar no `.env.example`:
  - **(a) API do Gemini** (`google-genai` + `GEMINI_API_KEY`) — chave única do dono, mais simples; **ou**
  - **(b) Vertex AI** (mesmo SDK, auth por ADC) — sem API key.

> ⚠️ **Free tier compartilhado:** com várias pessoas no mesmo projeto, **a quota gratuita é somada entre todos**. Reforça os guardrails da seção 9 do `ESPECIFICACAO_FINAL_MVP.md` (budget alert, endpoint Vertex desligado quando ocioso, modelos `flash`/`flash-lite`).

---

## 6. Trabalho simultâneo sem pisar no pé do outro

### 6.1 Código (Git)
- Branch por feature: `feat/<modulo>-<descricao>` (ex.: `feat/planejamento-correlacao`).
- `main` sempre estável; merge via Pull Request + revisão.
- **Divisão por módulo** (ver spec): Planejamento / Abertura / Campo / Fechamento / FUP — cada um é um router no backend + páginas no frontend, o que reduz conflito.

### 6.2 Dados de dev (GCP compartilhado)
Para não misturar dados de teste, usar **namespace por pessoa** via `DEV_NAMESPACE`:
- BigQuery: dataset/sufixo por dev (ex.: `clai_dev_vitor`) ou coluna `namespace`.
- Firestore: prefixo de coleção (ex.: `vitor__trabalhos`).
- Cloud Storage: prefixo de caminho (ex.: `dev/<DEV_NAMESPACE>/...`).
- O backend **lê `DEV_NAMESPACE` do `.env`** e aplica nos clients GCP automaticamente.

---

## 7. Convenções de código (uniformidade)

| Item | Padrão |
|------|--------|
| Lint/format backend | **ruff** (`ruff check` + `ruff format`) — rodar antes do commit |
| Lint/format frontend | **ESLint + Prettier** (config no `frontend/`) |
| Estilo | snake_case em Python; camelCase/PascalGase em TS/React |
| Tipos | type hints + Pydantic (backend); TypeScript estrito (frontend) |
| Idioma | código/identificadores em inglês; textos de UI em pt-BR |
| Commits | mensagens curtas e descritivas; 1 assunto por PR |

> (Opcional) **pre-commit** para rodar ruff/eslint automaticamente.

---

## 8. Arquivos-base que precisam existir no repo

| Arquivo | Papel |
|---------|-------|
| `backend/requirements.txt` | dependências Python fixadas |
| `backend/app/main.py` | app FastAPI (CORS + routers + `/health`) |
| `frontend/package.json` + `package-lock.json` | dependências do frontend (lock commitado) |
| `.env.example` | chaves de config do backend (sem segredos) |
| `frontend/.env.example` | `VITE_API_BASE_URL` etc. |
| `.gitignore` | itens da seção 2 |
| `scripts/setup.ps1` / `scripts/setup.sh` | bootstrap em **um comando** (passos 2–7) |
| `scripts/vector_search.py` | `start`/`stop` do índice Vertex (guardrail de custo) |
| `backend/scripts/seed.py` | dados de exemplo no namespace do dev |
| `CLAUDE.md` | instruções do projeto carregadas pela IA |

---

## 9. Checklist "ambiente pronto" (Definition of Ready)

- [ ] `python --version` → 3.11.x e `node --version` → LTS
- [ ] `backend/.venv` criado e `requirements.txt` instalado sem erro
- [ ] `frontend/node_modules` instalado (`npm install`)
- [ ] `.env` (backend) e `frontend/.env` preenchidos
- [ ] `gcloud auth application-default login` feito e `project` setado
- [ ] Backend sobe (`uvicorn`) e `GET /health` responde em `localhost:8000`
- [ ] Frontend sobe (`npm run dev`) em `localhost:5173` e fala com a API
- [ ] Acesso ao GCP validado (consegue listar o dataset/bucket)
- [ ] `ruff` (backend) e `eslint` (frontend) rodando

Quando tudo estiver ✅, o ambiente está **idêntico ao do time**.

---

## 10. Troubleshooting comum

| Sintoma | Causa provável | Solução |
|---------|----------------|---------|
| `activate` não persiste no terminal/agente | shell não mantém estado | chamar `backend\.venv\Scripts\python.exe` direto |
| Erro de parser no PowerShell ao chamar exe entre aspas | falta o operador `&` | `& "backend\.venv\Scripts\python.exe" ...` |
| Frontend não acessa a API (CORS) | origem não liberada | conferir `CORS_ORIGINS` no `.env` e `VITE_API_BASE_URL` |
| Versões divergentes (frontend) | instalou sem lock | usar `npm ci` e commitar `package-lock.json` |
| `PermissionDenied` no GCP | IAM não concedido | dono adiciona o e-mail aos papéis (seção 5) |
| Custo subindo | endpoint Vertex ligado | `scripts/vector_search.py stop` |
| Dados de dev misturados | sem namespace | preencher `DEV_NAMESPACE` no `.env` |
