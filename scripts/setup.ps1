# CLAI 2026 — bootstrap do ambiente (Windows / PowerShell)
# Uso (na raiz do repo):
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
#   .\scripts\setup.ps1
# Idempotente: pode rodar várias vezes.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$py = Join-Path $root "backend\.venv\Scripts\python.exe"

Write-Host "==> [1/6] Verificando Python 3.11 e Node..." -ForegroundColor Cyan
$ver = (python --version) 2>&1
if ($ver -notmatch "3\.11") { Write-Warning "Python esperado 3.11.x, encontrado: $ver" }
try { node --version | Out-Null } catch { Write-Warning "Node.js (LTS) nao encontrado — necessario para o frontend." }

Write-Host "==> [2/6] Backend: virtualenv (backend\.venv)..." -ForegroundColor Cyan
if (-not (Test-Path "backend\.venv")) { python -m venv backend\.venv }

Write-Host "==> [3/6] Backend: instalando dependencias..." -ForegroundColor Cyan
& $py -m pip install --upgrade pip --quiet
& $py -m pip install -r backend\requirements.txt

Write-Host "==> [4/6] Frontend: instalando dependencias (npm)..." -ForegroundColor Cyan
if (Test-Path "frontend\package.json") {
    Push-Location frontend; npm install; Pop-Location
} else {
    Write-Warning "frontend\package.json ainda nao existe — pule ate o frontend ser criado (npm create vite@latest frontend -- --template react-ts)."
}

Write-Host "==> [5/6] Verificando .env..." -ForegroundColor Cyan
if (-not (Test-Path ".env")) { Copy-Item ".env.example" ".env"; Write-Warning ".env criado. Preencha GCP_PROJECT_ID e DEV_NAMESPACE." } else { Write-Host "    .env ja existe (ok)." }
if ((Test-Path "frontend\.env.example") -and -not (Test-Path "frontend\.env")) { Copy-Item "frontend\.env.example" "frontend\.env"; Write-Host "    frontend\.env criado." }

Write-Host "==> [6/6] Setup concluido." -ForegroundColor Cyan
Write-Host ""
Write-Host "Subir o backend:  cd backend; .\.venv\Scripts\python.exe -m uvicorn app.main:app --reload" -ForegroundColor Green
Write-Host "Subir o frontend: cd frontend; npm run dev" -ForegroundColor Green
