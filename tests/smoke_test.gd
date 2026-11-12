extends SceneTree
## Prueba de humo sin editor: construye la arena real y ejercita los sistemas
## núcleo (armas, oleadas, combate automático, jefe, estandarte y anti-camping).
##
## Uso: godot --headless --path . --script res://tests/smoke_test.gd

var _fallos := 0
var _pruebas := 0


func _initialize() -> void:
	_ejecutar()


func _comprobar(condicion: bool, texto: String) -> void:
	_pruebas += 1
	if condicion:
		print("  OK    ", texto)
	else:
		_fallos += 1
		printerr("  FALLO ", texto)


func _esperar_fisicas(cantidad: int) -> void:
	for i in cantidad:
		await physics_frame


func _ejecutar() -> void:
	print("== Smoke test: Gladiators Revenge ==")
	var sonidos_ok := true
	for nombre in Sfx.RUTAS:
		if not ResourceLoader.exists(Sfx.RUTAS[nombre]):
			sonidos_ok = false
			printerr("  falta audio: ", Sfx.RUTAS[nombre])
	_comprobar(sonidos_ok, "los efectos de audio CC0 existen")
	var escena = load("res://scenes/main.tscn").instantiate()
	root.add_child(escena)
	await process_frame
	await process_frame

	var jugador: GladiatorController = escena.get("_jugador")
	var bandera: RebellionBanner = escena.get("_bandera")
	var oleadas: WaveManager = escena.get("_oleadas")
	var publico: AudienceFury = escena.get("_publico")

	_comprobar(jugador != null and bandera != null and oleadas != null, "la arena construye jugador, estandarte y oleadas")
	_comprobar(escena.get("_hud") != null and escena.get("_camara") != null, "HUD y cámara presentes")
	_comprobar(oleadas.total_oleadas == 20, "el bucle tiene 20 oleadas")

	# --- Armas -------------------------------------------------------------
	var catalogo := WeaponItem.crear_catalogo_base()
	_comprobar(catalogo.size() == 3, "catálogo base con 3 armas")
	for arma in catalogo:
		_comprobar(arma.es_valida(), "arma válida: %s" % arma.nombre)
	_comprobar(WeaponItem.crear_prisionero().es_valida(), "kit de prisionero válido")

	# --- Armería: comprar define la clase ---------------------------------
	var pedestales: Array = escena.get("_pedestales")
	var pedestal: ArmoryPedestal = pedestales[0]
	var fuerza_antes := jugador.estadisticas.fuerza_total
	var oro_antes: int = escena.oro
	jugador.global_position = pedestal.global_position + Vector3(0.0, 0.0, 1.6)
	escena._interactuar_cercano()
	_comprobar(jugador.arma_actual != null and jugador.arma_actual.clase == WeaponItem.Clase.BASTION, "comprar en la armería equipa el Bastión")
	_comprobar(escena.oro == oro_antes, "elegir campeón no cuesta oro")
	_comprobar(pedestal.vendida, "el pedestal queda marcado como elegido")
	_comprobar(jugador.estadisticas.fuerza_total > fuerza_antes, "el arma aplica bonos de atributo")
	var clase_fijada := jugador.arma_actual.clase
	_comprobar(
		pedestales[1].vendida and pedestales[2].vendida,
		"las otras clases desaparecen de la selección al elegir campeón"
	)
	jugador.global_position = pedestales[1].global_position + Vector3(0.0, 0.0, 1.6)
	escena._interactuar_cercano()
	_comprobar(
		jugador.arma_actual.clase == clase_fijada,
		"solo se puede escoger un tipo por partida"
	)

	# --- Objetos, inventario y forja --------------------------------------
	var catalogo_objetos := ItemCatalog.crear_catalogo()
	var ids := {}
	var validos := true
	for objeto in catalogo_objetos:
		if objeto == null or objeto.id == &"" or ids.has(objeto.id):
			validos = false
			break
		ids[objeto.id] = true
		if objeto.es_equipo() and objeto.bonificaciones.is_empty():
			validos = false
	_comprobar(validos and catalogo_objetos.size() >= 20, "catálogo de objetos válido y sin ids duplicados")

	var inventario := jugador.inventario
	_comprobar(inventario != null and inventario.tiene(&"pocion_vida"), "el gladiador empieza con una poción")
	jugador.salud_actual = maxf(1.0, jugador.estadisticas.salud_maxima - 100.0)
	var vida_antes_pocion := jugador.salud_actual
	_comprobar(inventario.usar(0, jugador), "la poción de vida se usa")
	_comprobar(jugador.salud_actual > vida_antes_pocion, "la poción cura al gladiador")
	_comprobar(not inventario.usar(0, jugador), "las pociones comparten enfriamiento")

	escena.oro = 5000
	var brasa := ItemCatalog.obtener(&"brasa_forja")
	var placa := ItemCatalog.obtener(&"placa_oxidada")
	var piel := ItemCatalog.obtener(&"piel_basalto")
	jugador.global_position = Vector3(26.0, 0, 8.0)
	_comprobar(escena.comprar_objeto(brasa), "se compra un componente en la tienda")
	_comprobar(inventario.tiene(&"brasa_forja"), "el componente entra en la mochila")
	_comprobar(escena.comprar_objeto(placa), "se compra el segundo componente")
	_comprobar(inventario.tiene(&"nucleo_ferreo") and not inventario.tiene(&"brasa_forja"), "la forja automática crea el objeto intermedio")
	_comprobar(escena.comprar_objeto(piel), "se compra la piel y se encadena la receta")
	_comprobar(inventario.tiene(&"corazon_obsidiana"), "la cadena de forja llega al legendario")
	var indice_corazon := -1
	for i in inventario.ranuras.size():
		var ranura: Dictionary = inventario.ranuras[i]
		var objeto: ItemData = ranura["item"]
		if objeto != null and objeto.id == &"corazon_obsidiana":
			indice_corazon = i
	_comprobar(indice_corazon >= 0, "el legendario ocupa una ranura activa")
	if indice_corazon >= 0:
		_comprobar(inventario.usar(indice_corazon, jugador), "la habilidad activa del legendario se lanza")
		_comprobar(jugador.escudo_actual > 0.0, "el Corazón de Obsidiana otorga escudo")

	jugador.mana_actual = jugador.estadisticas.mana_maximo
	var banda: RebellionBanner = escena.get("_bandera")
	jugador.global_position = Vector3(0.0, 0.0, 2.0)
	banda.recibir_dano(120.0, GladiatorStats.TIPO_VERDADERO)
	var vida_banda := banda.salud_actual
	var cuerno := ItemCatalog.obtener(&"cuerno_rebelion")
	_comprobar(jugador.lanzar_habilidad_item(cuerno.habilidad), "el Cuerno de la Rebelión se activa")
	_comprobar(banda.salud_actual > vida_banda, "el Grito de Guerra cura el estandarte")
	_comprobar(float(jugador.get("_buff_ataque")) > 0.0, "el Grito de Guerra acelera al gladiador")

	escena.oro = 200

	# --- Talentos de combate ---------------------------------------------
	jugador.otorgar_puntos_rojos(12)
	var muro := jugador.arma_actual.habilidades[0]
	var talento_radio := muro.talentos[0]
	var talento_duracion := muro.talentos[1]
	_comprobar(not jugador.desbloquear_talento(talento_duracion), "un talento exige su requisito")
	_comprobar(jugador.desbloquear_talento(talento_radio), "compra el primer rango de talento")
	_comprobar(jugador.rango_talento(talento_radio.id) == 1, "el rango de talento sube")
	_comprobar(jugador.desbloquear_talento(talento_duracion), "se desbloquea el talento dependiente")
	_comprobar(jugador.puntos_rojos == 7, "los puntos rojos se descuentan")

	var cetro := WeaponItem.crear_catalogo_base()[2]
	jugador.equipar_arma(cetro)
	_comprobar(cetro.atributo_principal == &"inteligencia", "el Cetro escala con Inteligencia")
	var dano_ataque_cetro := jugador.estadisticas.escalar_ataque_principal(
		cetro.dano_ataque_base, cetro.atributo_principal
	)
	jugador.estadisticas.inteligencia += 4
	var dano_ataque_cetro_mas := jugador.estadisticas.escalar_ataque_principal(
		cetro.dano_ataque_base, cetro.atributo_principal
	)
	_comprobar(
		is_equal_approx(dano_ataque_cetro_mas, dano_ataque_cetro + 4.0),
		"subir Inteligencia aumenta el daño de ataque básico del Cetro"
	)
	jugador.otorgar_puntos_rojos(6)
	var estandarte := cetro.habilidades[1]
	jugador.desbloquear_talento(estandarte.talentos[0])
	jugador.desbloquear_talento(estandarte.talentos[0])
	var efecto := AbilityEffect.new()
	escena.add_child(efecto)
	efecto.configurar(estandarte, jugador)
	_comprobar(is_equal_approx(float(efecto.get("_radio")), 7.0), "el talento amplía el radio por rango")
	efecto.queue_free()

	jugador.estadisticas.nivel = 6
	jugador._sincronizar_desbloqueos()
	jugador.mana_actual = jugador.estadisticas.mana_maximo
	_comprobar(jugador.intentar_habilidad(3), "el cetro lanza la ultimate")
	_comprobar(not get_nodes_in_group("aliados").is_empty(), "la ultimate invoca un espíritu aliado")
	_comprobar(get_nodes_in_group("aliados")[0].is_in_group("aliados"), "el espíritu pertenece al equipo aliado")
	_comprobar(not get_nodes_in_group("aliados")[0].is_in_group("enemigos"), "el espíritu no se registra como enemigo")
	for aliado in get_nodes_in_group("aliados"):
		aliado.queue_free()

	# --- Crecimiento por nivel y subida aleatoria de habilidades ----------
	var nivel_previo := jugador.estadisticas.nivel
	var fuerza_base_antes := jugador.estadisticas.fuerza
	var agilidad_base_antes := jugador.estadisticas.agilidad
	var inteligencia_base_antes := jugador.estadisticas.inteligencia
	var rangos_antes := 0
	for indice in 4:
		var hab := jugador.arma_actual.obtener_habilidad(indice)
		if hab != null:
			rangos_antes += jugador.rango_habilidad(hab.id)
	var xp_nivel := jugador.estadisticas.experiencia_requerida
	jugador.otorgar_experiencia(xp_nivel)
	var rangos_despues := 0
	for indice in 4:
		var hab := jugador.arma_actual.obtener_habilidad(indice)
		if hab != null:
			rangos_despues += jugador.rango_habilidad(hab.id)
	_comprobar(jugador.estadisticas.nivel == nivel_previo + 1, "otorgar XP sube de nivel")
	_comprobar(
		jugador.estadisticas.fuerza > fuerza_base_antes
		and jugador.estadisticas.agilidad > agilidad_base_antes
		and jugador.estadisticas.inteligencia > inteligencia_base_antes,
		"el crecimiento de clase sube las estadísticas base"
	)
	_comprobar(rangos_despues == rangos_antes + 1, "una habilidad sube de nivel al azar al subir de nivel")

	# --- Oleada y combate automático --------------------------------------
	oleadas.espera_inicial = 0.3
	oleadas.duracion_entrada = 0.3
	oleadas.set("_temporizador", 0.3)
	await _esperar_fisicas(360)  # preparación + entrada + primer spawn
	_comprobar(oleadas.oleada_actual == 1, "la oleada 1 arranca sola")
	var enemigos := get_nodes_in_group("enemigos")
	_comprobar(not enemigos.is_empty(), "la oleada genera enemigos")

	if not enemigos.is_empty():
		var enemigo := enemigos[0] as ArenaEnemy
		# Se sube la vida para que el enemigo no muera y el pool lo recicle a
		# mitad de la comprobación (un enemigo de oleada 1 cae en dos golpes).
		enemigo.salud_maxima = 400.0
		enemigo.salud_actual = 400.0
		enemigo.global_position = jugador.global_position + Vector3(1.4, 0.0, 0.0)
		var vida_antes := enemigo.salud_actual
		await _esperar_fisicas(150)  # 2,5 s de ataque básico
		_comprobar(enemigo.salud_actual < vida_antes or not enemigo.activo, "el ataque básico daña al enemigo")

	# --- Estandarte --------------------------------------------------------
	var vida_bandera := bandera.salud_actual
	bandera.recibir_dano(120.0)
	_comprobar(bandera.salud_actual < vida_bandera, "el estandarte recibe daño")

	# --- Jefe: fases de furia ---------------------------------------------
	var jefe := ArenaBossAI.crear()
	escena.add_child(jefe)
	jefe.set_physics_process(false)  # aislar la prueba de la persecución
	var niveles: Array[int] = []
	jefe.furia_activada.connect(func(nivel: int) -> void: niveles.append(nivel))
	var vida_base := jefe.salud_maxima
	jefe.configurar_para_ronda(5)
	_comprobar(jefe.salud_maxima > vida_base, "la ronda 5 escala la vida del jefe")

	jefe.recibir_dano(jefe.salud_actual - jefe.salud_maxima * 0.74)
	_comprobar(jefe.nivel_furia == 1, "Furia 1 al 75 % de vida")
	_comprobar(is_equal_approx(jefe.multiplicador_velocidad, jefe.multiplicador_velocidad_furia), "Furia 1 acelera al jefe")
	_comprobar(niveles == [1], "emite furia_activada(1) una sola vez")

	jefe.aplicar_aturdimiento(1.0)
	_comprobar(jefe.estado == ArenaBossAI.Estado.ATURDIDO, "antes de Furia 2 el jefe es aturdible")

	jefe.recibir_dano(jefe.salud_actual - jefe.salud_maxima * 0.49)
	_comprobar(jefe.nivel_furia == 2, "Furia 2 al 50 % de vida")
	_comprobar(jefe.inmune_aturdimiento and jefe.usa_ataques_area, "Furia 2 da inmunidad y ataques en área")
	jefe.aplicar_aturdimiento(1.0)
	_comprobar(jefe.estado != ArenaBossAI.Estado.ATURDIDO, "Furia 2 ignora el aturdimiento")
	_comprobar(niveles == [1, 2], "las fases se activan en orden")

	# --- Anti-camping ------------------------------------------------------
	publico.tiempo_limite = 0.6
	publico.duracion_furia = 1.0
	publico.establecer_combate(true)
	await _esperar_fisicas(60)  # 1 s parado
	_comprobar(escena.esta_congelado(), "la Furia del Público castiga el camping")
	publico.tiempo_limite = 999.0  # evitar que se repita durante la comprobación
	await _esperar_fisicas(90)
	_comprobar(not escena.esta_congelado(), "el castigo termina y se puede volver a jugar")

	# --- Consola inferior e iconos ----------------------------------------
	var hud = escena.get("_hud")
	_comprobar(hud.get("_retrato") != null, "la consola tiene retrato 3D")
	_comprobar((hud.get("_comando_botones") as Array).size() == 8, "la parrilla tiene 8 comandos y 4 habilidades")
	_comprobar((hud.get("_inventario_botones") as Array).size() == 6, "el inventario conserva 6 ranuras")
	_comprobar(IconStudio.obtener(&"atacar", IconStudio.CATEGORIA_COMANDO) != null, "IconStudio entrega iconos en headless")
	_comprobar(hud.get("_revive_panel") != null, "la consola tiene panel de revivir")
	_comprobar(hud.get("_tooltip") != null, "la consola tiene tooltip rico")

	# --- Glifos: la fuente por defecto no dibuja ◆ ✔ ✘ (salen como cajas) ---
	var fuente: Font = ThemeDB.fallback_font
	var glifos_ok := true
	for code in [0x25C6, 0x2714, 0x2718]:
		if fuente.has_char(code):
			continue
		for ruta in ["res://scripts/ui/ShopPanel.gd", "res://scripts/ui/ArenaHUD.gd"]:
			if FileAccess.get_file_as_string(ruta).contains(String.chr(code)):
				glifos_ok = false
	_comprobar(glifos_ok, "la UI no usa glifos que la fuente no dibuja")

	# --- Tienda: pestañas y recetario ---
	hud.alternar_tienda()
	await process_frame
	var panel_tienda = hud.get("_tienda")
	var grid: GridContainer = panel_tienda.get("_lista")
	var cartas_mercado := grid.get_child_count()
	panel_tienda._cambiar_tab(1)
	await process_frame
	var cartas_recetas := grid.get_child_count()
	_comprobar(cartas_mercado == ItemCatalog.vendibles().size(), "la pestaña MERCADO lista solo lo vendible")
	_comprobar(cartas_recetas == ItemCatalog.recetas().size(), "la pestaña RECETARIO lista todas las recetas")
	_comprobar(cartas_recetas > cartas_mercado, "el recetario muestra los objetos forjables")

	# --- Iconos 3D de los objetos nuevos ---
	var nuevos := [&"armadura_brasas", &"anillo_vampiro", &"corazon_fenix", &"capa_comandante", &"guadana_verdugo_ancestral"]
	var modelos_ok := true
	for id in nuevos:
		var modelo := ItemModelFactory.crear(id)
		if _contar_mallas(modelo) < 3:
			modelos_ok = false
		modelo.free()
	_comprobar(modelos_ok, "los objetos nuevos tienen miniatura 3D propia")
	_comprobar(
		is_equal_approx(IconStudio.color_para(IconStudio.CATEGORIA_OBJETO, &"capa_comandante").b, IconStudio.COLOR_LEGENDARIO.b),
		"los legendarios nuevos usan el tinte dorado"
	)
	hud.cerrar_tienda()
	await process_frame

	# --- Revivir cooperativo conserva el equipo ---------------------------
	var pociones_antes := jugador.inventario.contar(&"pocion_vida")
	jugador.esta_muerto = true
	jugador.revivir_red(jugador.global_position, 0.6)
	_comprobar(not jugador.esta_muerto, "revivir devuelve al gladiador al combate")
	_comprobar(jugador.salud_actual > 0.0, "revivir restaura vida")
	_comprobar(
		jugador.inventario.contar(&"pocion_vida") == pociones_antes,
		"revivir conserva el inventario"
	)

	# --- Auras de objetos épicos y legendarios -----------------------------
	var epicos := 0
	var auras_ok := true
	for item in ItemCatalog.crear_catalogo():
		if item.rareza == ItemData.Rareza.EPICO:
			epicos += 1
			if item.aura.is_empty():
				auras_ok = false
	_comprobar(epicos >= 3 and auras_ok, "el catálogo trae objetos épicos con aura")

	var autorreceta := false
	for receta in ItemCatalog.recetas():
		if receta.receta.has(receta.id):
			autorreceta = true
	_comprobar(not autorreceta, "ninguna receta se pide a sí misma")

	var base_aura: Vector3 = jugador.global_position
	var portador: GladiatorController = escena._instanciar_gladiador(base_aura + Vector3(2.0, 0.0, 0.0), 7)
	var lejano: GladiatorController = escena._instanciar_gladiador(base_aura + Vector3(60.0, 0.0, 0.0), 8)
	portador.inventario.agregar(ItemCatalog.obtener(&"anillo_vampiro"))
	lejano.inventario.agregar(ItemCatalog.obtener(&"guadana_verdugo_ancestral"))
	await process_frame
	_comprobar(is_equal_approx(portador.bono_aura(&"robo_vida_aliados"), 0.05), "el portador recibe su propia aura")
	_comprobar(is_equal_approx(portador.bono_aura(&"dano_aliados"), 0.0), "un aliado lejano no aporta su aura")
	lejano.global_position = portador.global_position + Vector3(2.0, 0.0, 0.0)
	await process_frame
	_comprobar(is_equal_approx(portador.bono_aura(&"dano_aliados"), 0.20), "un aliado cercano aporta su aura")
	_comprobar(is_equal_approx(portador.bono_aura(&"robo_vida_aliados"), 0.05), "las auras de distintas claves no se mezclan")
	portador.queue_free()
	lejano.queue_free()
	await process_frame

	# Cadena de forja: el último ingrediente crea la épica y su aura
	var fabricante: GladiatorController = escena._instanciar_gladiador(Vector3(24.0, 0.0, 0.0), 9)
	fabricante.inventario.agregar(ItemCatalog.obtener(&"nucleo_ferreo"))
	escena.game_state.oro = 4000
	var forjado: bool = escena.comprar_para(fabricante, ItemCatalog.obtener(&"raiz_savia"))
	_comprobar(
		forjado and fabricante.inventario.contar(&"armadura_brasas") == 1,
		"comprar el último ingrediente forja la Armadura de Brasas"
	)
	_comprobar(
		is_equal_approx(fabricante.bono_aura(&"dano_aliados"), 0.10),
		"la épica forjada irradia su aura de daño"
	)
	fabricante.queue_free()
	await process_frame

	# --- Fin de partida ----------------------------------------------------
	escena._finalizar("DERROTA", "prueba de cierre")
	_comprobar(escena.terminado, "terminar cierra la partida")
	var panel = escena.get("_hud").get("_talentos")
	_comprobar(panel != null and not panel.visible, "el panel de talentos se cierra al terminar")

	print("== %d pruebas, %d fallos ==" % [_pruebas, _fallos])
	Sfx.liberar()
	quit(1 if _fallos > 0 else 0)

## Cuenta las mallas de una miniatura 3D (para detectar el icono genérico).
func _contar_mallas(nodo: Node) -> int:
	var total := 0
	if nodo is MeshInstance3D:
		total += 1
	for hijo in nodo.get_children():
		total += _contar_mallas(hijo)
	return total
