# Gladiators Revenge

Arena de supervivencia con perspectiva isométrica 2.5D en **Godot 4.7**, pensada
para publicarse en **Web (HTML5 / WebAssembly)**. IP original: gladiadores orcos
de las Tierras Baldías se rebelan contra el Imperio Humano de Hierro.

## Estado (v1.2 jugable)

Partida completa de principio a fin: 20 oleadas, tres clases de arma, zona
segura con campeón, fuente, mercader y obelisco, jefes con dos fases de furia,
anti-camping, talentos con rangos, skins, HUD con retrato 3D y miniaturas
renderizadas, inventario de 6 ranuras con forja automática, objetos comunes, épicos y
legendarios con auras, arte 3D animado y audio CC0. **Cooperativo online autoritativo** para hasta 3
gladiadores; sin guardado todavía.

- 81 comprobaciones de humo + 23 comprobaciones de red + simulación de 20 oleadas.
- Export web sin threads, servible desde cualquier hosting estático.
- Export Android (APK), servidor Docker y despliegue Web automático con Actions.
- Revivir cooperativo, snapshots binarios a 15 Hz y tooltips/tienda rediseñados.
- Todo el arte es **CC0** (KayKit, Kenney); el código es **MIT**.

## Ejecutar

```powershell
# Editor
godot --path .

# Partida directa
godot --path . scenes/main.tscn

# Servidor cooperativo
godot --headless -- --servidor --puerto=9080

# Cliente cooperativo de escritorio
godot -- --cliente=ws://127.0.0.1:9080
```

Godot 4.7 se instaló con `winget install GodotEngine.GodotEngine`.

## Cooperativo online

En Web y APK aparece un menú con **Jugar solo** y **Unirse a partida**. El
servidor (`Dockerfile`, `fly.toml`, `render.yaml`) es la autoridad de oleadas,
enemigos, daño, oro, compras, talentos e inventario. Los clientes envían sus
acciones y reciben snapshots a 10 Hz.

- Hasta 3 jugadores, una clase distinta por persona y partida.
- El servidor rechaza repetir clase o cambiarla después de elegir.
- Los pedestales de clases ocupadas se apagan en todos los clientes; al elegir,
  el jugador deja de ver cualquier opción de campeón.
- Los efectos de habilidad se dibujan en los clientes sin aplicar daño local.
- Si un jugador cae y otro sigue vivo, revive automáticamente en 10 s (≈4 s si
  un aliado está cerca) conservando nivel, talentos e inventario.
- Guía de despliegue y pruebas: [`docs/ONLINE.md`](docs/ONLINE.md).

## Supabase

El proyecto usa Supabase (`ntmxmaxaprmqmvhsxtmd`) para **descubrimiento de
servidores** e **historial de partidas**:

- `servidores`: el servidor Godot registra su URL `wss://`, región y jugadores
  cada 20 s; el menú muestra los activos (últimos 2 minutos).
- `partidas`: al terminar, el servidor guarda resultado, oleada, duración y
  clases/niveles de los jugadores.
- El cliente usa solo la `anon key` + RLS. La `service_role` va exclusivamente
  como variable de entorno del servidor (`SUPABASE_SERVICE_KEY`).
- La connection string de Postgres solo se usa para aplicar la migración; nunca
  en el cliente.

Pasos completos y seguridad en [`supabase/README.md`](supabase/README.md).

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

## Consola inferior

La consola de 185 px se divide en cuatro bloques: minimapa cuadrado, retrato 3D
en vivo con barras de vida/maná, ficha del gladiador con nivel, XP, oleada,
atributo principal y estado, inventario 2x3 y parrilla de comandos/habilidades
4x3. Los botones son **solo iconos**; el nombre y el escalado real viven en el
tooltip. La tecla de cada botón va en la esquina superior izquierda y las
habilidades muestran puntos dorados con su rango actual. `IconStudio.gd`
renderiza miniaturas 3D de 64x64 con luz cálida, rim light y fondo degradado
(fuego para Fuerza, esmeralda para Agilidad, azul/violeta para INT, dorado para
legendarios), las cachea y usa un icono procedural si corre en `--headless`.
`ItemModelFactory.gd` construye armas, escudos, pociones, pergaminos, orbes,
flechas, botas y demás piezas con primitivas propias.

## Bucle de juego

1. **Zona segura**: cada gladiador elige un campeón gratuito en uno de los tres
   pedestales. La clase queda fijada para la partida; en co-op cada persona debe
   elegir una distinta. La fuente cura fuera de combate y el mercader/forja/
   obelisco solo se usan en la base.
