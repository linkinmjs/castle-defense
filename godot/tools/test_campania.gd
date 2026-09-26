extends SceneTree
## La vuelta completa: arrancar, terminar, ver el resumen y pasar al siguiente.
##
## Las otras pruebas miran cada pieza por separado. Esta recorre la campania
## como la recorre el jugador, que es donde aparecen los problemas de
## conexion: una señal que nadie escucha, un resumen que sale vacio, un
## encuentro que no limpia lo del anterior.

## Mas que la recuperacion de la ligera (0.3 s) y menos que la ventana del
## combo (0.7 s): lo que tarda un jugador en apretar dos veces.
const ENTRE_LIGERAS := 24

var _battle: Node
var _healer: Healer3D
var _combos: ComponenteCombos
var _resumenes: Array[Dictionary] = []
var _titulos: Array[String] = []
## El que recibe el combo del tercer encuentro.
var _paciente: Unidad3D
var _fallos := 0
var _fase := 0
var _ticks := 0


func _initialize() -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	root.add_child(_battle)
	physics_frame.connect(_tick)


## La batalla arma el healer y la telemetria en su _ready, que todavia no
## corrio cuando SceneTree llama a _initialize.
func _engancharse() -> void:
	_healer = _battle.get_node("%Healer")
	_combos = _healer.get_node("Combos")
	_battle.telemetria().encuentro_cerrado.connect(
		func(r: Dictionary) -> void: _resumenes.append(r))
	_battle.encuentro_iniciado.connect(
		func(e: Encuentro, _s: int, _i: int) -> void: _titulos.append(e.titulo))


func _tick() -> void:
	_ticks += 1
	match _fase:
		0:
			if _ticks < 5:
				return
			_engancharse()
			print("--- arranca por el primero, no por la batalla completa ---")
			_ok("carga la campania sola", _battle.campana != null)
			_ok("empieza en el primer encuentro", _battle._actual.id == &"e1_mantener_linea")
			_igual("con un solo movimiento", _combos.movimientos.size(), 1)

			print("--- curar de verdad queda anotado ---")
			var paciente := _primer_aliado()
			_ok("hay a quien curar", paciente != null)
			paciente.vida = paciente.vida_maxima * 0.5
			_frente_a(paciente)
			_healer.mana = _healer.mana_maximo
			_ok("la ligera sale", _healer.pulsar(&"ligera"))
			var r: Dictionary = _battle.telemetria().resumen()
			_ok("y la telemetria la vio", r["curacion_emitida"] > 0.0)
			_ok("con el uso anotado", r["usos_por_movimiento"].has("Toque"))

			# Se fuerza el final en vez de esperar los 75 segundos reales.
			_battle.tiempo_encuentro = _battle._actual.duracion
			_ticks = 0
			_fase = 1
		1:
			if _ticks < 5:
				return
			print("--- al terminar sale el resumen ---")
			_ok("la batalla termino", _battle.esta_terminada())
			_ok("se publico un resumen", _resumenes.size() == 1)
			# Sin resumen no hay que revisar: indexar igual cortaria la prueba
			# con un error en vez de contarlo como una falla mas.
			if _resumenes.is_empty():
				_ok("el resumen dice como termino (no llego ninguno)", false)
			else:
				var r: Dictionary = _resumenes[0]
				_ok("dice que se gano", r["victoria"] == true)
				_ok("con el id del encuentro", r["encuentro_id"] == &"e1_mantener_linea")
				_ok("y la curacion que hubo", r["curacion_emitida"] > 0.0)
			_ok("hay una observacion",
				_battle.telemetria().observacion_causal() != "")
			_ok("las unidades quedaron quietas", _ninguna_procesa())
			_ticks = 0
			_fase = 2
		2:
			if _ticks < 3:
				return
			print("--- Enter pasa al siguiente ---")
			_battle.avanzar_encuentro()
			_ticks = 0
			_fase = 3
		3:
			if _ticks < 5:
				return
			_ok("ahora es el de eficiencia", _battle._actual.id == &"e2_no_desperdiciar")
			_ok("se aviso el encuentro nuevo", _titulos.size() == 1)
			_igual("con el mana recortado", int(_healer.mana_maximo), 60)
			_ok("la batalla vuelve a estar en juego", not _battle.esta_terminada())
			_ok("el healer arranca entero", _healer.vida == _healer.vida_maxima)

			var r: Dictionary = _battle.telemetria().resumen()
			_igual("y la medicion arranca de cero", int(r["curacion_emitida"]), 0)
			_ok("hay heridos de distinta magnitud", _hay_heridas_dispares())

			_battle.tiempo_encuentro = _battle._actual.duracion
			_ticks = 0
			_fase = 4
		4:
			if _ticks < 5:
				return
			_ok("segundo resumen publicado", _resumenes.size() == 2)
			if _resumenes.size() < 2:
				_ok("y es del segundo encuentro (no llego el segundo resumen)", false)
			else:
				_ok("y es del segundo encuentro",
					_resumenes[1]["encuentro_id"] == &"e2_no_desperdiciar")
			_battle.avanzar_encuentro()
			_ticks = 0
			_fase = 5
		5:
			if _ticks < 5:
				return
			print("--- el tercero suma Vendaje ---")
			_ok("es el del sangrado", _battle._actual.id == &"e3_tratar_la_causa")
			# El segundo recorta el mana a 60 y el tercero no dice nada al
			# respecto: tiene que volver al de la escena, no heredar el recorte.
			_igual("el mana vuelve al normal", int(_healer.mana_maximo), 100)
			_igual("ahora hay dos movimientos", _combos.movimientos.size(), 2)
			_ok("Vendaje esta equipado", _combos.movimiento_por_nombre("Vendaje") != null)
			_ok("hay alguien sangrando de entrada", _sangrando() > 0)

			print("--- L, L sobre el que sangra corta la causa y queda anotado ---")
			var herido := _primer_sangrando()
			if herido == null:
				# Sin nadie sangrando no hay combo que probar: ya fallo arriba.
				_fase = 7
				return
			_frente_a(herido)
			_healer.mana = _healer.mana_maximo
			# Con dos lanceros sangrando, la ligera elige; lo que importa es que
			# el que recibe el combo sea uno que sangra.
			_paciente = Apuntado.objetivo_ligera(_healer)
			_ok("la ligera le llega a uno que sangra",
				_paciente != null and _paciente.esta_sangrando())
			_ok("la primera ligera sale", _healer.pulsar(&"ligera"))
			_ok("y es Toque: todavia sangra", _paciente != null and _paciente.esta_sangrando())
			_ticks = 0
			_fase = 6
		6:
			if _ticks < ENTRE_LIGERAS:
				return
			_ok("la segunda ligera sale", _healer.pulsar(&"ligera"))
			_ok("es Vendaje: dejo de sangrar", _paciente != null and not _paciente.esta_sangrando())
			var r: Dictionary = _battle.telemetria().resumen()
			_ok("la telemetria lo conto", r["sangrados_estabilizados"] >= 1)
			_ok("y anoto el Vendaje", r["usos_por_movimiento"].has("Vendaje"))
			_fase = 7
		7:
			print("--- volver al primero desde el ultimo ---")
			_ok("el ultimo avisa que no hay mas", not _battle.avanzar_encuentro())
			_ticks = 0
			_fase = 8
		8:
			if _ticks < 5:
				return
			_ok("y se vuelve al primero", _battle._actual.id == &"e1_mantener_linea")
			_igual("con su loadout otra vez", _combos.movimientos.size(), 1)
			_fase = 9
		9:
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit(1 if _fallos > 0 else 0)
			_fase = 10

	if _ticks > 900:
		print("FALLA: el test no termino")
		quit(1)


