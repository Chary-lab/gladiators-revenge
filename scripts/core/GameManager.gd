extends Node
## Autoload GameManager — máquina de estados global del juego.
##
## Fase 1 del rework: define los estados, las transiciones válidas y emite
## EventBus.estado_cambiado. NO toca `get_tree().paused` NI llama a `Pausa`:
## hoy la tienda y los talentos ya usan el contador estático `Pausa` y hacerlo
## aquí también duplicaría el conteo. En la Fase 2 se instalará el puente
## `EventBus.pausa_solicitada` -> `Pausa.abrir()/cerrar()` y se retirará el
## llamado directo de los paneles, en el mismo commit en que se conecten.
##
## Orden de autoload: EventBus primero, GameManager segundo.

enum Estado { MENU, PLAYING, SHOP, PAUSED, GAMEOVER }

signal estado_cambiado(nuevo_estado: int, estado_anterior: int, motivo: StringName)

var estado: Estado = Estado.MENU
var _motivo_actual: StringName = &""


func _ready() -> void:
	# El bus es la entrada única: cualquier sistema puede pedir el fin de la
	# partida o un reintento sin conocer este autoload.
	EventBus.partida_terminada.connect(_al_partida_terminada)
	EventBus.reintentar_solicitado.connect(reiniciar_partida)
	EventBus.salir_lobby_solicitado.connect(volver_al_menu)


# --- API pública ------------------------------------------------------------

func cambiar_estado(nuevo: Estado, motivo: StringName = &"") -> bool:
	var anterior: Estado = estado
	if nuevo == anterior:
		return false
	if not _transicion_permitida(anterior, nuevo):
		push_warning("GameManager: transición rechazada %s -> %s (%s)" % [
			estado_como_texto(anterior), estado_como_texto(nuevo), String(motivo)
		])
		return false

	estado = nuevo
	_motivo_actual = motivo
	estado_cambiado.emit(int(nuevo), int(anterior), motivo)
	EventBus.estado_cambiado.emit(int(nuevo), int(anterior), motivo)
	EventBus.pausa_solicitada.emit(_mundo_debe_pausarse(nuevo), motivo)
	return true


func iniciar_partida(es_local: bool = true) -> bool:
	if not cambiar_estado(Estado.PLAYING, &"iniciar_partida"):
		return false
	EventBus.partida_iniciada.emit(es_local)
	return true


func abrir_tienda() -> bool:
	return cambiar_estado(Estado.SHOP, &"tienda")


func cerrar_tienda() -> bool:
	return cambiar_estado(Estado.PLAYING, &"cerrar_tienda")


func pausar() -> bool:
	return cambiar_estado(Estado.PAUSED, &"pausa")


func reanudar() -> bool:
	return cambiar_estado(Estado.PLAYING, &"reanudar")


func terminar_partida(titulo: String, detalle: String, victoria: bool) -> bool:
	if not cambiar_estado(Estado.GAMEOVER, &"fin_partida"):
		return false
	EventBus.partida_terminada.emit(titulo, detalle, victoria)
	return true


func reiniciar_partida() -> bool:
	return cambiar_estado(Estado.PLAYING, &"reintentar")


func volver_al_menu() -> bool:
	return cambiar_estado(Estado.MENU, &"volver_al_menu")


func es_jugable() -> bool:
	return estado == Estado.PLAYING


## Los controles táctiles sólo pueden recibir input en PLAYING. La Fase 2
## conectará esto con `TouchControls.visible` y su `mouse_filter`.
func bloquea_controles_tactiles() -> bool:
	return estado != Estado.PLAYING


func motivo_actual() -> StringName:
	return _motivo_actual


func estado_como_texto(valor: int) -> String:
	match valor:
		Estado.MENU:
			return "MENU"
		Estado.PLAYING:
			return "PLAYING"
		Estado.SHOP:
			return "SHOP"
		Estado.PAUSED:
			return "PAUSED"
		Estado.GAMEOVER:
			return "GAMEOVER"
	return "DESCONOCIDO"


# --- Internos ---------------------------------------------------------------

func _al_partida_terminada(titulo: String, detalle: String, victoria: bool) -> void:
	# `terminar_partida()` ya emite esta señal; el guardia evita la recursión.
	if estado != Estado.GAMEOVER:
		cambiar_estado(Estado.GAMEOVER, &"fin_partida_remoto")


func _mundo_debe_pausarse(valor: Estado) -> bool:
	return valor in [Estado.SHOP, Estado.PAUSED, Estado.GAMEOVER]


func _transicion_permitida(desde: Estado, hacia: Estado) -> bool:
	match desde:
		Estado.MENU:
			return hacia == Estado.PLAYING or hacia == Estado.GAMEOVER
		Estado.PLAYING:
			return hacia in [Estado.SHOP, Estado.PAUSED, Estado.GAMEOVER, Estado.MENU]
		Estado.SHOP:
			return hacia in [Estado.PLAYING, Estado.GAMEOVER, Estado.MENU]
		Estado.PAUSED:
			return hacia in [Estado.PLAYING, Estado.GAMEOVER, Estado.MENU]
		Estado.GAMEOVER:
			return hacia == Estado.PLAYING or hacia == Estado.MENU
	return false
