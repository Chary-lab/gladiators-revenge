# desplegar.ps1
# Despliega el servidor de salas en Fly.io y deja la URL lista para la web.
# Requiere flyctl autenticado:  iwr https://fly.io/install.ps1 -useb | iex ; fly auth login
# Uso:  .\desplegar.ps1 [-App nombre] [-Region mad] [-Salas 2]

param(
    [string]$App = "",
    [string]$Region = "gru",
    [int]$Salas = 2
)

# flyctl escribe avisos por stderr; con "Stop" PowerShell los toma como error
# fatal. Se controla cada paso con $LASTEXITCODE.
$ErrorActionPreference = "Continue"

# --- flyctl: PATH o la instalación del usuario ---
$fly = (Get-Command fly -ErrorAction SilentlyContinue).Source
if (-not $fly) {
    $candidato = Join-Path $env:USERPROFILE ".fly\bin\flyctl.exe"
    if (Test-Path $candidato) { $fly = $candidato }
}
if (-not $fly) {
    Write-Host "Falta flyctl. Instalalo con:" -ForegroundColor Yellow
    Write-Host "  iwr https://fly.io/install.ps1 -useb | iex" -ForegroundColor White
    exit 1
}

$sesion = & $fly auth whoami 2>$null
if (-not $sesion) {
    Write-Host "flyctl no esta autenticado. Corre: fly auth login" -ForegroundColor Yellow
    exit 1
}
Write-Host "Fly: $sesion" -ForegroundColor Gray

# --- Nombre de la app: el de fly.toml si no se pasa uno ---
$raiz = $PSScriptRoot
$flyToml = Join-Path $raiz "fly.toml"
if (-not $App) {
    $App = (Select-String -Path $flyToml -Pattern '^app\s*=\s*"([^"]+)"').Matches[0].Groups[1].Value
}

# --- Clave de servicio de Supabase (nunca se escribe en el repo) ---
$clave = $env:SUPABASE_SERVICE_KEY
if (-not $clave) {
    $archivo = Join-Path $env:APPDATA "Godot\app_userdata\Gladiators Revenge\supabase.local.cfg"
    if (Test-Path $archivo) {
        $clave = (Get-Content $archivo -Raw).Trim()
        Write-Host "Clave de servicio: $archivo" -ForegroundColor Gray
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

# --- Crear la app (si el nombre ya está tomado, se prueba con sufijo) ---
$creada = $false
for ($intento = 0; $intento -lt 2; $intento++) {
    $salida = (& $fly apps create $App 2>&1 | Out-String)
    $codigo = $LASTEXITCODE
    if ($codigo -eq 0 -or $salida -match "already exists|already been taken|Name has already been taken") {
        $creada = $true
        break
    }
    if ($intento -eq 0) {
        $sufijo = -join ((97..122) | Get-Random -Count 4 | ForEach-Object { [char]$_ })
        $App = "$App-$sufijo"
        Write-Host "Ese nombre estaba tomado; uso $App" -ForegroundColor Yellow
        (Get-Content $flyToml -Raw) -replace '^app\s*=\s*"[^"]+"', "app = `"$App`"" |
            Set-Content $flyToml -NoNewline
    }
}
if (-not $creada) {
    Write-Host "No se pudo crear la app $App" -ForegroundColor Red
    Write-Host $salida
    exit 1
}

$url = "https://$App.fly.dev"
Write-Host "=== Gladiators Revenge · servidor de salas ===" -ForegroundColor Cyan
Write-Host "App: $App   Region: $Region   Salas: $Salas   URL: $url" -ForegroundColor Gray

# --- Secretos por archivo temporal (no quedan en el historial) ---
$temporal = New-TemporaryFile
try {
    # Sin BOM: fly rechaza el primer nombre si el archivo empieza con U+FEFF.
    $contenido = "SUPABASE_SERVICE_KEY=$clave`nSERVER_PUBLIC_URL=$url`nSALAS=$Salas`nSUPABASE_REGION=gru`n"
    [IO.File]::WriteAllText($temporal, $contenido, (New-Object System.Text.UTF8Encoding($false)))
    # Se pasan por stdin con "type" para no dejar la clave en el historial ni
    # en la línea de comandos.
    & cmd /c "type `"$temporal`" | `"$fly`" secrets import --app $App" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "No se pudieron cargar los secretos (codigo $LASTEXITCODE)." -ForegroundColor Red
        exit 1
    }
} finally {
    Remove-Item $temporal -Force -ErrorAction SilentlyContinue
}

Write-Host "Desplegando en $Region (la primera vez tarda varios minutos)…" -ForegroundColor Cyan
& $fly deploy --app $App

Write-Host ""
Write-Host "Comprobando el servicio…" -ForegroundColor Cyan
Start-Sleep -Seconds 10
foreach ($intento in 1..10) {
    try {
        $salud = Invoke-RestMethod "$url/salud" -TimeoutSec 30
        Write-Host "  /salud -> $($salud | ConvertTo-Json -Compress)" -ForegroundColor Green
        $sala = Invoke-RestMethod -Method Post "$url/salas" -TimeoutSec 30
        Write-Host "  /salas -> $($sala | ConvertTo-Json -Compress)" -ForegroundColor Green
        break
    } catch {
        if ($intento -eq 10) {
            Write-Host "  No responde todavia: $($_.Exception.Message)" -ForegroundColor Yellow
        } else {
            Start-Sleep -Seconds 6
        }
    }
}

Write-Host ""
Write-Host "Listo. La web puede crear salas con:" -ForegroundColor Yellow
Write-Host "  https://chary-lab.github.io/gladiators-revenge/?api=$url" -ForegroundColor White
Write-Host "APP_URL=$url" -ForegroundColor White
