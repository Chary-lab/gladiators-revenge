# Gladiators Revenge

Arena de supervivencia con perspectiva isométrica 2.5D en **Godot 4.7**, pensada
para publicarse en **Web (HTML5 / WebAssembly)**. IP original: gladiadores orcos
de las Tierras Baldías se rebelan contra el Imperio Humano de Hierro.

## Estado (v1.1 jugable)

Partida completa de principio a fin: 20 oleadas, tres clases de arma, armería,
jefes con dos fases de furia, anti-camping, talentos con rangos, skins, HUD
unificado, inventario de 6 ranuras con forja automática, objetos legendarios,
arte 3D animado y audio CC0. Sin cooperativo ni guardado todavía.

- 55 comprobaciones de humo + simulación acelerada de las 20 oleadas.
- Export web sin threads, servible desde cualquier hosting estático.
- Todo el arte es **CC0** (KayKit, Kenney); el código es **MIT**.

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
| Click derecho en suelo | Mover al punto (NavigationAgent3D), con anillo verde |
| Click derecho en enemigo | Fijar objetivo prioritario y perseguirlo |
| Q / W / E / R | Habilidad del slot del arma equipada |
| Click izquierdo | Tras **A**, atacar-mover: avanza y combate al cruzarse enemigos |
| F | Comprar arma o abrir el mercader si está cerca (3,5 m) |
| Z / X / C / V / B / N | Usar la ranura de inventario correspondiente |
| T | Abrir/cerrar el panel de talentos (pausa la partida) |
| K | Cambiar la skin del orco |
| S | Detener el movimiento y soltar el objetivo |
| H | Mantener posición: no persigue, solo ataca a su alcance |
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

Sinergias de clase: el Golpe Sísmico del Bastión pega un 35 % más y aturde más
tiempo contra enemigos provocados; el Paso Sombrío del Filo deja rastro y
potencia el siguiente Tajo un 40 %; la Ejecución reduce su enfriamiento si el
objetivo está marcado o muere; la Espina Vital del Cetro salta a un aliado y el
Lazo de Raíces aumenta el daño mágico recibido.

## Objetos, tienda y forja

El **Mercader de la Rebelión** (F, junto a la carpa del este) vende pociones,
pergaminos, componentes y recetas. La mochila tiene 6 ranuras activas.

- **Pociones**: Sangre (cura `140 + 40 % FUE`) y Savia (`100 + 30 % INT`), con
  enfriamiento compartido.
- **Pergaminos**: Égida para el estandarte, Temblor de raíces en zona y Furia
  temporal (+35 % velocidad de ataque y 15 % robo de vida).
- **6 componentes** (100–130 de oro): atributos planos, armadura, crítico,
  regeneración.
- **6 intermedios** con receta de 2 piezas y forja de 80 de oro.
- **4 legendarios**: Corazón de Obsidiana (escudo e inmunidad a aturdimientos), Daga del Eclipse
  (parpadeo y crítico asegurado), Orbe del Cataclismo (descarga mágica con 3
  rebotes) y Cuerno de la Rebelión (cura el estandarte y da gritos de guerra).

La forja es automática: al comprar el ingrediente que completa una receta, se
consumen los materiales, se cobra la forja y, si el resultado completa otra
receta, la cadena sigue hasta el legendario. Los objetos equipados aplican sus
bonos mediante `GladiatorStats.aplicar_bonos_inventario`.

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
- **Kenney Impact / RPG / UI Audio**: golpes, monedas, tajos y clics. Licencias
  CC0 en `assets/audio/`; `Sfx.gd` usa los OGG y sintetiza si falta alguno.
- `CharacterVisual.gd` monta el modelo, tinte de skin, armas en el hueso
  `handslot_r` y reproduce locomoción, ataque, casteo, daño y muerte.
- Cuatro skins cosméticas con **K** (Tierra Baldía, Ceniza, Sangre, Hielo).

## Estructura

