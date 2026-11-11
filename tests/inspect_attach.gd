extends SceneTree
## Inspección temporal: prueba rotaciones y mide dónde queda el arma.

const ROTACIONES := [
	Vector3(0, 0, 0),
	Vector3(180, 0, 0),
	Vector3(0, 0, 180),
	Vector3(0, 98.6, 90),
	Vector3(0, -98.6, -90),
	Vector3(90, 0, 0),
	Vector3(-90, 0, 0),
]

func _init() -> void:
	var raiz := Node3D.new()
	get_root().add_child(raiz)
	var visual := CharacterVisual.new()
	raiz.add_child(visual)
	visual.configurar("res://assets/kaykit/adventurers/Barbarian.glb", Color.WHITE, "barbaro")
	await process_frame

	for rot in ROTACIONES:
		visual.equipar_arma(load("res://assets/kaykit/weapons/axe_2handed.gltf") as PackedScene, rot, 1.0)
		await process_frame
		var minimo := Vector3(INF, INF, INF)
		var maximo := Vector3(-INF, -INF, -INF)
		for malla in visual.arma_actual().find_children("*", "MeshInstance3D", true, false):
			var mi := malla as MeshInstance3D
			var caja: AABB = mi.global_transform * mi.get_aabb()
			minimo = minimo.min(caja.position)
			maximo = maximo.max(caja.position + caja.size)
		print("rot=", rot, "  y=[", minimo.y, " .. ", maximo.y, "]  z=[", minimo.z, " .. ", maximo.z, "]")
	quit()
