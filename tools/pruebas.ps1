<#
.SYNOPSIS
    Ejecuta la batería de pruebas de Gladiators Revenge en paralelo.

.DESCRIPTION
    Cada suite (smoke, regression, wave) corre en su propio proceso Godot y en
    paralelo, con APPDATA/HOME/TEMP aislados para que no compitan por user://
    (ajustes.cfg, perfil.cfg) ni por la caché de recursos. El import de assets se
    hace una sola vez, en serie, antes de lanzar los workers.

    La suite "red" es orquestación (servidor + cliente A + cliente B), así que se
    ejecuta en secuencia con su propio arranque y limpieza.

.EXAMPLE
    ./tools/pruebas.ps1
    Corre smoke + regression + wave en paralelo.

.EXAMPLE
    ./tools/pruebas.ps1 -Suite smoke
    Solo el smoke crítico (≈2 s), para el bucle de desarrollo.

.EXAMPLE
    ./tools/pruebas.ps1 -Suite red
    Levanta servidor + cliente A + cliente B y valida el cooperativo.
#>
param(
    [ValidateSet("smoke", "regression", "wave", "red", "all")]
    [string]$Suite = "all",
    [ValidateRange(1, 16)]
    [int]$Workers = 3,
    [string]$Godot = "",
    [int]$TimeoutSeg = 240,
    [switch]$Secuencial,
    [switch]$SinImport
)

$ErrorActionPreference = "Stop"
# Salida UTF-8: el runner imprime acentos, ñ y "·".
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$raiz = Split-Path -Parent $PSScriptRoot
Push-Location $raiz

function Resolver-Godot {
    if ($Godot) { return $Godot }
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $winget = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\godot.exe"
    if (Test-Path $winget) { return $winget }
    throw "No encuentro el binario de Godot. Pásalo con -Godot <ruta>."
}