2. La oleada avisa con 30 s de preparación; al abrirse los portones hay 8 s de
   entrada con +35 % de velocidad y luego se cierran.
3. Cada oleada exige defender el **Estandarte de Rebelión** (900 PV); puede
   recogerse con **G** y colocarse en otro punto del arena.
4. Al superar una oleada: oro, puntos de atributo, punto rojo de talento y 25 %
   de curación; cada nivel sube automáticamente los atributos de la clase y una
   habilidad aleatoria (Q/W/E/R) que no esté al máximo.
5. Cada 5 oleadas aparece un **jefe**; la oleada 20 cierra la partida.
6. Si el jugador permanece 14 s en un radio de 5 m, el público activa la
   **Furia del Público**: congela la ganancia de oro y lanza bolas de fuego
   durante 9 s. Moverse reinicia el contador.

La clase se escoge una sola vez por partida: al elegir un campeón, los otros
pedestales se apagan y desaparecen como opción. Los rangos de habilidad ya no
se compran; el panel **T** solo invierte puntos rojos en talentos.

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
- **3 épicos** (receta de 2 piezas y forja de 180): Armadura de Brasas, Anillo de
  Vampirismo y Corazón de Fénix. Además de sus stats irradian aura.
- **6 legendarios**: Corazón de Obsidiana (escudo e inmunidad a aturdimientos), Daga del Eclipse
  (parpadeo y crítico asegurado), Orbe del Cataclismo (descarga mágica con 3
  rebotes), Cuerno de la Rebelión (cura el estandarte y da gritos de guerra),
  Capa del Comandante y Guadaña del Verdugo Ancestral (auras de mando).

La forja es automática: al comprar el ingrediente que completa una receta, se
consumen los materiales, se cobra la forja y, si el resultado completa otra
receta, la cadena sigue hasta el legendario. Los objetos equipados aplican sus
bonos mediante `GladiatorStats.aplicar_bonos_inventario`.

**Rarezas y auras.** `ItemData.rareza` (común, épico, legendario) decide el
color en la tienda: gris, púrpura y dorado. `ItemData.aura` es un diccionario
que el portador irradia a sí mismo y a los aliados a 10 m
(`GladiatorController.auras_cercanas`, acumulado en `InventoryComponent.auras`):
`dano_aliados`, `velocidad_ataque_aliados`, `robo_vida_aliados` y
`regeneracion_aliados`. Se aplican al golpe básico, a las invocaciones, a la
regeneración de `CombatComponent` y al temporizador de ataque.

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
    Arena.gd                construye el mundo, economía, red y condiciones
    ArenaCamera.gd          cámara ortográfica isométrica con límites
    WaveManager.gd          20 oleadas, jefes y recompensas
  net/NetCoop.gd            WebSocket, RPCs, lobby y snapshots
  net/Supabase.gd           registro de servidores y partidas por REST
  ui/
    ArenaHUD.gd             consola 185 px, retrato, ficha, 2x3 y parrilla 4x3
    ArenaMinimap.gd         radar 2D del patio
    MenuRed.gd              menú Jugar solo / Unirse a partida
    DamageNumbers.gd        números de daño/curación con pool
    TalentPanel.gd          panel de talentos con rangos y requisitos
    ShopPanel.gd            tienda, recetario, forja y tooltips
    IconStudio.gd           miniaturas 3D 64x64 con SubViewport y caché
    ItemModelFactory.gd     modelos de objetos y comandos con primitivas
    GladiatorPortrait.gd    busto 3D animado para la consola
tests/
  smoke_test.gd             prueba de humo headless (81 comprobaciones)
  net_smoke.gd              cliente coop: conexión, compra y clase única
  net_smoke_b.gd            segundo cliente: clase única y revivir
  wave_sim.gd               simulación acelerada de las 20 oleadas
Dockerfile                  servidor cooperativo headless
fly.toml / render.yaml      despliegue del servidor
supabase/migrations/        esquema de servidores y partidas
```

La escena se genera por código (`Arena._ready`) para iterar sin editor; los
sistemas son nodos independientes y sustituibles.

## Pruebas

```powershell
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/wave_sim.gd

