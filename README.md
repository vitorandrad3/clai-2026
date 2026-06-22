# CLAI 2026

Plataforma de **auditoria interna assistida por IA**. Frontend em **React (Vite + TypeScript)** e backend em **FastAPI (Python)**, sobre **Google Cloud Platform** (Gemini, BigQuery, Firestore, Cloud Storage, Vertex AI Vector Search).

> Projeto pessoal / MVP. Prioridade de custo: **não estourar o free tier**.

## Documentação

- [`Especificações do projeto/ESPECIFICACAO_FINAL_MVP.md`](Especificações%20do%20projeto/ESPECIFICACAO_FINAL_MVP.md) — escopo, arquitetura, dados, fluxos e guardrails (fonte da verdade).
- [`Especificações do projeto/SETUP_AMBIENTE_PADRONIZADO.md`](Especificações%20do%20projeto/SETUP_AMBIENTE_PADRONIZADO.md) — bootstrap do ambiente.
- [`CLAUDE.md`](CLAUDE.md) — instruções do projeto para a IA.

## Módulos

| Módulo | O que faz |
|--------|-----------|
| **Planejamento** | Correlaciona notícias (RSS) e incidentes internos com os riscos corporativos |
| **Execução — Abertura** | Carrega contexto do trabalho e gera matriz de risco |
| **Execução — Campo** | Upload de evidências por teste (TA) + chat com agente do TA |
| **Execução — Fechamento** | Lê todos os TAs e gera relatório |
| **FUP** | Pontos de auditoria, planos de ação e análise de eficiência por IA |

## Estrutura

```
backend/    # FastAPI (Python 3.11)
frontend/   # React + Vite + TypeScript
scripts/    # utilitários (ex.: vector_search start|stop)
```

## Como rodar (dev)

Pré-requisitos: Python 3.11.x, Node LTS, gcloud CLI. Detalhes no SETUP.

```bash
# bootstrap em um comando
./scripts/setup.sh                 # Windows: .\scripts\setup.ps1

# backend (http://localhost:8000 — Swagger em /docs)
cd backend && ./.venv/bin/python -m uvicorn app.main:app --reload

# frontend (http://localhost:5173)
cd frontend && npm run dev
```

## Configuração

Copie `.env.example` → `.env` (backend) e `frontend/.env.example` → `frontend/.env`. Nunca versione `.env` nem chaves de Service Account.

## Trabalho simultâneo

Branch por feature (`feat/<modulo>-<descricao>`), `main` estável via PR. Mesmo `GCP_PROJECT_ID` para todos; cada dev autentica com a própria conta (ADC) e usa seu `DEV_NAMESPACE`.
