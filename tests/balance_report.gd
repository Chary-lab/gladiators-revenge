extends SceneTree
## Informe de balance sin editor: imprime la curva de daño, vida y tiempo de
## muerte (TTK) de cada clase en los niveles clave frente al enemigo de la
## oleada equivalente. No es una prueba: sirve para ajustar constantes.
##
## Usa las fuentes de verdad del juego (no números copiados):
##  - arma real del catálogo (WeaponItem.crear_catalogo_base): dano_ataque_base
##    y atributo_principal.
##  - GladiatorStats: crecimiento,Mult_DANO_POR_CLASE, rango_dano_ataque.
##  - ArenaEnemy: VIDA_BASE=66, VIDA_POR_RONDA=24, DANO_BASE=6, DANO_POR_RONDA=2.
##  - BalanceOlas.perfil: multiplicadores de vida/daño de la oleada.
##
## Uso: godot --headless --path . --script res://tests/balance_report.gd

const VIDA_ENE_BASE := 66.0
const VIDA_ENE_RONDA := 24.0
const DANO_ENE_BASE := 6.0
const DANO_ENE_RONDA := 2.0


func _initialize() -> void:
	print("clase      niv  FUE  AGI  INT |    HP   ARM  red% |  vel  daño(min-máx)   DPS | HP_ene  TTK | DanEne  DPS_ene  surv")
	var armas := WeaponItem.crear_catalogo_base()
	for clase in [&"prisionero", &"bastion", &"filo", &"cetro", &"lanza", &"saeta"]:
		var arma := _arma_para(clase, armas)
		var arma_base := arma.dano_ataque_base if arma != null else 6.0
		var atributo := arma.atributo_principal if arma != null else &"fuerza"
		for nivel in [1, 5, 10, 15, 20]:
			var e := GladiatorStats.new()
			e.configurar_clase(clase)
			e.nivel = nivel
			# Crecimiento automático por nivel + 1 punto libre por nivel al atributo principal.
			var crec: Vector3 = GladiatorStats.CRECIMIENTO_POR_CLASE.get(clase, Vector3(1, 1, 1))
			var extra: int = nivel - 1
			e.fuerza += int(round(crec.x * extra))
			e.agilidad += int(round(crec.y * extra))
			e.inteligencia += int(round(crec.z * extra))
			var rango := e.rango_dano_ataque(arma_base, atributo)
			var medio: float = (rango.x + rango.y) * 0.5
			var crit_mult: float = 1.0 + e.probabilidad_critico * (e.multiplicador_critico - 1.0)
			var dps: float = medio * e.velocidad_ataque * crit_mult
			# Enemigo de referencia: mismo número de ronda, con multiplicadores del perfil.
			var perfil: Dictionary = BalanceOlas.perfil(nivel)
			var hp_ene: float = (VIDA_ENE_BASE + nivel * VIDA_ENE_RONDA) * float(perfil["vida"])
			var ttk: float = hp_ene / maxf(1.0, dps)
			var dano_ene: float = (DANO_ENE_BASE + nivel * DANO_ENE_RONDA) * float(perfil["dano"])
			var dps_ene: float = dano_ene / 1.5
			var ef_hp: float = e.salud_maxima / maxf(0.05, 1.0 - e.mitigacion_fisica)
			var surv: float = ef_hp / maxf(0.1, dps_ene)
			print("%-10s %3d %4d %4d %4d | %5d %5d %5.0f | %4.2f %4.0f-%4.0f %6.0f | %5.0f %5.1f | %6.1f %7.1f %6.1f" % [
				clase, nivel, e.fuerza_total, e.agilidad_total, e.inteligencia_total,
				int(e.salud_maxima), int(e.armadura_total), e.mitigacion_fisica * 100.0,
				e.velocidad_ataque, rango.x, rango.y, dps,
				hp_ene, ttk, dano_ene, dps_ene, surv
			])
	quit()


static func _arma_para(clase: StringName, catalogo: Array) -> WeaponItem:
	for arma in catalogo:
		if arma != null and arma.id_clase() == clase:
			return arma
	return null
