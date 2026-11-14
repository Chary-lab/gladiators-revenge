# Créditos y licencias

## Código y diseño

**Gladiators Revenge** — Chary-Lab, 2026.

- Código fuente: licencia MIT (`LICENSE`).
- Diseño de juego, lore (Orcos de las Tierras Baldías contra el Imperio Humano
  de Hierro), nombres de armas, habilidades y talentos: originales.
- Audio: efectos de **Kenney** (CC0) en `assets/audio/`; si un archivo falta,
  `scripts/core/SfxPlayer.gd` sintetiza el efecto en tiempo de ejecución.
- Iconos de la consola: miniaturas 3D originales generadas en tiempo de ejecución
  por `scripts/ui/IconStudio.gd` y `ItemModelFactory.gd` con primitivas de Godot;
  no usan arte de terceros.
- No contiene samples de terceros fuera de los packs CC0 acreditados abajo.

## Tipografía

| Fuente | Uso | Licencia |
| --- | --- | --- |
| [Cinzel](https://github.com/NDISCOVER/Cinzel) | Títulos, versalitas y rótulos de toda la interfaz | SIL Open Font License 1.1 (`assets/ui/Cinzel-OFL.txt`) |

El cuerpo de texto usa la sans que incluye Godot (Open Sans), sin archivos
externos. La fuente se carga como `FontFile` variable y se espacia con
`FontVariation` para los rótulos (`ForjaTema.fuente_etiqueta()`).

## Arte 3D

Los modelos, texturas y props son de **KayKit** y se distribuyen como **CC0**
(dominio público). Se incluyen sin modificaciones de licencia; los materiales
se tiñen en tiempo de ejecución para crear las skins.

| Pack | Uso | Licencia |
| --- | --- | --- |
| [KayKit Character Pack: Adventurers](https://kaykit.itch.io/adventurers) | Orco bárbaro (jugador), caballero jefe, armas | CC0 |
| [KayKit Character Pack: Skeletons](https://kaykit.itch.io/skeletons) | Esqueletos enemigos y espíritu invocado | CC0 |
| [KayKit Dungeon Remastered](https://kaykit.itch.io/dungeon) | Columnas, antorchas, estandartes | CC0 |

Las licencias completas están en:

- `assets/kaykit/adventurers/LICENSE.txt`
- `assets/kaykit/skeletons/LICENSE.txt`
- `assets/kaykit/dungeon/LICENSE.txt`

## Audio

| Pack | Uso | Licencia |
| --- | --- | --- |
| [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Golpes, muertes, campanas | CC0 |
| [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio) | Monedas, tajos, puertas | CC0 |
| [Kenney UI Audio](https://kenney.nl/assets/ui-audio) | Clic de interfaz | CC0 |

Las licencias completas están en:

- `assets/audio/LICENSE-impact-sounds.txt`
- `assets/audio/LICENSE-rpg-audio.txt`
- `assets/audio/LICENSE-ui-audio.txt`

## Motor

[Godot Engine](https://godotengine.org/) 4.7.2 — MIT.
