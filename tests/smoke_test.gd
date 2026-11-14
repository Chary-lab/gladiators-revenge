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

	# --- Forja de campeones: la clase se elige en su pantalla --------------
	var pedestales: Array = escena.get("_pedestales")
	_comprobar(pedestales.is_empty(), "la armería no deja pedestales de campeón en el mapa")
	var fuerza_antes := jugador.estadisticas.fuerza_total
	var oro_antes: int = escena.oro
	escena._al_elegir_campeon(&"bastion")
	_comprobar(
		jugador.arma_actual != null and jugador.arma_actual.clase == WeaponItem.Clase.BASTION,
		"elegir en la forja equipa el Bastión"
	)
	_comprobar(escena.oro == oro_antes, "elegir campeón no cuesta oro")
	_comprobar(jugador.estadisticas.fuerza_total > fuerza_antes, "el arma aplica bonos de atributo")
	var clase_fijada := jugador.arma_actual.clase
	escena._al_elegir_campeon(&"filo")
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
	var incremento_esperado := 4.0 * GladiatorStats.DANO_ATAQUE_POR_ATRIBUTO \
		* float(GladiatorStats.MULT_DANO_POR_CLASE[&"cetro"]) \
		* (1.0 + float(jugador.estadisticas.nivel - 1) * GladiatorStats.DANO_ESCALA_POR_NIVEL)
	_comprobar(
		is_equal_approx(dano_ataque_cetro_mas - dano_ataque_cetro, incremento_esperado),
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

	# El espíritu se dibuja translúcido y comparte materiales entre invocaciones:
	# duplicarlos por instancia costaba ~550 ms al liberarlo.
	var espiritu: Node3D = get_nodes_in_group("aliados")[0]
	var malla_espectral: MeshInstance3D = null
	var material_espectral: BaseMaterial3D = null
	for nodo in espiritu.find_children("*", "MeshInstance3D", true, false):
		var malla := nodo as MeshInstance3D
		var activo := malla.get_active_material(0)
		if activo is BaseMaterial3D and (activo as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
			malla_espectral = malla
			material_espectral = activo as BaseMaterial3D
			break
	_comprobar(material_espectral != null, "el espíritu se dibuja translúcido")
	var otro_espiritu := SpiritSummon.crear()
	escena.add_child(otro_espiritu)
	var material_repetido: BaseMaterial3D = null
	if malla_espectral != null:
		var gemela := otro_espiritu.find_child(malla_espectral.name, true, false) as MeshInstance3D
		if gemela != null:
			material_repetido = gemela.get_active_material(0) as BaseMaterial3D
	_comprobar(material_repetido != null and material_repetido == material_espectral, "los espíritus comparten materiales (no se duplican por instancia)")
	otro_espiritu.queue_free()

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

	# --- Sistema de diseño (ForjaTema) ------------------------------------
	var tema := ForjaTema.tema_global()
	_comprobar(
		tema.has_stylebox("normal", "Button") and tema.has_icon("grabber", "HSlider"),
		"el tema global estiliza botones y deslizadores"
	)
	var fuente_titulo := ForjaTema.fuente_titulo()
	_comprobar(
		fuente_titulo != null
		and fuente_titulo.has_char("Á".unicode_at(0))
		and fuente_titulo.has_char("ñ".unicode_at(0))
		and fuente_titulo.has_char("·".unicode_at(0)),
		"la tipografía de títulos cubre acentos, eñe y el punto medio"
	)
	_comprobar(
		(hud.get("_barra_superior") as Panel) != null
		and hud.get("_ficha_jugador") != null
		and hud.get("_ficha_jugador").get_parent() == hud.get("_barra_superior"),
		"la barra superior incluye la ficha del jugador"
	)

	# --- Sala de espera: elegir campeón acorta la cuenta atrás ------------
	var olas := WaveManager.new()
	olas.iniciar([jugador], null, [], null)
	escena.add_child(olas)
	var antes_prep := olas.tiempo_preparacion()
	olas.acortar_preparacion(2.0)
	_comprobar(
		antes_prep > 2.0 and olas.tiempo_preparacion() <= 2.0 and olas.en_espera(),
		"acortar_preparacion recorta la espera sin salir de la sala"
	)
	olas.queue_free()

	# --- Apodo y ficha del jugador ---------------------------------------
	_comprobar(
		Perfil.normalizar("  Orco  Épico  ") == "Orco Épico",
		"el apodo se limpia y conserva acentos"
	)
	_comprobar(
		Perfil.normalizar("a<b>c/d").find("<") == -1 and Perfil.normalizar("x").length() == 1,
		"el apodo rechaza símbolos raros"
	)
	hud.establecer_bajas(3)
	_comprobar((hud.get("_bajas_jugador") as Label).text == "3", "la ficha muestra los enemigos abatidos")
	var bajas_antes: int = oleadas.bajas
	oleadas.al_morir_enemigo(0)
	_comprobar(oleadas.bajas == bajas_antes + 1, "cada muerte suma una baja")

	# --- Tienda simple: una lista y dos modos -----------------------------
	hud.alternar_tienda()
	await process_frame
	var panel_tienda = hud.get("_tienda")
	var grid: GridContainer = panel_tienda.get("_grid")
	var cartas_mercado := grid.get_child_count()
	_comprobar(cartas_mercado == ItemCatalog.vendibles().size(), "la tienda lista lo vendible en una sola cuadrícula")
	_comprobar(panel_tienda.get("_chip_vender") != null, "la tienda tiene el modo VENDER")
	panel_tienda._cambiar_modo(true)
	await process_frame
	var cartas_venta := grid.get_child_count()
	_comprobar(cartas_venta >= 1, "el modo VENDER lista las ranuras con objeto")
	panel_tienda._cambiar_modo(false)
	await process_frame

	# --- Pausa: los paneles no dejan la partida congelada ------------------
	hud.alternar_tienda()
	await process_frame
	hud.alternar_talentos()
	await process_frame
	hud.cerrar_talentos()
	await process_frame
	_comprobar(not paused and not Pausa.hay_paneles(), "los paneles no dejan la partida en pausa")
	hud.alternar_tienda()
	await process_frame
	hud.cerrar_tienda()
	await process_frame
	hud.cerrar_tienda()
	await process_frame
	hud.alternar_tienda()
	await process_frame
	hud.cerrar_tienda()
	await process_frame
	_comprobar(not paused, "cerrar dos veces la tienda no descuadra la pausa")

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


	# --- Balance: daño mín-máx, ritmo de ataque y arquetipos ---
	var stats := GladiatorStats.new()
	stats.configurar_clase(&"bastion")
	var rango_base := stats.rango_dano_ataque(20.0, &"fuerza")
	_comprobar(rango_base.x < rango_base.y, "el ataque básico tiene daño mínimo y máximo")
	_comprobar(
		is_equal_approx(rango_base.x, round(rango_base.y / (1.0 + GladiatorStats.DANO_VARIANZA) * (1.0 - GladiatorStats.DANO_VARIANZA)))
		or rango_base.x < stats.escalar_ataque_principal(20.0, &"fuerza"),
		"el mínimo queda por debajo de la media del golpe"
	)
	stats.fuerza += 10
	var rango_fuerte := stats.rango_dano_ataque(20.0, &"fuerza")
	_comprobar(rango_fuerte.x > rango_base.x and rango_fuerte.y > rango_base.y, "subir Fuerza sube el daño mínimo y el máximo")
	stats.agilidad = 0
	stats.nivel = 1
	_comprobar(
		is_equal_approx(stats.velocidad_ataque, GladiatorStats.VEL_ATAQUE_BASE),
		"sin Agilidad ni niveles el campeón ataca al ritmo base (0.15/s)",
	)
	var vel_antes := stats.velocidad_ataque
	stats.agilidad = 40
	_comprobar(stats.velocidad_ataque > vel_antes, "la Agilidad sube la velocidad de ataque")
	_comprobar(
		is_equal_approx(GladiatorStats.new().salud_maxima, GladiatorStats.VIDA_BASE + 10.0 * GladiatorStats.VIDA_POR_FUERZA),
		"la vida base sale solo de Fuerza y de la constante VIDA_BASE",
	)

	# --- Oleadas: 20 perfiles distintos y jefes en 5/10/15/20 ---
	var perfiles_ok := BalanceOlas.PERFILES.size() == 20
	for indice in BalanceOlas.PERFILES.size():
		var perfil: Dictionary = BalanceOlas.perfil(indice + 1)
		if perfil["tipos"].is_empty():
			perfiles_ok = false
		for tipo in perfil["tipos"]:
			if not BalanceOlas.TIPOS_VALIDOS.has(tipo):
				perfiles_ok = false
	_comprobar(perfiles_ok, "las 20 oleadas tienen perfil con arquetipos válidos")
	_comprobar(
		BalanceOlas.perfil(5)["jefe"] == "caballero" and BalanceOlas.perfil(10)["jefe"] == "liche" and BalanceOlas.perfil(20)["jefe"] == "liche",
		"los jefes 5/10/20 salen del perfil de la oleada"
	)
	_comprobar(
		BalanceOlas.cantidad(20) > BalanceOlas.cantidad(1) * 3 and BalanceOlas.cantidad(1) >= 8,
		"la cantidad de enemigos crece con la oleada"
	)
	var tipos_vistos: Array = []
	for i in 40:
		var elegido := BalanceOlas.elegir_tipo(BalanceOlas.perfil(9))
		if not tipos_vistos.has(elegido):
			tipos_vistos.append(elegido)
	_comprobar(not tipos_vistos.is_empty() and tipos_vistos.all(func(t): return BalanceOlas.TIPOS_VALIDOS.has(t)), "el perfil de una oleada mixta reparte arquetipos válidos")
	var arquetipos_ok := true
	for tipo in BalanceOlas.TIPOS_VALIDOS:
		if not ArenaEnemy.ARQUETIPOS.has(tipo) or not ArenaEnemy.VISUALES.has(tipo):
			arquetipos_ok = false
	_comprobar(arquetipos_ok, "cada arquetipo tiene estadísticas y modelo visual")
	# --- Fin de partida ----------------------------------------------------
	escena._finalizar("DERROTA", "prueba de cierre")
	_comprobar(escena.terminado, "terminar cierra la partida")
	var panel = escena.get("_hud").get("_talentos")
	_comprobar(panel != null and not panel.visible, "el panel de talentos se cierra al terminar")

	# --- Sala online (botón CREAR SALA) -----------------------------------
	var menu := MenuRed.new()
	_comprobar(
		menu.has_signal("crear_sala") and menu.has_method("estado_creacion") and menu.has_method("sala_fallida"),
		"el menú de red ofrece crear una sala pública"
	)
	_comprobar(menu.get("_url") == null, "el menú ya no pide una URL a mano")
	menu.free()
	_comprobar(
		escena.get("_hud").has_method("establecer_lobby"),
		"el HUD tiene la sala de espera con cuenta atrás"
	)
	# --- Controles táctiles -------------------------------------------------
	var tactil := TouchControls.new()
	tactil.configurar(null)
	_comprobar(
		tactil.has_signal("habilidad") and tactil.has_signal("interactuar") and tactil.has_signal("detener"),
		"los controles táctiles exponen habilidades e interacción"
	)
	_comprobar(
		(tactil.get("_botones") as Array).size() == 4,
		"los controles táctiles dibujan Q/W/E/R"
	)
	_comprobar(
		(tactil.get("_base") as Panel) != null and (tactil.get("_perilla") as Panel) != null,
		"el joystick táctil dibuja base y perilla"
	)
	_comprobar(
		(tactil.get("_aro") as ForjaTema.AroRunas) != null,
		"el joystick dibuja el aro de runas"
	)
	_comprobar(
		(tactil.get("_velos") as Array).size() == 4 and (tactil.get("_cd_textos") as Array).size() == 4,
		"las habilidades táctiles muestran enfriamiento radial y segundos"
	)
	_comprobar(tactil.has_signal("pausa"), "el HUD táctil tiene botón de pausa")
	var perfiles: Array = escena._perfiles_campeon()
	_comprobar(perfiles.size() == 3, "la forja de campeones ofrece las tres clases")
	var primer_perfil: Dictionary = perfiles[0]
	_comprobar(
		float(primer_perfil.get("vida", 0.0)) > 0.0 and float(primer_perfil.get("dano_max", 0.0)) > 0.0,
		"cada campeón llega con estadísticas calculadas"
	)
	var seleccion := SeleccionCampeon.new()
	escena.add_child(seleccion)
	seleccion.configurar(perfiles, &"")
	_comprobar(
		(seleccion.get("_emblemas") as Array).size() == 3 and seleccion.get("_marca") != null,
		"la pantalla de campeón monta emblemas y ficha"
	)
	_comprobar(
		seleccion.get("_vitrina") != null and seleccion.get("_btn_elegir") != null,
		"la pantalla de campeón tiene vitrina 3D y botón de elegir"
	)
	seleccion.free()
	tactil.free()
	var punto: Variant = escena._punto_habilidad()
	_comprobar(punto is Vector3, "en táctil la habilidad apunta a un punto del mundo")

	# --- Ajustes y actualizador --------------------------------------------
	var ajustes := Ajustes.new()
	ajustes.volumen = 0.5
	ajustes.escala_tactil = 1.2
	ajustes.guardar()
	var releidos := Ajustes.cargar()
	_comprobar(
		is_equal_approx(releidos.volumen, 0.5) and is_equal_approx(releidos.escala_tactil, 1.2),
		"los ajustes se guardan y se vuelven a leer"
	)
	var actualizador := Actualizador.new()
	_comprobar(actualizador._es_mas_nueva("1.6.0", "1.5.0"), "el actualizador detecta una versión más nueva")
	_comprobar(not actualizador._es_mas_nueva("1.5.0", "1.5.0"), "el actualizador no molesta si ya está al día")
	_comprobar(not actualizador._es_mas_nueva("1.4.9", "1.5.0"), "el actualizador no retrocede de versión")
	actualizador.free()

	var gestor_oleadas = escena.get("_oleadas")
	_comprobar(
		gestor_oleadas != null and gestor_oleadas.has_method("en_espera") and gestor_oleadas.has_method("asegurar_preparacion"),
		"las oleadas exponen el estado de espera y su extensión"
	)
	var creador := CrearSala.new()
	_comprobar(
		creador._nombre_binario().begins_with("cloudflared"),
		"el creador de sala resuelve el binario de cloudflared"
	)
	_comprobar(creador.url_publica().is_empty(), "la sala no anuncia URL antes de abrir el túnel")
	creador.free()

	# --- Lobby online ------------------------------------------------------
	var supabase := Supabase.new()
	_comprobar(
		supabase.configurado_cliente(),
		"Supabase queda configurado al construirse, sin esperar un fotograma"
	)
	supabase.free()

	# --- Salas en la nube --------------------------------------------------
	var remota := SalaRemota.new()
	# Las lambdas capturan por valor: se usa una caja para leer el motivo.
	var caja := [""]
	remota.fallo.connect(func(m: String) -> void: caja[0] = m)
	remota.configurar("")
	remota.crear()
	_comprobar(
		str(caja[0]).contains("servidor de salas"),
		"sin servidor de salas, crear sala avisa del error"
	)
	remota.free()
	var maestro := MaestroSalas.new()
	_comprobar(
		maestro.has_method("iniciar") and maestro.has_method("cerrar"),
		"el maestro de salas expone iniciar y cerrar"
	)
	# La URL pública de la sala debe salir en wss://, no en https://.
	maestro.set("_base_publica", "https://app.fly.dev")
	_comprobar(
		maestro.url_sala(2) == "wss://app.fly.dev/sala/2",
		"el maestro convierte la URL pública a wss para la sala"
	)
	maestro.set("_base_publica", "http://localhost:9000/")
	_comprobar(
		maestro.url_sala(1) == "ws://localhost:9000/sala/1",
		"el maestro también acepta http:// para pruebas locales"
	)
	maestro.free()

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
