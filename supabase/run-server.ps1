param([int]$Puerto = 9080)

$ErrorActionPreference = "Stop"
$raiz = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $PSScriptRoot ".env"

if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            Set-Item -Path ("Env:" + $matches[1].Trim()) -Value $matches[2].Trim()
        }
    }
}

if (-not $env:SERVER_PUBLIC_URL) {
    Write-Output "Aviso: SERVER_PUBLIC_URL vacío; el servidor no se anunciará en Supabase."
}

& godot --headless --path $raiz -- --servidor --puerto=$Puerto
