# Gladiators Revenge

Arena de supervivencia con perspectiva isométrica 2.5D en **Godot 4.7**, pensada
para publicarse en **Web (HTML5 / WebAssembly)**. IP original: gladiadores orcos
de las Tierras Baldías se rebelan contra el Imperio Humano de Hierro.

## Estado (v1 candidata)

Partida completa de principio a fin: 20 oleadas, tres clases de arma, armería,
jefes con dos fases de furia, anti-camping, talentos con rangos, skins, HUD,
arte 3D animado y audio sintetizado. Sin cooperativo ni guardado todavía.

- 35 comprobaciones de humo + simulación acelerada de las 20 oleadas.
- Export web sin threads, servible desde cualquier hosting estático.
- Todo el arte es **CC0** (KayKit); el código es **MIT**.

## Ejecutar

```powershell
# Editor
godot --path .

# Partida directa
godot --path . scenes/main.tscn
```

Godot 4.7 se instaló con `winget install GodotEngine.GodotEngine`.

## Controles

| Entrada | Acción |
| --- | --- |
| Click derecho | Mover al punto del cursor (NavigationAgent3D) |
| Q / W / E / R | Habilidad del slot del arma equipada |
| F | Comprar el arma del pedestal más cercano (3,5 m) |
| T | Abrir/cerrar el panel de talentos |
| K | Cambiar la skin del orco |
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

Cada habilidad activa tiene talentos con rango, coste en puntos rojos y
requisitos. Se compran desde el panel **T**; el ejecutor `AbilityEffect` aplica
los modificadores de radio, duración y daño, y la invocación hereda la INT.

## Escalado

Una sola fuente de verdad: `GladiatorStats.gd`. Ningún otro script replica las
fórmulas.

| Atributo | Aporta |
| --- | --- |
| Fuerza | Vida máxima, regeneración, daño físico plano, mitigación |
| Agilidad | Velocidad de ataque, crítico, multiplicador crítico, movimiento |
| Inteligencia | Maná, regeneración, daño mágico, herencia de invocaciones |

## Arte y audio

- **KayKit Adventurers / Skeletons**: orco bárbaro con colmillos, esqueletos y
  caballero; armas y props del dungeon. Licencias CC0 en `assets/kaykit/`.
- `CharacterVisual.gd` monta el modelo, tinte de skin, armas en el hueso
  `handslot_r` y reproduce locomoción, ataque, casteo, daño y muerte.
- Cuatro skins cosméticas con **K** (Tierra Baldía, Ceniza, Sangre, Hielo).
- `Sfx.gd` sintetiza golpes, críticos, habilidades, compra, oleada y finales en
  PCM al arrancar; no hay archivos de audio.

## Estructura

```
project.godot
export_presets.cfg          preset Web (sin threads, 1280x720)
scenes/main.tscn            raíz Arena
assets/kaykit/              modelos, texturas y props CC0
scripts/
  core/
    GladiatorStats.gd       atributos y escalado
    AbilityData.gd          datos de habilidad
    TalentData.gd           ranuras de talento
    ObjectPool.gd           pool genérico (enemigos, proyectiles)
    SfxPlayer.gd            sintetizador PCM (class_name Sfx)
  items/WeaponItem.gd       arma = clase + rol + bonos + 4 habilidades
  player/
    GladiatorController.gd  click-to-move, combate, maná, talentos
    SpiritSummon.gd         invocación que hereda INT
  visual/CharacterVisual.gd modelos, skins, animaciones y armas
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
  ui/
    ArenaHUD.gd             barras, oleada, oro, puntos y slots QWER
    TalentPanel.gd          panel de talentos con rangos y requisitos
tests/
  smoke_test.gd             prueba de humo headless (37 comprobaciones)
  wave_sim.gd               simulación acelerada de las 20 oleadas
```

La escena se genera por código (`Arena._ready`) para iterar sin editor; los
sistemas son nodos independientes y sustituibles.

## Pruebas

```powershell
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/wave_sim.gd
```

La prueba de humo cubre construcción de la arena, catálogo, compra, bonos,
talento con requisito y rango, habilidades (radio, invocación), oleada, ataque
básico, estandarte, fases del jefe y ciclo de la Furia del Público. La
simulación recorre las 20 oleadas y verifica jefes en 5/10/15/20 y la victoria.

Capturas de depuración (sin editor):

```powershell
godot --path . -- --captura            # preparación
godot --path . -- --captura-combate    # oleada 1 en curso
godot --path . -- --captura-cerca      # close-up del orco
godot --path . -- --captura-talentos   # panel de talentos
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
- Audio 100 % procedural: cero peso en el `.pck`.

## Límites conocidos

- Cooperativo aún no implementado: el diseño lo permite (grupo `gladiadores`,
  objetivo por jugador), pero `Arena` crea un solo gladiador.
- Sin guardado ni tabla de récords; reiniciar recarga la escena.
- El audio es sintetizado; no hay música ni voces.
- Probado en Edge (WebAssembly) con 0 errores de consola: movimiento, compra,
  cambio de arma, talentos, Furia del Público y derrota con reinicio.

## Créditos

- Código y diseño: Chary-Lab, licencia MIT (`LICENSE`).
- Arte 3D: [KayKit](https://kaykit.itch.io/) — Adventurers, Skeletons y Dungeon
  Remastered, CC0. Detalle y licencias en `CREDITS.md`.
- Motor: [Godot Engine](https://godotengine.org/) 4.7.2, MIT.