# Red: servidor + cliente A + cliente B (ver docs/ONLINE.md)
godot --headless -- --servidor --puerto=9080 --red-rapida
godot --headless --script res://tests/net_smoke.gd -- --cliente=ws://127.0.0.1:9080
godot --headless --script res://tests/net_smoke_b.gd -- --cliente=ws://127.0.0.1:9080
```

La prueba de humo cubre construcción de la arena, catálogo, compra, bonos,
talentos con requisitos y rangos, habilidades (radio, invocación, sinergias),
crecimiento por nivel, subida aleatoria de habilidades, clase única por partida,
oleada, ataque básico, estandarte, fases del jefe, ciclo de la Furia del Público,
inventario, pociones, forja en cadena hasta legendario y cierre de partida. La
simulación recorre las 20 oleadas y verifica jefes en 5/10/15/20 y la victoria.
Las pruebas de red verifican conexión, snapshots binarios, movimiento
autoritativo, compra, enemigos, oleadas, clase única, muerte y revivir con el
inventario intacto.

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

## GitHub Pages

El workflow `.github/workflows/web-pages.yml` exporta la build Web en cada push a
`main` y la publica con GitHub Pages.

1. En GitHub, entra en **Settings → Pages** y elige **Source: GitHub Actions**.
2. Haz push a `main` (o lanza el workflow **Web / GitHub Pages** a mano desde
   **Actions**).
3. La URL queda en
   `https://chary-lab.github.io/gladiators-revenge/`.

El workflow instala Godot 4.7.2 con sus plantillas, exporta con el preset `Web`
(sin threads, así no necesita cabeceras COOP/COEP) y sube `build/web` como
artefacto de Pages.

## APK Android

El preset `Android` compila un APK de depuración (`build/android/`). El workflow
`.github/workflows/android-apk.yml` lo genera en la nube:

- Se lanza desde **Actions → Android APK → Run workflow** o al empujar una tag
  `v*`.
- Instala Java 17, plantillas Android de Godot 4.7.2 y el SDK Android 35.
- Genera un keystore de depuración (`debug.keystore`, ignorado por git) y sube el
  APK como artefacto; en tags lo adjunta a la release.

Para compilarlo en local hacen falta el SDK Android, JDK 17 y las plantillas
Android de Godot:

```powershell
# Crear debug.keystore si no existe (requiere keytool del JDK)
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android `
  -keystore debug.keystore -storepass android `
  -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
New-Item -ItemType Directory -Force build/android
godot --headless --path . --export-debug "Android" "build/android/gladiators-revenge.apk"
```

El juego usa el renderizador **GL Compatibility** y vista 1280×720 con
`canvas_items`, así que el mismo proyecto escala a móviles y tablets.

## Multijugador online

El cooperativo online ya está implementado: servidor Godot headless
autoritativo, WebSocket y snapshots. Hasta 3 jugadores con una clase distinta
cada uno; el servidor rechaza repetir clase o cambiarla. La guía de ejecución,
pruebas y despliegue está en [`docs/ONLINE.md`](docs/ONLINE.md).

## Rendimiento web

- Renderizador **GL Compatibility**.
- Pool de 24 enemigos, 8 bolas de fuego y 40 números de daño; sin instanciación
  en combate.
- Ruta del jefe recalculada solo si el objetivo se mueve >0,5 m.
- Regeneración a 4 Hz; sin asignaciones por frame en los bucles de movimiento.
- Export sin threads: no necesita cabeceras COOP/COEP.
- Audio: 13 OGG de Kenney (~150 KB); si falta un archivo, se sintetiza.

## Límites conocidos

- Las invocaciones del Cetro y los números de daño flotantes no se replican en
  red; el daño se ve en las barras y en los efectos de habilidad.
- El servidor no persiste la partida ni permite reconectar a mitad de oleada.
- Sin guardado ni tabla de récords; reiniciar recarga la escena.
- El audio usa efectos CC0 de Kenney; no hay música ni voces.
- Probado en Edge (WebAssembly) con 0 errores de consola: menú, unión al
  servidor, movimiento, objetivo, compra de armas, compra en el mercader,
  talentos, Furia del Público, derrota y reinicio.

## Créditos

- Código y diseño: Chary-Lab, licencia MIT (`LICENSE`).
- Arte 3D: [KayKit](https://kaykit.itch.io/) — Adventurers, Skeletons y Dungeon
  Remastered, CC0. Detalle y licencias en `CREDITS.md`.
- Audio: [Kenney](https://kenney.nl/assets) — Impact Sounds, RPG Audio y UI
  Audio, CC0.
- Motor: [Godot Engine](https://godotengine.org/) 4.7.2, MIT.
