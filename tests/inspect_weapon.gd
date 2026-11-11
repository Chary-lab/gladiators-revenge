extends SceneTree
## Inspección temporal de las armas: transform y caja de cada malla.

const RUTAS := [
	"res://assets/kaykit/weapons/axe_2handed.gltf",
	"res://assets/kaykit/weapons/sword_1handed.gltf",
	"res://assets/kaykit/weapons/staff.gltf",
]


func _init() -> void:
	for ruta in RUTAS:
		var escena := load(ruta) as PackedScene
		print("\n=== ", ruta)
		if escena == null:
			continue
		var raiz := escena.instantiate() as Node3D
		for nodo in raiz.find_children("*", "MeshInstance3D", true, false):
			var malla := nodo as MeshInstance3D
			print("  ", raiz.get_path_to(malla), " pos=", malla.position, " rot=", malla.rotation_degrees, " escala=", malla.scale)
			if malla.mesh != null:
				var caja := malla.mesh.get_aabb()
				print("     aabb centro=", caja.get_center(), " tamaño=", caja.size)
		raiz.free()
	quit()
