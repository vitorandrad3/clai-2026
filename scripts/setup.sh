#!/usr/bin/env bash
# CLAI 2026 — bootstrap do ambiente (macOS / Linux)
# Uso (na raiz do repo):  bash scripts/setup.sh
# Idempotente: pode rodar várias vezes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PY="$ROOT/backend/.venv/bin/python"

echo "==> [1/6] Verificando Python 3.11 e Node..."
python3.11 --version >/dev/null 2>&1 || echo "AVISO: python3.11 nao encontrado." >&2
node --version >/dev/null 2>&1 || echo "AVISO: Node.js (LTS) nao encontrado — necessario para o frontend." >&2

echo "==> [2/6] Backend: virtualenv (backend/.venv)..."
[ -d backend/.venv ] || python3.11 -m venv backend/.venv

echo "==> [3/6] Backend: instalando dependencias..."
"$PY" -m pip install --upgrade pip --quiet
"$PY" -m pip install -r backend/requirements.txt

echo "==> [4/6] Frontend: instalando dependencias (npm)..."
if [ -f frontend/package.json ]; then
  (cd frontend && npm install)
else
  echo "AVISO: frontend/package.json ainda nao existe — pule ate o frontend ser criado." >&2
fi

echo "==> [5/6] Verificando .env..."
[ -f .env ] || { cp .env.example .env; echo "AVISO: .env criado. Preencha GCP_PROJECT_ID e DEV_NAMESPACE."; }
if [ -f frontend/.env.example ] && [ ! -f frontend/.env ]; then cp frontend/.env.example frontend/.env; echo "    frontend/.env criado."; fi

echo "==> [6/6] Setup concluido."
echo ""
echo "Subir o backend:  cd backend && ./.venv/bin/python -m uvicorn app.main:app --reload"
echo "Subir o frontend: cd frontend && npm run dev"
