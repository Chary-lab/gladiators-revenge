# Gladiators Revenge

Arena de supervivencia con perspectiva isométrica 2.5D en **Godot 4.7**, pensada
para publicarse en **Web (HTML5 / WebAssembly)**. IP original: gladiadores orcos
de las Tierras Baldías se rebelan contra el Imperio Humano de Hierro.

## Estado (v1.8.5 jugable)

Partida completa de principio a fin: 20 oleadas, tres clases de arma, zona
segura con campeón, fuente, mercader y obelisco, jefes con dos fases de furia,
anti-camping, talentos con rangos, skins, HUD con retrato 3D y miniaturas
renderizadas, inventario de 6 ranuras con forja automática, objetos comunes, épicos y
legendarios con auras, arte 3D animado y audio CC0. **Cooperativo online autoritativo**
para hasta 3 gladiadores con salas en la nube; sin guardado todavía.

- 133 comprobaciones de humo + 23 comprobaciones de red + simulación de 20 oleadas.
- Export web sin threads, servible desde cualquier hosting estático.
- Export Android (APK), servidor Docker y despliegue Web automático con Actions.
- Revivir cooperativo, snapshots binarios a 15 Hz y tooltips/tienda rediseñados.
- **Apodo del gladiador**: la primera vez que entrás te pide un nombre (2–14
  letras, se guarda) y encabeza tu ficha en la arena.
- **Interfaz unificada (v1.8)**: tipografía **Cinzel** (SIL OFL), paleta de
  carbón/oro/ascua y colores de rareza (común, raro, épico, legendario) en un
  `Theme` compartido (`ForjaTema.tema_global()`); ninguna pantalla define su
  propia paleta.
- **Lobby atmosférico**: el campeón se exhibe en una vitrina 3D sobre brasas y
  aros de arena, con las salas públicas como tarjetas y el estado del lobby
  arriba.
- **Forja de campeones**: el gladiador a tamaño héroe, riel de clases con
  rombos, ficha RPG (nivel, atributos, estadísticas con barras, habilidades
  con descripción al tocarlas, equipo) y selector de piel.
- **HUD de combate**: una sola barra superior con oleada, estandarte y la ficha
  del jugador (apodo, nivel, enemigos abatidos y oro, con contadores animados);
  marcos de inventario por rareza. La sala de espera es sólo texto, sin panel.
- **Tienda**: filtros por categoría y rareza, placas de estado (xN, NUEVO,
  FORJABLE) y ficha lateral con comparación de datos.
- **Coop**: la sala de espera del cliente la manda el servidor (cuenta atrás
  real), la capa táctil existe también dentro de una sala y elegir campeón
  acorta la espera. El maestro pre-arranca una sola sala.
- **HUD táctil**: joystick con aro de runas y una rueda con INTERACTUAR en el
  centro y Q/W/E/R alrededor (nivel de cada habilidad, enfriamiento radial y
  segundos), pastilla de vida/maná, mercader/talentos/mochila, **FICHA** con
  atributos y descripción de las habilidades, y pausa. En móvil la consola de
  escritorio se apaga: la arena queda despejada.
- **Controles táctiles** en móvil: joystick de movimiento a la izquierda y
  botones grandes de Q/W/E/R, INTERACTUAR y DETENER. Las habilidades apuntan al
  enemigo más cercano. El tamaño de los botones se ajusta desde Ajustes.
- **Ajustes** (volumen y tamaño táctil) y **aviso de versión nueva** en el menú:
  comprueba el release de GitHub y abre la descarga con un toque.
- **Fin de partida** con "Volver a jugar" y "Salir al lobby" (los invitados de
  una sala solo ven Salir al lobby).
- Todo el arte es **CC0** (KayKit, Kenney) y la tipografía **SIL OFL**
  (Cinzel); el código es **MIT**.

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

En Web y APK aparece un menú con **Jugar solo**, **Crear sala** y **Unirse a
partida**. En escritorio, **Crear sala** lo hace todo sin instalar nada: descarga
`cloudflared` la primera vez, abre el túnel, lanza el servidor headless y registra
la sala en el lobby público; el botón **Terminar** de la pantalla final apaga
servidor y túnel. En la web y el APK, **Crear sala** pide una sala al servidor
maestro desplegado (`red/api_url`), porque un navegador no puede abrir puertos. El servidor (`Dockerfile`, `fly.toml`, `render.yaml`) es la
autoridad de oleadas, enemigos, daño, oro, compras, talentos e inventario. Los
clientes envían sus acciones y reciben snapshots a 15 Hz.

- Hasta 3 jugadores, una clase distinta por persona y partida.
- El servidor rechaza repetir clase o cambiarla después de elegir.
- Los pedestales de clases ocupadas se apagan en todos los clientes; al elegir,
  el jugador deja de ver cualquier opción de campeón.
