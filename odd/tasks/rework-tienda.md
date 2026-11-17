# Rework de la tienda — más dinámica, interactiva y moderna

Rama: `main` (push al final) · Runner: `godot --headless --script res://tests/<suite>.gd` + `--captura-tienda`

## Specs

**S1** — Pedido del usuario (verbatim): "no me convece la tienda, tenemos que hacerle un tipo de rework que sea mas dinamico e facil de distinguir, de poder crear los items, que se interactivo y creativo, que sea facil de entender y facil de usar y moderno, algo asi como la tienda de lol o dota 2".

**S2** — Decisión del usuario (verbatim): "Rework completo con pestañas y forja visual (Recommended)" = "Rediseñar ShopPanel: pestañas COMPRAR/FORJAR/COMPONENTES, tarjetas con rareza glow y badges, barra de progreso de forja en vivo con 'FORJAR AHORA', y una ruta sugerida. Mantengo compatibilidad con tests."

**S3** — Restricciones (AGENTS.md): tienda es un modal 1120×560 sobre la arena (no pantalla completa — se descartó la opción LoL literal); una sola lista original sin pestañas (S2 la cambia a conciencia); tocar tarjeta selecciona, tocar otra vez compra; lógica de compra en Arena/InventoryComponent; sin glyphs tofu (◆✔✘); dirty flags y refresco en sitio (no reconstruir 26 tarjetas por compra); Botón ÁRBOL DE FORJA debe seguir abriendo BuildTreePanel.

## Tasks

- **T1** — S1-S3 — ruta: inline (mapeo delegado `gentle-ai-explore`, sesión `ses_e164ba681ffer6HkUo31l2br72`) — estado: en curso — mapear estructura de ShopPanel, categorización, API de compra/forja, dependencias de tests y patrones visuales reutilizables.
- **T2** — S2-S3 — ruta: inline — estado: pendiente — rediseñar ShopPanel (pestañas, tarjetas, forja visual, ruta) conservando nombres que leen los tests y la API de compra.
- **T3** — S3 — ruta: inline — estado: pendiente — actualizar tests rotos por el rework + añadir checks de las nuevas pestañas/forja (RED→GREEN).
- **T4** — S3 — ruta: inline — estado: pendiente — `--captura-tienda` inspeccionada + gate completo (import, smoke, regression, wave sim, boot).
- **T5** — S1-S3 — ruta: inline — estado: pendiente — docs (README/AGENTS) + commit + assess RDD + push final.

## Log

**L1** — Pedido original (verbatim):
> "D:\Orc Gladiators" necesitamos que se paresca a orc gladiators revenge de warcraft 3 pero sin caer en la similitud, hay que tener originalidad, vamos a mejorar visual, errores, bugs, ideas, optimizar el codigo, y borrar cosas huerfanas sin uso

**L2** — 2026-11-17 — Inspeccioné `captura_tienda.png`: tienda funcional pero lista plana de 26 objetos, ficha lateral, "SOLO FORJA" pasivo sin progreso visual. Elegido rework completo con pestañas y forja visual. Se descartó tienda de pantalla completa estilo LoL literal porque tapa la arena (es modal entre oleadas).

**L3** — 2026-11-17 — Explorador mapeando el código antes de tocar nada. Prioridad: no romper los nombres que leen los tests (`_cuadriculas`, `_grid`, `_campo_busqueda`, `_boton_arbol`) y la API de compra/forja de Arena.

---

Registro de entregas: T1 → ⏳ · T2 → [pendiente] · T3 → [pendiente] · T4 → [pendiente] · T5 → [pendiente]
