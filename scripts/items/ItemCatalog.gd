class_name ItemCatalog
extends RefCounted
## Catálogo original de objetos de Gladiators Revenge.
## Solo componentes, pociones y pergaminos se compran; intermedios y legendarios
## se forjan automáticamente al reunir la receta y pagar el coste de forja.

static var _cache: Array[ItemData] = []
## Índice id → objeto: `obtener()` se llama desde cada chip del árbol de la
## tienda y desde cada compra; recorrer la lista costaba 1,5 µs por consulta.
static var _por_id: Dictionary = {}


static func crear_catalogo() -> Array[ItemData]:
	if not _cache.is_empty():
		return _cache
	var items: Array[ItemData] = []
	items.append_array(_pociones())
	items.append_array(_pergaminos())
	items.append_array(_componentes())
	items.append_array(_epicos())
	items.append_array(_intermedios())
	items.append_array(_legendarios())
	_cache = items
	_por_id.clear()
	for item in items:
		_por_id[item.id] = item
	return _cache


static func obtener(id: StringName) -> ItemData:
	if _por_id.has(id):
		return _por_id[id]
	for item in crear_catalogo():
		if item.id == id:
			return item
	return null


static func vendibles() -> Array[ItemData]:
	var lista: Array[ItemData] = []
	for item in crear_catalogo():
		if item.tipo in [ItemData.Tipo.POCION, ItemData.Tipo.PERGAMINO, ItemData.Tipo.COMPONENTE]:
			lista.append(item)
	return lista


static func recetas() -> Array[ItemData]:
	var lista: Array[ItemData] = []
	for item in crear_catalogo():
		if item.tipo in [ItemData.Tipo.INTERMEDIO, ItemData.Tipo.LEGENDARIO]:
			lista.append(item)
	return lista


static func _pociones() -> Array[ItemData]:
	var vida := _base(&"pocion_vida", "Poción de Sangre", "Restaura vida al instante.", "❤", ItemData.Tipo.POCION, 1, 45)
	vida.consumible = true
	vida.maximo_pila = 5
	vida.curacion_vida = 140.0
	vida.descripcion = "Cura 140 + 40 % de tu Fuerza. Comparte enfriamiento con la poción de maná."

	var mana := _base(&"pocion_mana", "Poción de Savia", "Restaura maná al instante.", "✦", ItemData.Tipo.POCION, 1, 40)
	mana.consumible = true
	mana.maximo_pila = 5
	mana.curacion_mana = 100.0
	mana.descripcion = "Restaura 100 + 30 % de tu Inteligencia. Comparte enfriamiento con la poción de vida."
	return [vida, mana]


static func _pergaminos() -> Array[ItemData]:
	var escudo := _base(&"pergamino_egida", "Pergamino de Égida", "Escuda al estandarte y al gladiador.", "▣", ItemData.Tipo.PERGAMINO, 1, 90)
	escudo.consumible = true
	escudo.maximo_pila = 3
	escudo.efecto_especial = &"escudo_estandarte"
	escudo.descripcion = "Cura 220 al estandarte y otorga 120 de escudo al gladiador durante 8 s."

	var aturdir := _base(&"pergamino_temblor", "Pergamino de Temblor", "Onda de tierra que aturde.", "◎", ItemData.Tipo.PERGAMINO, 1, 120)
	aturdir.consumible = true
	aturdir.maximo_pila = 3
	aturdir.habilidad = _habilidad(&"pergamino_temblor", "Temblor", AbilityData.Tipo.ZONA, 30.0, 25.0, 14.0, 0.8, &"inteligencia")
	aturdir.habilidad.tipo_dano = GladiatorStats.TIPO_MAGICO
	aturdir.habilidad.efecto_especial = &"raices"
	aturdir.habilidad.radio = 5.0
	aturdir.habilidad.duracion = 2.2
	aturdir.habilidad.talentos.clear()
	aturdir.descripcion = "Aturde 2,2 s a los enemigos en 5 m e inflige 30 + escalado mágico de INT."

	var furia := _base(&"pergamino_furia", "Pergamino de Furia", "Enciende la sangre del gladiador.", "▲", ItemData.Tipo.PERGAMINO, 1, 110)
	furia.consumible = true
	furia.maximo_pila = 3
	furia.efecto_especial = &"furia_temporal"
	furia.descripcion = "Durante 8 s: +35 % velocidad de ataque y +15 % robo de vida."
	return [escudo, aturdir, furia]


