# CLAI 2026 — Instruções do projeto

Plataforma de auditoria interna assistida por IA. **Frontend React (Vite + TS) + Backend FastAPI (Python)** sobre **Google Cloud Platform**. Projeto pessoal / MVP — prioridade de custo: **não estourar o free tier**.

## Documentos de referência (ler antes de codar)
- `Especificações do projeto/ESPECIFICACAO_FINAL_MVP.md` — escopo, arquitetura, dados, fluxos e guardrails (fonte da verdade).
- `Especificações do projeto/SETUP_AMBIENTE_PADRONIZADO.md` — bootstrap do ambiente (rodar primeiro).

## Stack
- **Frontend:** React 18 + Vite + TypeScript (pasta `frontend/`). Consome a API via REST (`VITE_API_BASE_URL`).
- **Backend:** FastAPI + Python 3.11 + `uvicorn` (pasta `backend/`). Lógica na camada de serviços.
- **IA:** Gemini via `google-genai` (modelos `gemini-2.5-flash` / `gemini-2.5-flash-lite`; sem `pro`).
- **Dados operacionais:** Firestore. **Acervo analítico:** BigQuery. **Arquivos:** Cloud Storage.
- **Busca de acervo:** Vertex AI Vector Search (endpoint com on/off — desligar quando ocioso).
- **RAG do chat por TA:** Gemini File API (sem vector store).

## Ambiente
- **Backend:** Python **3.11.x**, venv em `backend/.venv`. Chamar sempre `.venv\Scripts\python.exe` (Windows) — não depender de `activate`. Deps FIXAS em `backend/requirements.txt`.
- **Frontend:** Node LTS + npm. Deps fixadas em `frontend/package-lock.json`.
- No PowerShell, chamar exe entre aspas com o operador `&`: `& ".\.venv\Scripts\python.exe" ...`.
- Config em `.env` (gitignored), template em `.env.example`. Frontend usa `frontend/.env` com `VITE_*`.
- Setup: `scripts\setup.ps1` (Windows) / `scripts/setup.sh` (mac/linux).

## Comandos
- Backend (API): `cd backend; .venv\Scripts\python.exe -m uvicorn app.main:app --reload`
- Frontend: `cd frontend; npm run dev`
- Lint/format (backend): `.venv\Scripts\python.exe -m ruff check .` / `ruff format .`
- Vector Search on/off: `python scripts\vector_search.py start|stop`

## Convenções
- Código e identificadores em **inglês**; textos de UI em **pt-BR**.
- **Backend** por módulo (ver spec): `api/v1/endpoints/`, `services/`, `repositories/`, `models/`, `core/`.
- **Frontend** por módulo: `pages/`, `components/`, `api/`, `hooks/`, `types/`.
- Saídas de IA que viram dado → validar com Pydantic (backend).
- Dados de dev isolados por `DEV_NAMESPACE` (prefixo em BigQuery/Firestore/Storage).

## Guardrails de custo (free tier)
- **Endpoint Vertex Vector Search desligado quando não estiver em uso** (`scripts/vector_search.py stop`).
- `gemini-2.5-flash` como padrão; `gemini-2.5-flash-lite` em tarefas leves/alto volume; sem `pro`.
- BigQuery: sem `SELECT *`; ficar < 1TB de consulta/mês.
- Manter **budget alert** ativo no Cloud Billing.
- `.env` e chaves de Service Account **nunca** no Git.

## Trabalho simultâneo
- Branch por feature: `feat/<modulo>-<descricao>`. `main` estável; merge via PR.
- Mesmo `GCP_PROJECT_ID` para todos; cada dev autentica com a própria conta (ADC) e usa seu `DEV_NAMESPACE`.
