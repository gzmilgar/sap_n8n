<#
.SYNOPSIS
    Starts the whole demo: n8n in one window, CAP in another.

.DESCRIPTION
    Adds the portable Node 22 folder to PATH for this session and for the two
    child windows, then launches n8n and `cds watch` side by side.
    No admin rights and no Docker required.

.EXAMPLE
    .\start-demo.ps1

.EXAMPLE
    .\start-demo.ps1 -NodeHome "D:\tools\node22" -SkipN8n
#>
[CmdletBinding()]
param(
    [string] $NodeHome   = "$env:USERPROFILE\node22",
    [string] $ProjectDir = (Split-Path -Parent $PSScriptRoot),
    [switch] $SkipN8n,
    [switch] $SkipCap
)

$ErrorActionPreference = "Stop"

Write-Host "=== SAP CAP + n8n demo launcher ===" -ForegroundColor Cyan

# --- 1) Portable Node on PATH -------------------------------------------------
if (-not (Test-Path $NodeHome)) {
    Write-Host "Node folder not found: $NodeHome" -ForegroundColor Red
    Write-Host "Pass the right path, e.g.  .\start-demo.ps1 -NodeHome 'C:\tools\node22'" -ForegroundColor Yellow
    exit 1
}

$env:PATH = "$NodeHome;$NodeHome\node_modules\npm\bin;$env:PATH"
Write-Host "PATH  : $NodeHome" -ForegroundColor DarkGray
Write-Host "node  : $(& node --version)" -ForegroundColor DarkGray

$capDir = Join-Path $ProjectDir "order-demo"
if (-not (Test-Path (Join-Path $capDir "package.json"))) {
    Write-Host "CAP project not found at $capDir" -ForegroundColor Red
    exit 1
}

# --- 2) .env sanity check -----------------------------------------------------
$envFile = Join-Path $capDir ".env"
if (-not (Test-Path $envFile)) {
    Write-Host "No .env in $capDir - copying .env.example" -ForegroundColor Yellow
    Copy-Item (Join-Path $capDir ".env.example") $envFile
}

# --- 3) npm install once ------------------------------------------------------
if (-not (Test-Path (Join-Path $capDir "node_modules"))) {
    Write-Host "Installing CAP dependencies (one time)..." -ForegroundColor Yellow
    Push-Location $capDir
    & npm install --no-audit --no-fund
    Pop-Location
}

# Child windows inherit this session's PATH, so node22 is visible in both.
$pathForChildren = $env:PATH

# --- 4) n8n window ------------------------------------------------------------
if (-not $SkipN8n) {
    Write-Host "Starting n8n  -> http://localhost:5678" -ForegroundColor Green
    # The inner command uses only single quotes, so it survives being wrapped in
    # one double-quoted -Command argument. Passing -ArgumentList as an array here
    # would let Windows split the command on its spaces.
    $n8nCmd = "`$env:PATH='$pathForChildren'; `$host.UI.RawUI.WindowTitle='n8n :5678'; n8n"
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit -Command `"$n8nCmd`""
    # n8n needs a head start so the webhook is registered before CAP can call it.
    Start-Sleep -Seconds 8
}

# --- 5) CAP window ------------------------------------------------------------
if (-not $SkipCap) {
    Write-Host "Starting CAP  -> http://localhost:4004" -ForegroundColor Green
    $capCmd = "`$env:PATH='$pathForChildren'; `$host.UI.RawUI.WindowTitle='CAP :4004'; Set-Location '$capDir'; cds watch"
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit -Command `"$capCmd`""
    Start-Sleep -Seconds 6
}

Write-Host ""
Write-Host "Ready:" -ForegroundColor Cyan
Write-Host "  CAP service  : http://localhost:4004"
Write-Host "  Fiori preview: http://localhost:4004/`$fiori-preview/OrderService/Orders#preview-app"
Write-Host "  n8n editor   : http://localhost:5678"
Write-Host ""
Write-Host "Fire a test order:  .\create-order.ps1 -Amount 15000" -ForegroundColor Yellow
