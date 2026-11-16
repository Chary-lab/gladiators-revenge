class_name EnemyCatalog
extends RefCounted
## Catálogo de los cuatro arquetipos data-driven. Carga los `.tres` una sola
## vez y los expone por id. Los modelos siguen siendo los KayKit CC0 que ya
## están en `assets/kaykit/` (ver CREDITS.md).

const RUTA := "res://assets/data/enemigos/"
const IDS: Array[StringName] = [&"soldado_mezcla", &"cargador", &"arquero_granja", &"muralla"]

static var _cache: Dictionary = {}


static func todos() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	for id: StringName in IDS:
		var ruta := RUTA + String(id) + ".tres"
		if ResourceLoader.exists(ruta):
			var datos := load(ruta) as EnemyData
			if datos != null:
				_cache[id] = datos
	return _cache


static func obtener(id: StringName) -> EnemyData:
	if _cache.is_empty():
		todos()
	return _cache.get(id) as EnemyData
