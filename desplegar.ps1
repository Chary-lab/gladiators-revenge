# desplegar.ps1
# Despliega el servidor de salas en Fly.io y deja la URL para la web.
# Requiere flyctl autenticado:  iwr https://fly.io/install.ps1 -useb | iex ; fly auth login
# Uso:  .\desplegar.ps1 [-App gladiators-revenge-server] [-Region mad] [-Salas 2]

param(
    [string]$App = "gladiators-revenge-server",
    [string]$Region = "mad",
    [int]$Salas = 2
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command fly -ErrorAction SilentlyContinue)) {
    Write-Host "Falta flyctl. Instalalo con:" -ForegroundColor Yellow
    Write-Host "  iwr https://fly.io/install.ps1 -useb | iex" -ForegroundColor White
    Write-Host "Despues cerra y abri la terminal, y corre 'fly auth login'." -ForegroundColor Yellow
    exit 1
}

$sesion = fly auth whoami 2>$null
if (-not $sesion) {
    Write-Host "flyctl no esta autenticado. Corre: fly auth login" -ForegroundColor Yellow
    exit 1
}

# --- Clave de servicio de Supabase (nunca se escribe en el repo) ---
$clave = $env:SUPABASE_SERVICE_KEY
if (-not $clave) {
    $archivo = Join-Path $env:APPDATA "Godot\app_userdata\Gladiators Revenge\supabase.local.cfg"
    if (Test-Path $archivo) {
        $clave = (Get-Content $archivo -Raw).Trim()
        Write-Host "Usando la clave de $archivo" -ForegroundColor Gray
    }
}
if (-not $clave) {
    $seguro = Read-Host "Pega la SUPABASE_SERVICE_KEY (no se muestra)" -AsSecureString
    $clave = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro)
    )
}
if (-not $clave) {
    Write-Host "Sin clave de servicio no se puede desplegar." -ForegroundColor Red
    exit 1
}

$url = "https://$App.fly.dev"

Write-Host "=== Gladiators Revenge · servidor de salas ===" -ForegroundColor Cyan
Write-Host "App: $App   Region: $Region   Salas: $Salas" -ForegroundColor Gray

# --- App (se ignora si ya existe) ---
fly apps create $App 2>$null | Out-Null

# --- Secretos: se pasan por archivo temporal para no dejarlos en el historial ---
$temporal = New-TemporaryFile
try {
    "SUPABASE_SERVICE_KEY=$clave`nSERVER_PUBLIC_URL=$url`nSALAS=$Salas" | Set-Content $temporal -Encoding ascii
    Get-Content $temporal | fly secrets import --app $App
} finally {
    Remove-Item $temporal -Force -ErrorAction SilentlyContinue
}

Write-Host "Desplegando…" -ForegroundColor Cyan
fly deploy --app $App --region $Region

Write-Host ""
Write-Host "Comprobando el servicio…" -ForegroundColor Cyan
try {
    $salud = Invoke-RestMethod "$url/salud" -TimeoutSec 60
    Write-Host "  /salud -> $($salud | ConvertTo-Json -Compress)" -ForegroundColor Green
    $sala = Invoke-RestMethod -Method Post "$url/salas" -TimeoutSec 30
    Write-Host "  /salas -> $($sala | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch {
    Write-Host "  Todavia no responde (puede tardar en arrancar): $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Listo. Para que la web cree salas, abrila con:" -ForegroundColor Yellow
Write-Host "  https://chary-lab.github.io/gladiators-revenge/?api=$url" -ForegroundColor White
Write-Host "O fija la URL en project.godot ([red] api_url=...) y hace push." -ForegroundColor Gray
