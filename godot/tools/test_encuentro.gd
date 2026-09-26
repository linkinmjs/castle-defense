extends SceneTree
## Los encuentros mandan sobre la batalla: componen el campo, restringen lo que
## esta en juego y se pueden repetir tal cual.

var _battle: Node
var _fallos := 0
var _fase := 0
var _ticks := 0
var _huella_inicial: Array[String] = []
var _nodos_iniciales := 0


func _initialize() -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	# Sin campania: se juega solo este, como hacen las pruebas y el editor.
	_battle.encuentro = load("res://resources/encuentros/e1_mantener_linea.tres")
	root.add_child(_battle)
	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	match _fase:
		0:
			if _ticks < 3:
				return
			print("--- el encuentro compone el campo ---")
			var aliados := _vivos("aliados")
			var enemigos := _vivos("enemigos")
			_igual("despliega los 4 escuderos del encuentro", aliados, 4)
			_igual("y los 5 zombis", enemigos, 5)
			_ok("todos los aliados son escuderos", _todos_del_tipo("aliados", "Escudero"))
			_ok("reparte nombres propios", _con_nombre("aliados") == 4)

			print("--- restringe lo que esta en juego ---")
			# El encuentro 1 apaga el sangrado: el unico problema es la vida.
			_ok("nadie puede sangrar", _probabilidad_maxima("aliados") == 0.0)
			var combos := _combos()
			_igual("equipa solo Toque", combos.movimientos.size(), 1)
			_ok("y es Toque", combos.movimiento_por_nombre("Toque") != null)
			_ok("Vendaje no esta", combos.movimiento_por_nombre("Vendaje") == null)

			# Redesplegado y medido en el mismo tick: con dejar correr aunque
			# sea un frame, las unidades ya se movieron y la huella dejaria de
			# describir el reparto para describir el combate.
			_battle.reiniciar_encuentro()
			_huella_inicial = _huella()
			# Contar los nodos en este mismo tick daria el doble: los del intento
			# anterior siguen colgando hasta que queue_free se concreta al final
			# del frame. El esperado son las unidades desplegadas mas el healer.
			_nodos_iniciales = _huella_inicial.size() + 1
			_ok("el despliegue no esta vacio", _huella_inicial.size() == 9)
			_ticks = 0
			_fase = 1
		1:
			if _ticks < 60:
				return
			print("--- reiniciar repite el mismo problema ---")
			# Un minuto de combate para que el campo quede bien distinto.
			_ok("el campo cambio mientras se jugaba", _huella() != _huella_inicial)
			_battle.reiniciar_encuentro()
			_ok("tras reiniciar vuelve el despliegue exacto", _huella() == _huella_inicial)
			_ticks = 0
			_fase = 2
		2:
			if _ticks < 3:
				return
			_igual("y no quedan restos del intento anterior",
				_battle.get_node("%Unidades").get_child_count(), _nodos_iniciales)
			_igual("el reloj del encuentro vuelve a cero", int(_battle.tiempo_encuentro), 0)
			_igual("y las bajas tambien", _battle.bajas_aliadas(), 0)
			_ticks = 0
			_fase = 3
		3:
			if _ticks < 3:
				return
			print("--- otra semilla, otro reparto ---")
			_battle.iniciar_encuentro(_battle.encuentro, 555)
			_ok("con otra semilla cambian las posiciones", _huella() != _huella_inicial)
			_ticks = 0
			_fase = 4
		4:
			if _ticks < 3:
				return
			_igual("pero la composicion es la misma", _vivos("aliados"), 4)
			_ticks = 0
			_fase = 5
		5:
			if _ticks < 3:
				return
			print("--- el encuentro 3 plantea la situacion de entrada ---")
			_battle.iniciar_encuentro(load("res://resources/encuentros/e3_tratar_la_causa.tres"))
			_ticks = 0
			_fase = 6
		6:
			if _ticks < 3:
				return
			_igual("despliega 5 aliados", _vivos("aliados"), 5)
			_ok("dos arrancan sangrando", _sangrando("aliados") == 2)
			var combos := _combos()
			_igual("ahora equipa dos movimientos", combos.movimientos.size(), 2)
			_ok("sumo Vendaje", combos.movimiento_por_nombre("Vendaje") != null)
			_ticks = 0
			_fase = 7
		7:
			if _ticks < 3:
				return
			print("--- la campania encadena los tres ---")
			var campana: Campana = load("res://resources/encuentros/campana.tres")
			_igual("son tres encuentros", campana.encuentros.size(), 3)
			_battle.campana = campana
			_battle.indice_encuentro = 0
			_battle.iniciar_encuentro(campana.encuentro_en(0))
			_ok("arranca en el primero", _battle._actual.id == &"e1_mantener_linea")
			_ok("avanzar devuelve true si hay mas", _battle.avanzar_encuentro())
			_ok("y pasa al segundo", _battle._actual.id == &"e2_no_desperdiciar")
			_battle.avanzar_encuentro()
			_ok("y al tercero", _battle._actual.id == &"e3_tratar_la_causa")
			_ok("en el ultimo devuelve false", not _battle.avanzar_encuentro())
			_ok("y vuelve al primero", _battle._actual.id == &"e1_mantener_linea")
			_ticks = 0
			_fase = 8
		8:
			if _ticks < 3:
				return
			print("--- heridas de distinta magnitud ---")
			_battle.iniciar_encuentro(load("res://resources/encuentros/e2_no_desperdiciar.tres"))
			_ticks = 0
			_fase = 9
		9:
			if _ticks < 3:
				return
			var fracciones := _fracciones_de_vida("aliados")
			_ok("nadie entra sano del todo", fracciones.min() < 0.5)
			_ok("y no todos estan igual de heridos",
				absf(fracciones.max() - fracciones.min()) > 0.3)
			_ticks = 0
			_fase = 10
		10:
			if _ticks < 3:
				return
			print("--- un encuentro sin lista equipa todo, no lo del anterior ---")
			# El anterior (e2) dejo solo Toque. El abierto no pide nada.
			_igual("venia de uno con Toque solo", _combos().movimientos.size(), 1)
			_battle.iniciar_encuentro(load("res://resources/encuentros/pruebas/abierto.tres"))
			_igual("equipa los ocho de la escena", _combos().movimientos.size(), 8)
			_ok("entre ellos Reanimar", _combos().movimiento_por_nombre("Reanimar") != null)
			_fase = 11
		11:
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit(1 if _fallos > 0 else 0)
			_fase = 12

	if _ticks > 900:
		print("FALLA: el test no termino")
		quit(1)


