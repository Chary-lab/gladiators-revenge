extends SceneTree
## Informe de balance sin editor: imprime la curva de daño, vida y tiempo de
## muerte (TTK) de cada clase en los niveles clave frente al enemigo de la
## oleada equivalente. No es una prueba: sirve para ajustar constantes.
##
## Uso: godot --headless --path . --script res://tests/balance_report.gd

func _initialize() -> void:
	print("clase      niv  FUE  AGI  INT |    HP   ARM  red% |  vel  daño(min-máx)   DPS | HP_ene  TTK | DanEne  DPS_ene  surv")
	for clase in [&"prisionero", &"bastion", &"filo", &"cetro"]:
		for nivel in [1, 5, 10, 15, 20]:
			var e := GladiatorStats.new()
			e.configurar_clase(clase)
			e.nivel = nivel
			# crecimiento automático por nivel + 1 punto libre por nivel al atributo principal
			var crec: Vector3 = GladiatorStats.CRECIMIENTO_POR_CLASE.get(clase, Vector3(1,1,1))
			var extra: int = nivel - 1
			e.fuerza += int(round(crec.x * extra))
			e.agilidad += int(round(crec.y * extra))
			e.inteligencia += int(round(crec.z * extra))
			var arma_base := 6.0
			var atributo := &"fuerza"
			match clase:
				&"bastion":
					arma_base = 20.0
					atributo = &"fuerza"
				&"filo":
					arma_base = 15.0
					atributo = &"agilidad"
				&"cetro":
					arma_base = 11.0
					atributo = &"inteligencia"
			var rango := e.rango_dano_ataque(arma_base, atributo)
			var medio: float = (rango.x + rango.y) * 0.5
			var crit_mult: float = 1.0 + e.probabilidad_critico * (e.multiplicador_critico - 1.0)
			var dps: float = medio * e.velocidad_ataque * crit_mult
			# enemigo de referencia: ala = nivel (misma ronda)
			var perfil: Dictionary = BalanceOlas.perfil(nivel)
			var hp_ene: float = (95.0 + nivel * 46.0) * float(perfil["vida"])
			var ttk: float = hp_ene / maxf(1.0, dps)
			var dano_ene: float = (11.0 + nivel * 4.6) * float(perfil["dano"])
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
