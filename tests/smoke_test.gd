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
	escena._comprar_cercana()
	_comprobar(jugador.arma_actual != null and jugador.arma_actual.clase == WeaponItem.Clase.BASTION, "comprar en la armería equipa el Bastión")
	_comprobar(escena.oro == oro_antes - pedestal.precio(), "la compra descuenta el oro")
	_comprobar(pedestal.vendida, "el pedestal queda marcado como vendido")
	_comprobar(jugador.estadisticas.fuerza_total > fuerza_antes, "el arma aplica bonos de atributo")

	# --- Oleada y combate automático --------------------------------------
	await _esperar_fisicas(360)  # 6 s: espera inicial + primer spawn
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
	await _esperar_fisicas(60)  # 1 s parado
	_comprobar(escena.esta_congelado(), "la Furia del Público castiga el camping")
	publico.tiempo_limite = 999.0  # evitar que se repita durante la comprobación
	await _esperar_fisicas(90)
	_comprobar(not escena.esta_congelado(), "el castigo termina y se puede volver a jugar")

	print("== %d pruebas, %d fallos ==" % [_pruebas, _fallos])
	quit(1 if _fallos > 0 else 0)