## Pone al healer 0.6 m detras de la unidad y mirando hacia ella: queda en la
## caja de la ligera, bien adentro.
func _frente_a(unidad: Unidad3D) -> void:
	_healer.global_position = unidad.global_position - Vector3(0.6, 0, 0)
	_healer._sprite.flip_h = false


func _primer_aliado() -> Unidad3D:
	for u in get_nodes_in_group("aliados"):
		if u.esta_viva() and not u.is_queued_for_deletion():
			return u
	return null


func _primer_sangrando() -> Unidad3D:
	for u in get_nodes_in_group("aliados"):
		if u.esta_sangrando() and not u.is_queued_for_deletion():
			return u
	return null


func _sangrando() -> int:
	var total := 0
	for u in get_nodes_in_group("aliados"):
		if u.esta_sangrando() and not u.is_queued_for_deletion():
			total += 1
	return total


func _hay_heridas_dispares() -> bool:
	var minima := 1.0
	var maxima := 0.0
	for u in get_nodes_in_group("aliados"):
		if u.is_queued_for_deletion():
			continue
		var fraccion: float = u.vida / u.vida_maxima
		minima = minf(minima, fraccion)
		maxima = maxf(maxima, fraccion)
	return maxima - minima > 0.3


func _ninguna_procesa() -> bool:
	for grupo in ["aliados", "enemigos"]:
		for u in get_nodes_in_group(grupo):
			if u.is_physics_processing():
				return false
	return true


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _igual(que: String, obtenido: int, esperado: int) -> void:
	var ok := obtenido == esperado
	if not ok:
		_fallos += 1
	print("  [%s] %-44s obtenido=%d esperado=%d" % [
		"OK" if ok else "FALLA", que, obtenido, esperado])
