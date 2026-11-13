# crear_sala.ps1
# Levanta automáticamente: Cloudflare Tunnel + servidor Godot headless.
# El host ejecuta este script; obtiene un enlace wss:// para compartir sin
# mostrar IP ni abrir puertos en el router.
# Uso: .\crear_sala.ps1
#      Luego compartes la URL que aparece en pantalla con tus amigos.
#      Al presionar cualquier tecla se cierra servidor y túnel.

$ErrorActionPreference = "Stop"

$puerto = 9080
$proyecto = "D:/Orc Gladiators"

# --- Buscar ejecutable de Godot ---
$godot = Get-Command "godot" -ErrorAction SilentlyContinue
if (-not $godot) {
    $candidato = "C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Links\godot.exe"
    if (Test-Path $candidato) {
        $godot = $candidato
    } else {
        Write-Host "ERROR: No se encontró el ejecutable de godot." -ForegroundColor Red
        Write-Host "Instalalo de https://godotengine.org/download o agregalo al PATH." -ForegroundColor Yellow
        exit 1
    }
} else {
    $godot = $godot.Source
}

# --- Verificar cloudflared (o usar el que ya descargó el juego) ---
$cloudflared = "cloudflared"
if (!(Get-Command "cloudflared" -ErrorAction SilentlyContinue)) {
    $descargado = "$env:APPDATA\Godot\app_userdata\Gladiators Revenge\bin\cloudflared.exe"
    if (Test-Path $descargado) {
        $cloudflared = $descargado
        Write-Host "Usando el cloudflared que descargó el juego." -ForegroundColor Gray
    } else {
        Write-Host "ERROR: cloudflared no está instalado." -ForegroundColor Red
        Write-Host "Abre el juego una vez y pulsa CREAR SALA (lo descarga solo)," -ForegroundColor Yellow
        Write-Host "o instalalo desde: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "=== GLADIATORS REVENGE — Crear sala pública ===" -ForegroundColor Cyan
Write-Host "Puerto local: $puerto" -ForegroundColor Gray
Write-Host ""

# --- Levantar túnel Cloudflare ---
Write-Host "Levantando túnel Cloudflare en puerto $puerto…" -ForegroundColor Cyan
$tunnel = Start-Process $cloudflared -ArgumentList @("tunnel","--url","http://localhost:$puerto") -PassThru -WindowStyle Hidden -RedirectStandardOutput "$PSScriptRoot/cloudflared.out" -RedirectStandardError "$PSScriptRoot/cloudflared.err"

# Esperar URL pública (máximo 30 segundos)
$url_publica = $null
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep 1
    if (Test-Path "$PSScriptRoot/cloudflared.out") {
        $contenido = Get-Content "$PSScriptRoot/cloudflared.out" -Raw -ErrorAction SilentlyContinue
        if ($contenido -match "https://([a-zA-Z0-9-]+\.trycloudflare\.com)") {
            $url_publica = "wss://$($matches[1])"
            Write-Host "Túnel listo: $url_publica" -ForegroundColor Green
            break
        }
    }
}

if (-not $url_publica) {
    Write-Host "No se pudo obtener la URL del túnel en 30 s." -ForegroundColor Red
    Get-Content "$PSScriptRoot/cloudflared.err" -ErrorAction SilentlyContinue
    Stop-Process -Id $tunnel.Id -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host ""
Write-Host "Compartí esta URL con tus amigos para que se unan:" -ForegroundColor Yellow
Write-Host ("  " + $url_publica) -ForegroundColor White
Write-Host ""
Write-Host "Presioná cualquier tecla para cerrar la sala, el servidor y el túnel…" -ForegroundColor Cyan

# --- Lanzar servidor Godot ---
$godotArgs = @("--headless","--path",$proyecto,"--","--servidor","--puerto=$puerto","--publico=$url_publica")
$godotProc = Start-Process $godot -ArgumentList $godotArgs -PassThru -WindowStyle Normal

# Esperar entrada del usuario
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# --- Cerrar todo ---
Write-Host ""
Write-Host "Cerrando servidor Godot y túnel Cloudflare…" -ForegroundColor Yellow
Stop-Process -Id $godotProc.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $tunnel.Id -Force -ErrorAction SilentlyContinue
Remove-Item "$PSScriptRoot/cloudflared.out" -ErrorAction SilentlyContinue
Remove-Item "$PSScriptRoot/cloudflared.err" -ErrorAction SilentlyContinue
Write-Host "Sala cerrada." -ForegroundColor Green