static func _componentes() -> Array[ItemData]:
	var brasa := _base(&"brasa_forja", "Brasa de Forja", "Acero aún caliente del Imperio.", "♨", ItemData.Tipo.COMPONENTE, 1, 120)
	brasa.bonificaciones = {&"fuerza": 12}
	brasa.pasiva = "Nivel 1 · componente de Fuerza"

	var pluma := _base(&"pluma_espectral", "Pluma Espectral", "Ligera como un susurro.", "⌁", ItemData.Tipo.COMPONENTE, 1, 120)
	pluma.bonificaciones = {&"agilidad": 12}
	pluma.pasiva = "Nivel 1 · componente de Agilidad"

	var cristal := _base(&"cristal_ancestral", "Cristal Ancestral", "Late con magia de las Tierras Baldías.", "◇", ItemData.Tipo.COMPONENTE, 1, 120)
	cristal.bonificaciones = {&"inteligencia": 12}
	cristal.pasiva = "Nivel 1 · componente de Inteligencia"

	var placa := _base(&"placa_oxidada", "Placa Oxidada", "Pesada, pero detiene golpes.", "▤", ItemData.Tipo.COMPONENTE, 1, 110)
	placa.bonificaciones = {&"armadura": 30, &"vida": 30}
	placa.pasiva = "Nivel 1 · componente defensivo"

	var engranaje := _base(&"engranaje_ritual", "Engranaje Ritual", "Acelera el pulso del arma.", "⚙", ItemData.Tipo.COMPONENTE, 1, 130)
	engranaje.bonificaciones = {&"velocidad_ataque": 0.12, &"critico": 0.02}
	engranaje.pasiva = "Nivel 1 · componente ofensivo"

	var raiz := _base(&"raiz_savia", "Raíz de Savia", "La arena aún recuerda la vida.", "❦", ItemData.Tipo.COMPONENTE, 1, 120)
	raiz.bonificaciones = {&"regeneracion": 1.2, &"vida": 30}
	raiz.pasiva = "Nivel 1 · componente de sustento"
	return [brasa, pluma, cristal, placa, engranaje, raiz]