- Los efectos de habilidad se dibujan en los clientes sin aplicar daño local.
- Si un jugador cae y otro sigue vivo, revive automáticamente en 10 s (≈4 s si
  un aliado está cerca) conservando nivel, talentos e inventario.
- Guía de despliegue y pruebas: [`docs/ONLINE.md`](docs/ONLINE.md).
- Para que la web cree salas: [`DEPLOY.md`](DEPLOY.md) (servidor maestro en Fly o
  Render, y cómo apuntar la web con `red/api_url`).

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

## Interfaz y dirección de arte

La interfaz entera sale de un único sistema: `scripts/ui/ForjaTema.gd` define la
paleta (carbón cálido, oro viejo, ascua), los colores de rareza, la tipografía y
`tema_global()`, que `Arena._ready` aplica a la raíz del árbol para que todo
`Control` la herede. Los títulos usan **Cinzel** (`assets/ui/Cinzel-variable.ttf`,
SIL OFL) y el cuerpo, la sans del motor.

Los rótulos de sección (`rotulo()`), los paneles (`estilo_panel`, `estilo_ventana`,
`estilo_tarjeta`), las barras segmentadas, los iconos de estadística y las esquinas
grabadas viven ahí; una pantalla nueva solo compone piezas. El fondo de las
pantallas de menú es `FondoForja` (degradado, resplandor de ascua, aros de arena y
brasas dibujadas, sin shaders) y el campeón se muestra en `VitrinaCampeon`, un
`SubViewport` con tres luces y giro de presentación que no se construye en
headless.

## Consola inferior

La barra superior es un solo panel continuo: oleada, cuenta atrás y enemigos a
la izquierda; el estandarte (objetivo de la partida) en el centro; oro y puntos a
la derecha; y la lengüeta de estadísticas colgando abajo a la izquierda.

La consola de 185 px se divide en cuatro bloques: minimapa cuadrado, retrato 3D
en vivo con barras de vida/maná, ficha del gladiador con nivel, XP, oleada,
atributo principal y estado, inventario 2x3 y parrilla de comandos/habilidades
4x3. Las ranuras del inventario llevan el marco del color de la rareza del
objeto. Los botones son **solo iconos**; el nombre y el escalado real viven en el
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
5. Cada oleada tiene un **tema** con arquetipos propios (esqueletos, espectros,
   arqueros, magos, bárbaros tanque y caballeros de élite) según
   `BalanceOlas.PERFILES`; la 5, 10, 15 y 20 traen jefe y la 20 cierra la partida.
6. Si el jugador permanece 14 s en un radio de 5 m, el público activa la
   **Furia del Público**: congela la ganancia de oro y lanza bolas de fuego
   durante 9 s. Moverse reinicia el contador.

La clase se escoge una sola vez por partida: al elegir un campeón, los otros
pedestales se apagan y desaparecen como opción. Los rangos de habilidad ya no
se compran; el panel **T** solo invierte puntos rojos en talentos.

## Balance

Todo el balance vive en tres sitios y ninguna fórmula se replica fuera de ellos.

| Pieza | Dónde | Qué controla |
| --- | --- | --- |
| Daño mín-máx | `GladiatorStats.rango_dano_ataque()` | Banda del golpe básico (±20 %) |
| Ritmo de ataque | `GladiatorStats.velocidad_ataque` | Base 0,15 + 0,05 por AGI + 0,025 por nivel (golpes/s) |
| Clase | `MULT_DANO_POR_CLASE` | Prisionero 0,80 · Bastión 1,00 · Filo 1,12 · Cetro 0,92 |
| Enemigos | `ArenaEnemy.ARQUETIPOS` | Vida, daño, velocidad y cadencia por arquetipo |
| Oleadas | `BalanceOlas.PERFILES` | Mezcla de arquetipos, vida/daño extra y jefe |

El ataque básico tira `randf_range(min, max)`; la media es
`(daño del arma + atributo principal × 0,45) × (1 + 0,09 por nivel) × mult de clase`.
Un gladiador de nivel 1 pega poco a propósito: el daño llega con niveles, equipo
y auras, no con la estadística base. La recarga del golpe la descuenta
`CombatComponent.iniciar_recarga_ataque()`: si se escribe solo en el controlador,
el temporizador se reinicia cada frame y el campeón ataca sin parar.

Enemigos: vida `66 + 24 × oleada` y daño `6 + 2,0 × oleada`, con multiplicadores
por arquetipo. Cantidad: `7 + 2,2 × oleada` (9 enemigos en la oleada 1, 51 en la 20).
`tests/playtest.gd` juega solo: elige campeón, gasta puntos y talentos, usa
habilidades y mide por oleada duración, TTK, bajas/s y daño recibido.