```
project.godot
export_presets.cfg          preset Web (sin threads, 1280x720)
scenes/main.tscn            raíz Arena
assets/kaykit/              modelos, texturas y props CC0
assets/audio/               efectos CC0 de Kenney
scripts/
  core/
    GladiatorStats.gd       atributos y escalado
    AbilityData.gd          datos de habilidad
    TalentData.gd           ranuras de talento
    ObjectPool.gd           pool genérico (enemigos, proyectiles)
    SfxPlayer.gd            carga OGG de Kenney y sintetiza como respaldo
  items/WeaponItem.gd       arma = clase + rol + bonos + 4 habilidades
  items/ItemData.gd         datos de poción, componente, intermedio o legendario
  items/ItemCatalog.gd      catálogo, precios y recetas de forja
  items/InventoryComponent.gd 6 ranuras, bonos, enfriamientos y uso
  player/
    GladiatorController.gd  click-to-move, objetivo, combate, talentos, objetos
    SpiritSummon.gd         invocación que hereda INT
  visual/CharacterVisual.gd modelos, skins, animaciones y armas
  enemies/
    ArenaEnemy.gd           esbirro de persecución directa
    ArenaBossAI.gd          FSM + Enrage 75 % / 50 %
  world/
    RebellionBanner.gd      objetivo defensivo
    ArmoryPedestal.gd       compra de armas
    ShopPedestal.gd         mercader del patio
    AudienceFury.gd         anti-camping
    AudienceFireball.gd     proyectil del público
  effects/AbilityEffect.gd  ejecutor de habilidades (daño, cura, provocar)
  game/
    Arena.gd                construye el mundo, economía y condiciones
    ArenaCamera.gd          cámara ortográfica isométrica con límites
    WaveManager.gd          20 oleadas, jefes y recompensas
  ui/
    ArenaHUD.gd             consola inferior, minimapa, stats, mochila y QWER
    ArenaMinimap.gd         radar 2D del patio
    DamageNumbers.gd        números de daño/curación con pool
    TalentPanel.gd          panel de talentos con rangos y requisitos
    ShopPanel.gd            tienda, recetario, forja y tooltips
tests/
  smoke_test.gd             prueba de humo headless (55 comprobaciones)
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
talentos con requisitos y rangos, habilidades (radio, invocación, sinergias),
oleada, ataque básico, estandarte, fases del jefe, ciclo de la Furia del Público,
inventario, pociones, forja en cadena hasta legendario y cierre de partida. La
simulación recorre las 20 oleadas y verifica jefes en 5/10/15/20 y la victoria.

Capturas de depuración (sin editor):

```powershell
godot --path . -- --captura            # preparación
godot --path . -- --captura-combate    # oleada 1 en curso
godot --path . -- --captura-cerca      # close-up del orco
godot --path . -- --captura-talentos   # panel de talentos
godot --path . -- --captura-tienda     # mercader y recetario
godot --path . -- --captura-habilidad  # invocación del Cetro
godot --path . -- --captura-jefe       # Liche de la Arena
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
- Pool de 24 enemigos, 8 bolas de fuego y 40 números de daño; sin instanciación
  en combate.
- Ruta del jefe recalculada solo si el objetivo se mueve >0,5 m.
- Regeneración a 4 Hz; sin asignaciones por frame en los bucles de movimiento.
- Export sin threads: no necesita cabeceras COOP/COEP.
- Audio: 13 OGG de Kenney (~150 KB); si falta un archivo, se sintetiza.

## Límites conocidos

- Cooperativo aún no implementado: el diseño lo permite (grupo `gladiadores`,
  objetivo por jugador), pero `Arena` crea un solo gladiador.
- Sin guardado ni tabla de récords; reiniciar recarga la escena.
- El audio usa efectos CC0 de Kenney; no hay música ni voces.
- Probado en Edge (WebAssembly) con 0 errores de consola: movimiento, objetivo,
  compra de armas, compra en el mercader, talentos, Furia del Público, derrota y
  reinicio.

## Créditos

- Código y diseño: Chary-Lab, licencia MIT (`LICENSE`).
- Arte 3D: [KayKit](https://kaykit.itch.io/) — Adventurers, Skeletons y Dungeon
  Remastered, CC0. Detalle y licencias en `CREDITS.md`.
- Audio: [Kenney](https://kenney.nl/assets) — Impact Sounds, RPG Audio y UI
  Audio, CC0.
- Motor: [Godot Engine](https://godotengine.org/) 4.7.2, MIT.
