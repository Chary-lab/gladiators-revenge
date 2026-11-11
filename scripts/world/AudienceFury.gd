class_name AudienceFury
extends Node
## "Furia del Público": sistema anti-camping.
##
## Si el gladiador permanece más de `tiempo_limite` segundos dentro de un radio
## pequeño, el público se aburre: congela la ganancia de oro y lanza bolas de
## fuego desde las gradas durante `duracion_furia` segundos.
##
## Moverse lejos del ancla reinicia el contador; la rotación por el mapa es la
## única forma de evitar la penalización.

signal furia_iniciada(duracion: float)
signal furia_terminada

@export var tiempo_limite := 14.0
@export var duracion_furia := 9.0
@export var radio_quietud := 5.0
@export var intervalo_fuego := 1.3
@export var dano_fuego := 14.0

var congelando := false

var _jugador: GladiatorController
var _pool: ObjectPool
var _centro := Vector3.ZERO
var _radio_arena := 24.0
var _ancla := Vector3.ZERO
var _quieto := 0.0
var _restante := 0.0
var _cadencia := 0.0


func _ready() -> void:
	_pool = ObjectPool.new(Callable(AudienceFireball, "crear"))
	add_child(_pool)
	_pool.precalentar(8)


func iniciar(jugador: GladiatorController, centro: Vector3, radio_arena: float) -> void:
	_jugador = jugador
	_centro = centro
	_radio_arena = radio_arena
	if jugador != null:
		_ancla = jugador.global_position


func _process(delta: float) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		return

	if congelando:
		_restante -= delta
		_cadencia -= delta
		if _cadencia <= 0.0:
			_cadencia = intervalo_fuego
			_lanzar_fuego()
		if _restante <= 0.0:
			congelando = false
			_quieto = 0.0
			_ancla = _jugador.global_position
			furia_terminada.emit()
		return

	if _jugador.esta_muerto:
		return

	if _jugador.global_position.distance_to(_ancla) > radio_quietud:
		_ancla = _jugador.global_position
		_quieto = 0.0
		return

	_quieto += delta
	if _quieto >= tiempo_limite:
		_activar()


func _activar() -> void:
	congelando = true
	_restante = duracion_furia
	_cadencia = 0.0
	furia_iniciada.emit(duracion_furia)


func _lanzar_fuego() -> void:
	var angulo := randf() * TAU
	var origen := _centro + Vector3(cos(angulo), 0.0, sin(angulo)) * _radio_arena
	origen.y = 5.0
	var destino := _jugador.global_position + Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))

	var bola := _pool.obtener() as AudienceFireball
	bola.lanzar(origen, destino, _jugador, dano_fuego, _pool)