Los atributos alimentan las estadísticas base: Fuerza → vida y mitigación,
Agilidad → armadura, velocidad de ataque y crítico, Inteligencia → maná y daño
mágico. `tests/balance_report.gd` imprime la curva (HP, DPS, TTK y
supervivencia) de las cuatro clases en los niveles 1, 5, 10, 15 y 20 para afinar
constantes sin abrir el editor.

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
    BalanceOlas.gd          perfiles de oleada (arquetipos, vida y jefe)
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
  net/CrearSala.gd          descarga cloudflared, abre el túnel y lanza el servidor
  net/MaestroSalas.gd       varias salas por contenedor (HTTP + proxy por ruta)
  net/SalaRemota.gd         pide una sala al maestro (Web/APK)
  ui/
    ArenaHUD.gd             consola 185 px, retrato, ficha, 2x3 y parrilla 4x3
    ArenaMinimap.gd         radar 2D del patio
    MenuRed.gd              menú Jugar solo / Crear sala / Unirse a partida
    DamageNumbers.gd        números de daño/curación con pool
    TalentPanel.gd          panel de talentos con rangos y requisitos
    ShopPanel.gd            tienda, recetario, forja y tooltips
    IconStudio.gd           miniaturas 3D 64x64 con SubViewport y caché
    ItemModelFactory.gd     modelos de objetos y comandos con primitivas
    GladiatorPortrait.gd    busto 3D animado para la consola
tests/
  smoke_test.gd             smoke crítico headless (15 comprobaciones, ~2 s)
  regression_test.gd        cobertura completa (135 comprobaciones)
  net_smoke.gd              cliente coop: conexión, compra y clase única
  net_smoke_b.gd            segundo cliente: clase única y revivir
  wave_sim.gd               simulación acelerada de las 20 oleadas
  balance_report.gd         informe de DPS, TTK y supervivencia por clase
  playtest.gd               bot que juega oleadas y mide el ritmo real
Dockerfile                  servidor cooperativo headless
fly.toml / render.yaml      despliegue del servidor
supabase/migrations/        esquema de servidores y partidas
```

La escena se genera por código (`Arena._ready`) para iterar sin editor; los
sistemas son nodos independientes y sustituibles.

## Pruebas

```powershell
# Smoke crítico (arranque, identidad, datos, flujos de negocio): ~2 s
godot --headless --path . --script res://tests/smoke_test.gd

# Regresión completa: todo lo anterior + balance, jefe, UI, auras, anti-camping
godot --headless --path . --script res://tests/regression_test.gd

# Todas las suites en paralelo (un proceso Godot por suite, user:// aislado)
./tools/pruebas.ps1 -Suite all
./tools/pruebas.ps1 -Suite smoke        # bucle de desarrollo
./tools/pruebas.ps1 -Suite red          # levanta servidor + A + B y limpia
godot --headless --path . --script res://tests/wave_sim.gd

# Red a mano: servidor + cliente A + cliente B (ver docs/ONLINE.md)
godot --headless -- --servidor --puerto=9080 --red-rapida
godot --headless --script res://tests/net_smoke.gd -- --cliente=ws://127.0.0.1:9080 --esperar=40
godot --headless --script res://tests/net_smoke_b.gd -- --cliente=ws://127.0.0.1:9080
```

El smoke crítico comprueba que la arena arranca, el perfil del jugador se
normaliza, Supabase y las salas responden, y que tienda, forja, progresión,
oleada, ataque básico, estandarte y cierre de partida funcionan. La suite de
regresión añade catálogo, bonos, talentos, auras, UI y balance.
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
`canvas_items`, así que el mismo proyecto escala a móviles y tablets. En pantallas
táctiles aparece una capa de botones (`TouchControls`): Q/W/E/R, INTERACTUAR y
DETENER; para probarla en escritorio: `godot -- --tactil`.

## Multijugador online

El cooperativo online ya está implementado: servidor Godot headless
autoritativo, WebSocket y snapshots. Hasta 3 jugadores con una clase distinta
cada uno; el servidor rechaza repetir clase o cambiarla.

- **Salas en la nube**: un maestro (`--maestro`) levanta varias partidas en un
  contenedor y reparte a los jugadores con `POST /salas`. La web y el APK crean
  sala con un clic; en escritorio el anfitrión puede levantar la suya con túnel.
- **Sala de espera de 30 s** con cuenta atrás y "N/3 gladiadores"; si alguien
  entra con menos de 8 s, la preparación se alarga.
- El menú de red solo muestra la lista de salas: no hay que pegar URLs.
- Guía de ejecución, pruebas y despliegue: [`docs/ONLINE.md`](docs/ONLINE.md) y
  [`DEPLOY.md`](DEPLOY.md).

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
