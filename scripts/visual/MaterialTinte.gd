class_name MaterialTinte
extends RefCounted
## Tiñe mallas de modelos importados (KayKit) multiplicando el albedo, sin
## duplicar texturas ni mallas. Igual criterio que CharacterVisual: los
## materiales se comparten por (modelo, malla, tinte) para no pagar una copia
## por instancia. Se usa en la arena para integrar el suelo en la paleta
## carbón/ascua sin sustituir los GLB CC0.

static var _cache: Dictionary = {}


## Aplica `tinte` a todas las MeshInstance3D bajo `raiz` (incluida ella).
## `id_modelo` distingue los GLB para que mallas con el mismo nombre en
## modelos distintos no compartan material por error.
static func aplicar(raiz: Node, id_modelo: String, tinte: Color) -> void:
	if raiz == null:
		return
	for nodo in raiz.find_children("*", "MeshInstance3D", true, false):
		var malla := nodo as MeshInstance3D
		_teñir_malla(malla, id_modelo, tinte)


static func _teñir_malla(malla: MeshInstance3D, id_modelo: String, tinte: Color) -> void:
	var original := _material_original(malla)
	if original == null:
		return
	var clave := "%s|%s|%s" % [id_modelo, malla.name, tinte.to_html()]
	var copia: BaseMaterial3D = _cache.get(clave)
	if copia == null:
		copia = original.duplicate() as BaseMaterial3D
		if copia == null:
			return
		copia.albedo_color = Color(
			copia.albedo_color.r * tinte.r,
			copia.albedo_color.g * tinte.g,
			copia.albedo_color.b * tinte.b,
			copia.albedo_color.a * tinte.a
		)
		copia.resource_name = clave
		_cache[clave] = copia
	malla.material_override = copia


static func _material_original(malla: MeshInstance3D) -> BaseMaterial3D:
	if malla.material_override is BaseMaterial3D:
		return malla.material_override as BaseMaterial3D
	var cuenta := malla.mesh.get_surface_count() if malla.mesh != null else 0
	for i in cuenta:
		var material := malla.get_active_material(i)
		if material is BaseMaterial3D:
			return material as BaseMaterial3D
	return null


## Libera la caché (tests y cierre ordenado). Opcional: los materiales se
## reutilizan durante toda la partida y Godot los libera al salir.
static func limpiar() -> void:
	_cache.clear()
