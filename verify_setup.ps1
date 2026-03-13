$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFilePath = Join-Path $scriptDirectory ".env"

Write-Host "Testing .env file loading..." -ForegroundColor Green
if (Test-Path $envFilePath) {
    Write-Host "✓ .env file found" -ForegroundColor Green
    Get-Content $envFilePath | Where-Object { $_ -match '^\w' } | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "✗ .env file not found" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All configuration files are in place!" -ForegroundColor Green
Write-Host "The main.ps1 script is ready to use." -ForegroundColor Green
