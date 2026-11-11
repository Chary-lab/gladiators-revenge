extends SceneTree
## Inspección temporal de los GLB importados: árbol de nodos, animaciones y huesos.

const RUTAS := [
	"res://assets/kaykit/adventurers/Barbarian.glb",
	"res://assets/kaykit/skeletons/Skeleton_Warrior.glb",
	"res://assets/kaykit/adventurers/Knight.glb",
	"res://assets/kaykit/weapons/staff.gltf",
	"res://assets/kaykit/dungeon/column.gltf.glb",
]


func _init() -> void:
	for ruta in RUTAS:
		var escena := load(ruta) as PackedScene
		print("\n=== ", ruta, " -> ", escena)
		if escena == null:
			continue
		var raiz := escena.instantiate()
		_imprimir(raiz, 0)
		for nodo in raiz.find_children("*", "AnimationPlayer", true, false):
			var player := nodo as AnimationPlayer
			var nombres := player.get_animation_list()
			print("  ANIMACIONES (", nombres.size(), "): ", nombres.slice(0, 12))
		for nodo in raiz.find_children("*", "Skeleton3D", true, false):
			var esqueleto := nodo as Skeleton3D
			print("  HUESOS (", esqueleto.get_bone_count(), "): ", _huesos(esqueleto))
		raiz.free()
	quit()


func _imprimir(nodo: Node, nivel: int) -> void:
	print("  ".repeat(nivel), nodo.name, " [", nodo.get_class(), "]")
	for hijo in nodo.get_children():
		_imprimir(hijo, nivel + 1)


func _huesos(esqueleto: Skeleton3D) -> Array:
	var salida := []
	for i in mini(esqueleto.get_bone_count(), 45):
		salida.append(esqueleto.get_bone_name(i))
	return salida