# --- Lecturas del campo -------------------------------------------------------

func _combos() -> ComponenteCombos:
	return _battle.get_node("%Healer").get_node("Combos")


## Bando, tipo y posicion de cada unidad, redondeada: es la identidad del
## despliegue, lo que tiene que repetirse con la misma semilla.
func _huella() -> Array[String]:
	var huella: Array[String] = []
	for unidad in _battle.get_node("%Unidades").get_children():
		if not unidad is Unidad3D or unidad.is_queued_for_deletion():
			continue
		var tipo: String = unidad.tipo.nombre if unidad.tipo != null else "-"
		huella.append("%d/%s/%.2f/%.2f" % [
			unidad.bando, tipo, unidad.position.x, unidad.position.z])
	return huella


func _vivos(grupo: String) -> int:
	var total := 0
	for unidad in get_nodes_in_group(grupo):
		if unidad.esta_viva() and not unidad.is_queued_for_deletion():
			total += 1
	return total


func _sangrando(grupo: String) -> int:
	var total := 0
	for unidad in get_nodes_in_group(grupo):
		if unidad.esta_sangrando() and not unidad.is_queued_for_deletion():
			total += 1
	return total


func _con_nombre(grupo: String) -> int:
	var total := 0
	for unidad in get_nodes_in_group(grupo):
		if unidad.nombre_unidad != "" and not unidad.is_queued_for_deletion():
			total += 1
	return total


func _todos_del_tipo(grupo: String, nombre: String) -> bool:
	for unidad in get_nodes_in_group(grupo):
		if unidad.is_queued_for_deletion():
			continue
		if unidad.tipo == null or unidad.tipo.nombre != nombre:
			return false
	return true


func _probabilidad_maxima(grupo: String) -> float:
	var maxima := 0.0
	for unidad in get_nodes_in_group(grupo):
		if not unidad.is_queued_for_deletion():
			maxima = maxf(maxima, unidad.probabilidad_sangrado)
	return maxima


func _fracciones_de_vida(grupo: String) -> Array[float]:
	var fracciones: Array[float] = []
	for unidad in get_nodes_in_group(grupo):
		if not unidad.is_queued_for_deletion():
			fracciones.append(unidad.vida / unidad.vida_maxima)
	return fracciones


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _igual(que: String, obtenido: int, esperado: int) -> void:
	var ok := obtenido == esperado
	if not ok:
		_fallos += 1
	print("  [%s] %-48s obtenido=%d esperado=%d" % [
		"OK" if ok else "FALLA", que, obtenido, esperado])
