extends SceneTree
## Micro-banco: coste de las funciones que se llaman al abrir la forja, la
## tienda y en cada tarjeta (no depende de fps ni de la GPU).
##
##   godot --headless --script res://tests/microbench.gd

func _initialize() -> void:
	# Catálogo de armas: primera construcción vs. llamada cacheada.
	var t0 := Time.get_ticks_usec()
	WeaponItem.crear_catalogo_base()
	var primera_ms := float(Time.get_ticks_usec() - t0) / 1000.0

	t0 = Time.get_ticks_usec()
	for i in 1000:
		WeaponItem.crear_catalogo_base()
	var cacheada_us := float(Time.get_ticks_usec() - t0) / 1000.0
	print("armas primera_ms=%.2f cacheada_us=%.3f" % [primera_ms, cacheada_us])

	# Búsqueda por id (cada chip del árbol y cada compra).
	t0 = Time.get_ticks_usec()
	var encontrados := 0
	for i in 2000:
		if ItemCatalog.obtener(&"nucleo_ferreo") != null:
			encontrados += 1
	print("obtener_us=%.2f encontrados=%d" % [
		float(Time.get_ticks_usec() - t0) / 2000.0, encontrados
	])

	# Listas de la tienda.
	t0 = Time.get_ticks_usec()
	for i in 200:
		ItemCatalog.vendibles()
		ItemCatalog.recetas()
	print("listas_us=%.2f" % (float(Time.get_ticks_usec() - t0) / 400.0))

	# Índice inverso del árbol de construcción (se construye una vez).
	t0 = Time.get_ticks_usec()
	ShopPanel._construir_padres()
	print("padres_us=%.2f" % float(Time.get_ticks_usec() - t0))
	quit(0)
