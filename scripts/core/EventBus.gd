extends Node
## Autoload EventBus — canal global de eventos entre sistemas del juego.
##
## Fase 1 del rework: este archivo sólo declara señales. No conecta ni modifica
## escenas, nodos ni assets. Las señales que ya existen en Arena/HUD/WaveManager
## se puentearán aquí en la Fase 2, sin borrar las señales locales: un emisor
## local sigue siendo válido para el subsistema que lo emite, y EventBus sólo
## publica lo que otros sistemas necesitan escuchar sin conocer al emisor.
##
## Regla: las señales llevan tipos concretos. Para estados se usa `int` con los
## valores de `GameManager.Estado`, evitando una dependencia circular entre los
## dos autoloads.

# --- Ciclo de partida -------------------------------------------------------
signal partida_iniciada(es_local: bool)
signal partida_terminada(titulo: String, detalle: String, victoria: bool)
signal estado_cambiado(nuevo_estado: int, estado_anterior: int, motivo: StringName)
signal reintentar_solicitado
signal salir_lobby_solicitado

# --- Progresión y economía --------------------------------------------------
signal oleada_iniciada(numero: int, total: int)
signal oleada_terminada(numero: int)
signal oro_cambiado(cantidad: int)
signal inventario_cambiado
signal talentos_cambiados
signal enemigo_abatido(total: int)
signal mensaje(texto: String, duracion: float)

# --- Combate ----------------------------------------------------------------
signal vida_cambiada(actual: float, maxima: float)
signal mana_cambiado(actual: float, maxima: float)
signal habilidad_lanzada(slot: int, habilidad: AbilityData)
signal dano_infligido(objetivo: Node3D, cantidad: float, critico: bool)

# --- UI / control -----------------------------------------------------------
## panel: &"tienda", &"talentos", &"pausa", &"ficha", &"mochila".
signal panel_solicitado(panel: StringName, abrir: bool)
## Puente hacia `Pausa.abrir()/cerrar()` (contador existente) en la Fase 2.
signal pausa_solicitada(pausar: bool, motivo: StringName)
## El HUD táctil debe ocultarse y bloquear input cuando el estado no es PLAYING.
signal tactil_cambiado(activo: bool)