function Nueva-Salida([string]$nombre) {
    $dir = Join-Path $env:TEMP ("gladiadores-pruebas\" + $nombre + "-" + [guid]::NewGuid().ToString("N").Substring(0, 6))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    return $dir
}

function Puerto-Libre {
    $oyente = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $oyente.Start()
    $puerto = $oyente.LocalEndpoint.Port
    $oyente.Stop()
    return $puerto
}

function Esperar-Puerto([int]$puerto, [int]$intentos = 200) {
    for ($i = 0; $i -lt $intentos; $i++) {
        try {
            $cliente = [System.Net.Sockets.TcpClient]::new()
            $cliente.Connect("127.0.0.1", $puerto)
            $cliente.Close()
            return $true
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }
    return $false
}

# Bloque que corre cada worker: proceso Godot aislado con su propio user://
$bloqueSuite = {
    param($nombre, $script, $argsExtra, $salida, $exe, $raiz)
    $env:APPDATA = $salida
    $env:HOME = $salida
    $env:TEMP = $salida
    $env:TMP = $salida
    $crono = [System.Diagnostics.Stopwatch]::StartNew()
    $lineas = & $exe --headless --path $raiz --script $script @argsExtra 2>&1 | ForEach-Object { "$_" }
    $codigo = $LASTEXITCODE
    $crono.Stop()
    [pscustomobject]@{
        nombre  = $nombre
        codigo  = $codigo
        ms      = $crono.ElapsedMilliseconds
        ok      = @($lineas | Where-Object { $_ -match "^\s+OK\s" }).Count
        fallos  = @($lineas | Where-Object { $_ -cmatch "^\s+FALLO\s|SCRIPT ERROR|Parse Error|ERROR: " })
        resumen = @($lineas | Where-Object { $_ -match "^== " }) | Select-Object -Last 1
    }
}

# Arranca un proceso Godot con stdout/stderr capturados y su exit code fiable.
# (Start-Process -PassThru deja Process.ExitCode vacío en PowerShell 5.1.)
function Iniciar-Godot([string]$exe, [string]$argumentos) {
    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $exe
    $info.Arguments = $argumentos
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $proceso = [System.Diagnostics.Process]::new()
    $proceso.StartInfo = $info
    $proceso.Start() | Out-Null
    [pscustomobject]@{
        proceso = $proceso
        salida  = $proceso.StandardOutput.ReadToEndAsync()
        errores = $proceso.StandardError.ReadToEndAsync()
    }
}

# Suite de red: servidor + cliente A + cliente B (B necesita a A conectado)
function Invoke-Red {
    param($exe, $raiz, $timeout)
    $puerto = Puerto-Libre
    $dir = Nueva-Salida "red"
    $servidor = $null
    $resultados = @()
    try {
        $servidor = Iniciar-Godot $exe "--headless --path `"$raiz`" -- --servidor --puerto=$puerto --red-rapida"
        if (-not (Esperar-Puerto $puerto)) { throw "el servidor no abrió el puerto $puerto" }

        # A se queda 40 s vivo: B necesita un compañero para probar el revivir.
        $clienteA = Iniciar-Godot $exe "--headless --path `"$raiz`" --script res://tests/net_smoke.gd -- --cliente=ws://127.0.0.1:$puerto --esperar=40"
        Start-Sleep -Seconds 5
        $clienteB = Iniciar-Godot $exe "--headless --path `"$raiz`" --script res://tests/net_smoke_b.gd -- --cliente=ws://127.0.0.1:$puerto"

        $limite = [int]$timeout * 1000
        foreach ($cli in @($clienteB, $clienteA)) {
            if (-not $cli.proceso.WaitForExit($limite)) { $cli.proceso.Kill() }
        }

        $etiquetas = @("red A", "red B")
        $indice = 0
        foreach ($cli in @($clienteA, $clienteB)) {
            # printerr() de Godot va a stderr: se leen las dos salidas.
            $lineas = @((($cli.salida.Result) + "`n" + ($cli.errores.Result)) -split "`r?`n")
            $resultados += [pscustomobject]@{
                nombre  = $etiquetas[$indice]
                codigo  = $cli.proceso.ExitCode
                ms      = 0
                ok      = @($lineas | Where-Object { $_ -match "^\s+OK\s" }).Count
                fallos  = @($lineas | Where-Object { $_ -cmatch "^\s+FALLO\s|SCRIPT ERROR|Parse Error" })
                resumen = @($lineas | Where-Object { $_ -match "^== " }) | Select-Object -Last 1
            }
            $indice += 1
        }
    }
    finally {
        if ($servidor -and -not $servidor.proceso.HasExited) { $servidor.proceso.Kill() }
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }
    return $resultados
}

$exe = Resolver-Godot
$suites = [ordered]@{
    smoke      = @{ script = "res://tests/smoke_test.gd"; args = @() }
    regression = @{ script = "res://tests/regression_test.gd"; args = @() }
    wave       = @{ script = "res://tests/wave_sim.gd"; args = @() }
}
$objetivos = if ($Suite -eq "all") { @("smoke", "regression", "wave") } else { @($Suite) }

# El import se hace una vez: dos workers importando a la vez compiten por .godot/
if (-not $SinImport) {
    Write-Host "· Importando assets (--editor --quit)..." -ForegroundColor DarkGray
    & $exe --headless --path $raiz --editor --quit *> $null
}

Write-Host ("· Godot: {0}" -f $exe)
Write-Host ("· Suites: {0} · workers: {1}" -f ($objetivos -join ", "), $Workers) -ForegroundColor Cyan
$inicio = Get-Date
$resultados = @()

if ($Suite -eq "red") {
    $resultados += Invoke-Red -exe $exe -raiz $raiz -timeout $TimeoutSeg
}
elseif ($Secuencial) {
    foreach ($nombre in $objetivos) {
        $def = $suites[$nombre]
        $dir = Nueva-Salida $nombre
        $resultados += & $bloqueSuite $nombre $def.script $def.args $dir $exe $raiz
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }
}
else {
    # Pool de workers: nunca hay más de $Workers procesos Godot a la vez.
    $cola = [System.Collections.Queue]::new()
    foreach ($nombre in $objetivos) { $cola.Enqueue($nombre) }
    $activos = @()
    $limite = (Get-Date).AddSeconds($TimeoutSeg)

    while ($cola.Count -gt 0 -or $activos.Count -gt 0) {
        while ($activos.Count -lt $Workers -and $cola.Count -gt 0) {
            $nombre = $cola.Dequeue()
            $def = $suites[$nombre]
            $dir = Nueva-Salida $nombre
            $activos += Start-Job -Name $nombre -ArgumentList $nombre, $def.script, $def.args, $dir, $exe, $raiz `
                -ScriptBlock $bloqueSuite
        }

        $siguen = @()
        foreach ($t in $activos) {
            if ($t.State -in @("Completed", "Failed", "Stopped")) {
                $r = Receive-Job -Job $t
                if ($r) { $resultados += $r } else {
                    $resultados += [pscustomobject]@{
                        nombre = $t.Name; codigo = 1; ms = 0; ok = 0
                        fallos = @("el job no devolvió resultados"); resumen = "SIN SALIDA"
                    }
                }
                Remove-Job -Job $t -Force
            }
            else { $siguen += $t }
        }
        $activos = $siguen

        if ($activos.Count -gt 0) {
            if ((Get-Date) -gt $limite) {
                foreach ($t in $activos) {
                    Stop-Job -Job $t
                    $resultados += [pscustomobject]@{
                        nombre = $t.Name; codigo = 124; ms = $TimeoutSeg * 1000; ok = 0
                        fallos = @("tiempo agotado tras ${TimeoutSeg}s"); resumen = "TIMEOUT"
                    }
                    Remove-Job -Job $t -Force
                }
                $activos = @()
                $cola.Clear()
            }
            else { Start-Sleep -Milliseconds 150 }
        }
    }
    Get-ChildItem (Join-Path $env:TEMP "gladiadores-pruebas") -Directory -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

$total = [int]((Get-Date) - $inicio).TotalMilliseconds
Write-Host ""
"{0,-12} {1,-7} {2,4} {3,7} {4,8}  {5}" -f "SUITE", "ESTADO", "OK", "FALLOS", "TIEMPO", "RESUMEN" | Write-Host
foreach ($r in ($resultados | Sort-Object nombre)) {
    $estado = if ($r.codigo -eq 0 -and $r.fallos.Count -eq 0) { "PASA" } else { "FALLA" }
    $color = if ($estado -eq "PASA") { "Green" } else { "Red" }
    "{0,-12} {1,-7} {2,4} {3,7} {4,7}ms  {5}" -f $r.nombre, $estado, $r.ok, $r.fallos.Count, $r.ms, $r.resumen |
        Write-Host -ForegroundColor $color
    foreach ($f in $r.fallos) { Write-Host ("    " + $f.Trim()) -ForegroundColor Red }
}
Write-Host ("· pared: {0} ms · {1} núcleos · workers: {2}" -f $total, [Environment]::ProcessorCount, $Workers) -ForegroundColor Cyan

$fallidos = @($resultados | Where-Object { $_.codigo -ne 0 -or $_.fallos.Count -gt 0 }).Count
Pop-Location
if ($fallidos -gt 0) { exit 1 } else { exit 0 }
