# CLAI 2026 — bootstrap do ambiente (Windows / PowerShell)
# Uso (na raiz do repo):
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
#   .\scripts\setup.ps1
# Idempotente: pode rodar várias vezes.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$py = Join-Path $root ".venv\Scripts\python.exe"

Write-Host "==> [1/5] Verificando Python 3.11..." -ForegroundColor Cyan
$ver = (python --version) 2>&1
if ($ver -notmatch "3\.11") { Write-Warning "Python esperado 3.11.x, encontrado: $ver" }

Write-Host "==> [2/5] Criando virtualenv (.venv)..." -ForegroundColor Cyan
if (-not (Test-Path ".venv")) { python -m venv .venv }

Write-Host "==> [3/5] Instalando dependencias..." -ForegroundColor Cyan
& $py -m pip install --upgrade pip --quiet
& $py -m pip install -r requirements.txt

Write-Host "==> [4/5] Verificando .env..." -ForegroundColor Cyan
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Warning ".env criado a partir do template. Preencha GCP_PROJECT_ID e DEV_NAMESPACE."
} else {
    Write-Host "    .env ja existe (ok)."
}

Write-Host "==> [5/5] Inicializando Reflex (idempotente)..." -ForegroundColor Cyan
& $py -m reflex init

Write-Host ""
Write-Host "Ambiente pronto. Para subir a app:" -ForegroundColor Green
Write-Host "    .\.venv\Scripts\python.exe -m reflex run" -ForegroundColor Green