static func _intermedios() -> Array[ItemData]:
	var nucleo := _base(&"nucleo_ferreo", "Núcleo Férreo", "Corazón de hierro fundido.", "⛨", ItemData.Tipo.INTERMEDIO, 2, 0)
	nucleo.receta = [&"brasa_forja", &"placa_oxidada"]
	nucleo.precio_forja = 80
	nucleo.bonificaciones = {&"fuerza": 20, &"armadura": 55, &"vida": 90}
	nucleo.pasiva = "Pasiva: +20 Fuerza, +55 armadura y +90 vida."

	var tormenta := _base(&"furia_tormenta", "Furia de Tormenta", "El arma golpea como un vendaval.", "ϟ", ItemData.Tipo.INTERMEDIO, 2, 0)
	tormenta.receta = [&"brasa_forja", &"engranaje_ritual"]
	tormenta.precio_forja = 80
	tormenta.bonificaciones = {&"fuerza": 14, &"velocidad_ataque": 0.18, &"dano_fisico": 12}
	tormenta.pasiva = "Pasiva: +14 Fuerza, +18 % velocidad de ataque y +12 daño físico."

	var halcon := _base(&"ojo_halcon", "Ojo de Halcón", "Ninguna presa escapa.", "◉", ItemData.Tipo.INTERMEDIO, 2, 0)
	halcon.receta = [&"pluma_espectral", &"engranaje_ritual"]
	halcon.precio_forja = 80
	halcon.bonificaciones = {&"agilidad": 18, &"velocidad_ataque": 0.15, &"critico": 0.05}
	halcon.pasiva = "Pasiva: +18 Agilidad, +15 % velocidad de ataque y +5 % crítico."

	var corona := _base(&"corona_runica", "Corona Rúnica", "Corona de un rey olvidado.", "♛", ItemData.Tipo.INTERMEDIO, 2, 0)
	corona.receta = [&"cristal_ancestral", &"raiz_savia"]
	corona.precio_forja = 80
	corona.bonificaciones = {&"inteligencia": 18, &"mana": 40, &"regeneracion_mana": 0.5}
	corona.pasiva = "Pasiva: +18 INT, +40 maná y +0,5 regeneración de maná."

	var piel := _base(&"piel_basalto", "Piel de Basalto", "Como muro de la arena.", "▩", ItemData.Tipo.INTERMEDIO, 2, 0)
	piel.receta = [&"placa_oxidada", &"raiz_savia"]
	piel.precio_forja = 80
	piel.bonificaciones = {&"vida": 130, &"armadura": 50, &"regeneracion": 1.4}
	piel.pasiva = "Pasiva: +130 vida, +50 armadura y +1,4 regeneración."

	var sello := _base(&"sello_arcano", "Sello Arcano", "Dos escuelas, un solo foco.", "✶", ItemData.Tipo.INTERMEDIO, 2, 0)
	sello.receta = [&"cristal_ancestral", &"pluma_espectral"]
	sello.precio_forja = 80
	sello.bonificaciones = {&"inteligencia": 16, &"agilidad": 14, &"dano_magico": 14}
	sello.pasiva = "Pasiva: +16 INT, +14 AGI y +14 daño mágico."
	return [nucleo, tormenta, halcon, corona, piel, sello]


static func _epicos() -> Array[ItemData]:
	var armadura := _base(&"armadura_brasas", "Armadura de Brasas", "Forjada en el fuego de la rebelión, protege y fortalece.", "🛡️", ItemData.Tipo.INTERMEDIO, 2, 0)
	armadura.rareza = ItemData.Rareza.EPICO
	armadura.receta = [&"nucleo_ferreo", &"raiz_savia"]
	armadura.precio_forja = 180
	armadura.bonificaciones = {&"armadura": 40, &"vida": 60}
	armadura.aura = {&"dano_aliados": 0.10}
	armadura.pasiva = "Aura: +10 % daño para ti y aliados cercanos."
	armadura.descripcion = "Épica: +40 armadura, +60 vida. Irradia una aura de combate que potencia a la rebelión."

	var anillo := _base(&"anillo_vampiro", "Anillo de Vampirismo", "La sangre de los caídos te fortalece a ti y a los tuyos.", "💍", ItemData.Tipo.INTERMEDIO, 2, 0)
	anillo.rareza = ItemData.Rareza.EPICO
	anillo.receta = [&"ojo_halcon", &"raiz_savia"]
	anillo.precio_forja = 180
	anillo.bonificaciones = {&"robo_vida": 0.08, &"agilidad": 15}
	anillo.aura = {&"robo_vida_aliados": 0.05}
	anillo.pasiva = "Aura: +5 % robo de vida para ti y aliados cercanos."
	anillo.descripcion = "Épica: +8 % robo de vida, +15 Agilidad. Los aliados cercanos también sanan al golpear."

	var fenix := _base(&"corazon_fenix", "Corazón de Fénix", "Arde con vida eterna, curando a quienes lo rodean.", "🔥", ItemData.Tipo.INTERMEDIO, 2, 0)
	fenix.rareza = ItemData.Rareza.EPICO
	fenix.receta = [&"corona_runica", &"raiz_savia"]
	fenix.precio_forja = 180
	fenix.bonificaciones = {&"vida": 100, &"regeneracion": 1.5}
	fenix.aura = {&"regeneracion_aliados": 0.5}
	fenix.pasiva = "Aura: +0,5 regeneración de vida por segundo para ti y aliados cercanos."
	fenix.descripcion = "Épica: +100 vida máxima, +1,5 regeneración. Su aura reaviva la vida de la rebelión."

	return [armadura, anillo, fenix]


