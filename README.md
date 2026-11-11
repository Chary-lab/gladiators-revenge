# Gladiators Revenge

Arena de supervivencia con perspectiva isométrica 2.5D en **Godot 4.7**, pensada
para publicarse en **Web (HTML5 / WebAssembly)**. IP original: gladiadores orcos
de las Tierras Baldías se rebelan contra el Imperio Humano de Hierro.

## Estado

Prototipo jugable de principio a fin: 20 oleadas, tres clases de arma, armería,
jefes con furia, anti-camping, HUD y export web. El arte es procedural
(cápsulas, cajas y cilindros), sin assets de terceros.

## Ejecutar

```powershell
# Editor
godot --path .

# Partida directa
godot --path . scenes/main.tscn
```

Godot 4.7 se instaló con `winget install GodotEngine.GodotEngine`. Los scripts
también funcionan en 4.4+ salvo cambios menores de API.

## Controles

| Entrada | Acción |
| --- | --- |
| Click derecho | Mover al punto del cursor (NavigationAgent3D) |
| Q / W / E / R | Habilidad del slot del arma equipada |
| F | Comprar el arma del pedestal más cercano (3,5 m) |
| 1 / 2 / 3 | Gastar un punto en Fuerza / Agilidad / Inteligencia |
| Enter | Reiniciar tras victoria o derrota |

Las teclas usan `physical_keycode`: funcionan igual en teclados no QWERTY.

## Bucle de juego

1. **Ronda 0**: el gladiador empieza como *Prisionero* (sin rol) con 200 de oro.
2. La armería tiene tres armas a 200 de oro: comprar una define la clase y
   reemplaza el kit Q/W/E/R. Solo se puede comprar una por partida.
3. Cada oleada exige defender el **Estandarte de Rebelión** (900 PV) en el centro.
4. Al superar una oleada: `60 + 15·oleada` de oro, +2 puntos de atributo, +1 punto
   rojo de talento y 25 % de curación.
5. Cada 5 oleadas aparece un **jefe**; la oleada 20 cierra la partida.
6. Si el jugador permanece 14 s en un radio de 5 m, el público activa la
   **Furia del Público**: congela la ganancia de oro y lanza bolas de fuego
   durante 9 s. Moverse reinicia el contador.

## Armas

| Clase | Arma | Rol | Q | W | E | R |
| --- | --- | --- | --- | --- | --- | --- |
| Bastión | Gran Alabarda | Tanque | Muro de Escudos | Golpe Sísmico | Provocación | Bastión Inquebrantable |
| Filo | Guadaña Gemela | Verdugo | Tajo Gemelo | Paso Sombrío | Marca del Verdugo | Ejecución |
| Cetro | Bastón Rúnico | Convocador | Espina Vital | Estandarte de Rebelión | Lazo de Raíces | Espíritu Ancestral |

El Estandarte de Rebelión ya trae dos talentos de datos: `estandarte_radio`
(+1,5 m) y `estandarte_fuego` (+12 de daño de fuego, requiere el anterior).

## Escalado

Una sola fuente de verdad: `GladiatorStats.gd`. Ningún otro script replica las
fórmulas.

| Atributo | Aporta |
| --- | --- |
| Fuerza | Vida máxima, regeneración, daño físico plano, mitigación |
| Agilidad | Velocidad de ataque, crítico, multiplicador crítico, movimiento |
| Inteligencia | Maná, regeneración, daño mágico, herencia de invocaciones |

## Estructura

```
project.godot
export_presets.cfg          preset Web (sin threads, 1280x720)
scenes/main.tscn            raíz Arena
scripts/
  core/
    GladiatorStats.gd       atributos y escalado
    AbilityData.gd          datos de habilidad
    TalentData.gd           ranuras de talento
    ObjectPool.gd           pool genérico (enemigos, proyectiles)
  items/WeaponItem.gd       arma = clase + rol + bonos + 4 habilidades
  player/GladiatorController.gd  click-to-move, combate, maná, talentos
  enemies/
    ArenaEnemy.gd           esbirro de persecución directa
    ArenaBossAI.gd          FSM + Enrage 75 % / 50 %
  world/
    RebellionBanner.gd      objetivo defensivo
    ArmoryPedestal.gd       compra de armas
    AudienceFury.gd         anti-camping
    AudienceFireball.gd     proyectil del público
  effects/AbilityEffect.gd  ejecutor de habilidades (daño, cura, provocar)
  game/
    Arena.gd                construye el mundo, economía y condiciones
    ArenaCamera.gd          cámara ortográfica isométrica con límites
    WaveManager.gd          20 oleadas, jefes y recompensas
  ui/ArenaHUD.gd            barras, oleada, oro, puntos y slots QWER
tests/smoke_test.gd         prueba de humo headless (27 comprobaciones)
```

La escena se genera por código (`Arena._ready`) para iterar sin editor; los
sistemas son nodos independientes y sustituibles.

## Pruebas

```powershell
godot --headless --path . --script res://tests/smoke_test.gd
```

Cubre: construcción de la arena, catálogo de armas, compra en la armería,
bonos de atributo, inicio de oleada, daño del ataque básico, daño al estandarte,
escalado y fases del jefe (75 % / 50 %, inmunidad a aturdimiento) y el ciclo
completo de la Furia del Público. Sale con código 1 si algo falla.

Capturas de depuración (sin editor):

```powershell
godot --path . -- --captura            # preparación
godot --path . -- --captura-combate    # oleada 1 en curso
```

## Export web

Las plantillas 4.7.2 están en
`%APPDATA%\Godot\export_templates\4.7.2.stable\` (`web_nothreads_*`).

```powershell
New-Item -ItemType Directory -Force build/web
godot --headless --path . --export-release "Web" "build/web/index.html"
```

Salida esperada en `build/web/`: `index.html`, `index.js`, `index.wasm`
(~39 MB), `index.pck` y los worklets de audio. Para probarla hace falta servirla
por HTTP; abrir el `index.html` con `file://` no funciona.

## Rendimiento web

- Renderizador **GL Compatibility**.
- Pool de 24 enemigos y 8 bolas de fuego; sin instanciación en combate.
- Ruta del jefe recalculada solo si el objetivo se mueve >0,5 m.
- Regeneración a 4 Hz; sin asignaciones por frame en los bucles de movimiento.
- Export sin threads: no necesita cabeceras COOP/COEP.

## Límites conocidos

- Cooperativo aún no implementado: el diseño lo permite (grupo `gladiadores`,
  objetivo por jugador), pero `Arena` crea un solo gladiador.
- Sin audio, animaciones ni arte final.
- Los talentos se desbloquean automáticamente al ganar puntos rojos; falta UI.
- Sin guardado; reiniciar la partida recarga la escena.
- El daño de habilidades se resuelve con el ejecutor genérico; las habilidades
  de movilidad (Paso Sombrío) y las invocaciones aún no tienen lógica propia.

## Siguiente paso

1. Cooperativo local/online y objetivos por jugador.
2. UI de talentos y armería con descripciones.
3. Habilidades específicas: dash, invocaciones que heredan INT, ejecuciones.
4. Audio y animaciones; sustituir primitivas por modelos low-poly.
5. Guardado en `user://` y tabla de récords.
