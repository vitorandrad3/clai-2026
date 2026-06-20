#!/usr/bin/env bash
# CLAI 2026 — bootstrap do ambiente (macOS / Linux)
# Uso (na raiz do repo):  bash scripts/setup.sh
# Idempotente: pode rodar várias vezes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PY="$ROOT/.venv/bin/python"

echo "==> [1/5] Verificando Python 3.11..."
if ! python3.11 --version >/dev/null 2>&1; then
  echo "AVISO: python3.11 nao encontrado. Instale Python 3.11.x." >&2
fi

echo "==> [2/5] Criando virtualenv (.venv)..."
[ -d .venv ] || python3.11 -m venv .venv

echo "==> [3/5] Instalando dependencias..."
"$PY" -m pip install --upgrade pip --quiet
"$PY" -m pip install -r requirements.txt

echo "==> [4/5] Verificando .env..."
if [ ! -f .env ]; then
  cp .env.example .env
  echo "AVISO: .env criado a partir do template. Preencha GCP_PROJECT_ID e DEV_NAMESPACE."
else
  echo "    .env ja existe (ok)."
fi

echo "==> [5/5] Inicializando Reflex (idempotente)..."
"$PY" -m reflex init

echo ""
echo "Ambiente pronto. Para subir a app:"
echo "    ./.venv/bin/python -m reflex run"
