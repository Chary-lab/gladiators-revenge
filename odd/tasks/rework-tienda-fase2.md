# Rework tienda fase 2 — ruta vertical, colores por categoría y undo

Rama: `main` (push al final) · Runner: `godot --headless --script res://tests/<suite>.gd` + capturas

## Specs

**S1** — Pedido del usuario (verbatim): "el arbol de contruccion no me convence en realidad, la estructura de la tienda aun la veo demaciado grande mucho espacios vacios que se puede ocupar mejor, los componenetes deberian ir antes y luego forja, consumibles deberia ser primero, y luego todos, clasificarlos tambien con colores, rojos consumibles, blancos complementos, epico morados recetas y legendarios los dorados amarrillo. aplica los colores de las tarjetas correctamente. tambien un boton de deshazer compra pero solo cuando la tienda esta abierta luego de la compra, si se sale de la tienda ya no puede volver a deshazer".

**S2** — Decisiones del usuario:
- Árbol → **ruta vertical clara** (pasos apilados, sin líneas que se cruzan, sin panel lateral repetido, ocupa mejor el espacio).
- Orden de pestañas: **CONSUMIBLES → COMPONENTES → FORJAR → TODOS**.
- Colores: **rojo=consumibles, blanco=componentes, morado=épico/recetas, dorado=legendarios**.
- Undo: **última compra**, botón visible sólo con la tienda abierta, se pierde al cerrar.

## Tasks

- **T1** — S1-S2 — ruta: inline — estado: en curso — mapear BuildTreePanel, `_carta`/`_pintar_carta`, flujo de compra y cierre de tienda.
- **T2** — S2 — ruta: inline — estado: pendiente — reordenar pestañas y aplicar colores por categoría en tarjetas y ficha.
- **T3** — S2 — ruta: inline — estado: pendiente — reemplazar grafo por ruta vertical en BuildTreePanel.
- **T4** — S2 — ruta: inline — estado: pendiente — undo de última compra con limpieza al cerrar (RED→GREEN).
- **T5** — S1-S2 — ruta: inline — estado: pendiente — reducir espacio vacío de la tienda; capturas + gate + docs + commit + push.

## Log

**L1** — Pedido original del frente 2 (verbatim en S1). Se respeta la restricción de no arte Warcraft y la paleta propia del repo.

**L2** — 2026-11-17 — Inspeccioné `captura_tienda.png` y `captura_arbol.png`. Árbol: grafo de 5 columnas con líneas que se cruzan, ficha lateral repetida y espacio vacío abajo. Colores actuales desordenados: poción verde, pergamino morado, componente azul. Elegido: ruta vertical + colores por categoría + undo.

---

Registro de entregas: T1 → ⏳ · T2 → [pendiente] · T3 → [pendiente] · T4 → [pendiente] · T5 → [pendiente]