static func _legendarios() -> Array[ItemData]:
	var corazon := _base(&"corazon_obsidiana", "Corazón de Obsidiana", "Nada quebranta a quien ya fue roto.", "♥", ItemData.Tipo.LEGENDARIO, 3, 0)
	corazon.rareza = ItemData.Rareza.LEGENDARIO
	corazon.receta = [&"nucleo_ferreo", &"piel_basalto"]
	corazon.precio_forja = 350
	corazon.bonificaciones = {&"fuerza": 45, &"vida": 280, &"armadura": 90}
	corazon.pasiva = "Pasiva: +45 Fuerza, +280 vida y +90 armadura."
	corazon.habilidad = _habilidad(&"egida_inquebrantable", "Égida Inquebrantable", AbilityData.Tipo.APOYO, 0.0, 30.0, 35.0, 0.0, &"fuerza")
	corazon.habilidad.objetivo = AbilityData.Objetivo.PROPIO
	corazon.habilidad.duracion = 4.0
	corazon.habilidad.escudo_por_atributo = 1.15
	corazon.habilidad.inmunidad_aturdimiento = 3.5
	corazon.habilidad.efecto_especial = &"egida"
	corazon.descripcion = "ACTIVO: escudo de 115 % de tu Fuerza e inmunidad a aturdimiento 3,5 s. Refleja daño físico."

	var daga := _base(&"daga_eclipse", "Daga del Eclipse", "La sombra llega antes que el filo.", "†", ItemData.Tipo.LEGENDARIO, 3, 0)
	daga.rareza = ItemData.Rareza.LEGENDARIO
	daga.receta = [&"ojo_halcon", &"sello_arcano"]
	daga.precio_forja = 350
	daga.bonificaciones = {&"agilidad": 45, &"critico": 0.08, &"velocidad_movimiento": 0.8}
	daga.pasiva = "Pasiva: +45 AGI, +8 % crítico y +0,8 movimiento."
	daga.habilidad = _habilidad(&"parpadeo_sombrio", "Parpadeo Sombrío", AbilityData.Tipo.MOVILIDAD, 0.0, 20.0, 18.0, 0.0, &"agilidad")
	daga.habilidad.objetivo = AbilityData.Objetivo.SUELO
	daga.habilidad.radio = 9.0
	daga.habilidad.efecto_especial = &"parpadeo"
	daga.descripcion = "ACTIVO: teleporta hasta 9 m al cursor y garantiza crítico 3 s."

	var orbe := _base(&"orbe_cataclismo", "Orbe del Cataclismo", "El cielo de las Tierras Baldías responde.", "◍", ItemData.Tipo.LEGENDARIO, 3, 0)
	orbe.rareza = ItemData.Rareza.LEGENDARIO
	orbe.receta = [&"corona_runica", &"sello_arcano"]
	orbe.precio_forja = 420
	orbe.bonificaciones = {&"inteligencia": 50, &"mana": 80, &"dano_magico": 25}
	orbe.pasiva = "Pasiva: +50 INT, +80 maná y +25 daño mágico."
	orbe.habilidad = _habilidad(&"descarga_cataclismo", "Descarga Arcana", AbilityData.Tipo.ZONA, 12.0, 55.0, 40.0, 4.0, &"inteligencia")
	orbe.habilidad.tipo_dano = GladiatorStats.TIPO_MAGICO
	orbe.habilidad.radio = 4.5
	orbe.habilidad.duracion = 0.6
	orbe.habilidad.rebotes = 3
	orbe.habilidad.efecto_especial = &"descarga"
	orbe.descripcion = "ACTIVO: rayo arcano que rebota a 4 enemigos infligiendo 55 + escalado mágico de INT."

	var cuerno := _base(&"cuerno_rebelion", "Cuerno de la Rebelión", "Su eco levanta hasta a los caídos.", "♪", ItemData.Tipo.LEGENDARIO, 3, 0)
	cuerno.rareza = ItemData.Rareza.LEGENDARIO
	cuerno.receta = [&"furia_tormenta", &"corona_runica"]
	cuerno.precio_forja = 380
	cuerno.bonificaciones = {&"fuerza": 25, &"inteligencia": 25, &"regeneracion": 2.0}
	cuerno.pasiva = "Pasiva: +25 FUE, +25 INT y +2 regeneración."
	cuerno.habilidad = _habilidad(&"grito_rebelion", "Grito de Guerra", AbilityData.Tipo.APOYO, 40.0, 40.0, 45.0, 0.0, &"inteligencia")
	cuerno.habilidad.radio = 10.0
	cuerno.habilidad.duracion = 6.0
	cuerno.habilidad.efecto_especial = &"grito"
	cuerno.descripcion = "ACTIVO: cura al estandarte y otorga +25 % ataque y +12 % robo de vida 6 s."

	var comandante := _base(&"capa_comandante", "Capa del Comandante", "Su manto inspira a toda la rebelión.", "🧥", ItemData.Tipo.LEGENDARIO, 3, 0)
	comandante.rareza = ItemData.Rareza.LEGENDARIO
	comandante.receta = [&"sello_arcano", &"piel_basalto"]
	comandante.precio_forja = 500
	comandante.bonificaciones = {&"fuerza": 20, &"agilidad": 15, &"inteligencia": 15}
	comandante.aura = {&"dano_aliados": 0.15, &"velocidad_ataque_aliados": 0.10}
	comandante.pasiva = "Aura: +15 % daño y +10 % velocidad de ataque a ti y tus aliados."
	comandante.descripcion = "Tu aura de mando aumenta el daño y la velocidad de ataque de todos los aliados cercanos."

	var guadana := _base(&"guadana_verdugo_ancestral", "Guadaña del Verdugo Ancestral", "Cosecha almas con cada tajo.", "✖", ItemData.Tipo.LEGENDARIO, 3, 0)
	guadana.rareza = ItemData.Rareza.LEGENDARIO
	guadana.receta = [&"ojo_halcon", &"furia_tormenta"]
	guadana.precio_forja = 500
	guadana.bonificaciones = {&"agilidad": 40, &"critico": 0.10, &"robo_vida": 0.12}
	guadana.aura = {&"dano_aliados": 0.20}
	guadana.pasiva = "Aura: +20 % daño para ti y todos los aliados cercanos."
	guadana.descripcion = "Tu aura de ejecutor potencia el daño de toda la rebelión."
	return [corazon, daga, orbe, cuerno, comandante, guadana]


static func _base(
	id: StringName,
	nombre: String,
	descripcion: String,
	icono: String,
	tipo: ItemData.Tipo,
	nivel: int,
	precio: int
) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.nombre = nombre
	item.descripcion = descripcion
	item.icono = icono
	item.tipo = tipo
	item.nivel = nivel
	item.precio = precio
	return item


static func _habilidad(
	id: StringName,
	nombre: String,
	tipo: AbilityData.Tipo,
	dano: float,
	coste: float,
	cooldown: float,
	duracion: float,
	atributo: StringName
) -> AbilityData:
	var habilidad := AbilityData.new()
	habilidad.id = id
	habilidad.nombre = nombre
	habilidad.descripcion = ""
	habilidad.tipo = tipo
	habilidad.objetivo = AbilityData.Objetivo.PROPIO if tipo == AbilityData.Tipo.APOYO else AbilityData.Objetivo.SUELO
	habilidad.coste_mana = coste
	habilidad.cooldown = cooldown
	habilidad.dano_base = dano
	habilidad.duracion = duracion
	habilidad.atributo_escalado = atributo
	habilidad.tipo_dano = GladiatorStats.TIPO_FISICO
	return habilidad
