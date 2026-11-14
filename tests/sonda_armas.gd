extends SceneTree
## Sonda de geometría: confirma que las armas procedurales se empaquetan con sus
## piezas y mide su caja envolvente (un arco debe medir ~1,2 × 1,7, no 0,06).

func _initialize() -> void:
	for arma in WeaponItem.crear_catalogo_base():
		if arma == null or arma.escena_visual == null:
			continue
		var nodo := arma.escena_visual.instantiate() as Node3D
		if nodo == null:
			print("%s: escena visual nula" % arma.id_clase())
			continue
		var caja := AABB()
		var primero := true
		var mallas := 0
		for hijo in nodo.find_children("*", "MeshInstance3D", true, false):
			var malla := hijo as MeshInstance3D
			if malla == null or malla.mesh == null:
				continue
			mallas += 1
			var propia := malla.transform * malla.mesh.get_aabb()
			caja = propia if primero else caja.merge(propia)
			primero = false
		print("%s: %d mallas · tamaño=%.2f x %.2f x %.2f" % [
			arma.id_clase(), mallas, caja.size.x, caja.size.y, caja.size.z
		])
		nodo.free()
	quit(0)
