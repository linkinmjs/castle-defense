extends SceneTree
## La fila de habilidades: que muestre las equipadas y como estan.

var _contenedor: Node3D
var _healer: Healer3D
var _componente: ComponenteHabilidades
var _slots: Control
## El loadout completo, guardado antes de recortarlo: una vez equipada media
## lista, buscar el resto por nombre en el componente ya no lo encuentra.
var _todas: Array[Habilidad] = []
var _fallos := 0
var _fase := 0
var _ticks := 0


func _initialize() -> void:
	_contenedor = Node3D.new()
	root.add_child(_contenedor)
	_healer = load("res://scenes/3d/healer3d.tscn").instantiate()
	_contenedor.add_child(_healer)
	_componente = _healer.get_node("Habilidades")

	_slots = load("res://scripts/slots_habilidades.gd").new()
	_contenedor.add_child(_slots)
	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	match _fase:
		0:
			if _ticks < 3:
				return
			_slots.seguir(_healer, _componente)
			_todas = _componente.habilidades.duplicate()
			print("--- una entrada por habilidad equipada ---")
			_igual("con el loadout completo", _slots._armar_slots().size(), 6)

			var curar := _buscar("Curar")
			_componente.equipar([curar] as Array[Habilidad])
			_igual("con una sola equipada", _slots._armar_slots().size(), 1)

			print("--- cada entrada dice como esta la habilidad ---")
			_healer.mana = _healer.mana_maximo
			_componente._restante.clear()
			var slot: Dictionary = _slots._armar_slots()[0]
			_ok("trae el nombre", slot["nombre"] == "Curar")
			_ok("y la tecla", slot["tecla"] != "")
			_ok("y el icono del pack", slot["icono"] != null)
			_ok("esta disponible", slot["disponible"])
			_ok("sin enfriamiento", is_zero_approx(slot["enfriando"]))
			_ok("y el pie dice el costo (%s)" % slot["pie"], slot["pie"].contains("mana"))

			print("--- sin mana no se puede usar ---")
			_healer.mana = 0.0
			slot = _slots._armar_slots()[0]
			_ok("queda marcada sin mana", slot["sin_mana"])
			_ok("y no disponible", not slot["disponible"])
			_ok("el pie lo dice", slot["pie"] == "sin mana")

			print("--- usarla la deja enfriando ---")
			_healer.mana = _healer.mana_maximo
			var aliado := _crear_aliado()
			_healer._apuntada = aliado
			aliado.vida = 10.0
			_ok("se pudo usar", _componente.intentar(curar))
			slot = _slots._armar_slots()[0]
			_ok("queda enfriando", slot["enfriando"] > 0.0)
			_ok("y no disponible", not slot["disponible"])
			_ok("el pie muestra los segundos (%s)" % slot["pie"], slot["pie"].ends_with("s"))
			_fase = 1
		1:
			if _ticks < 6:
				return
			print("--- los nodos siguen al loadout ---")
			_igual("un slot dibujado", _slots._vistas.size(), 1)
			_componente.equipar([_buscar("Curar"), _buscar("Estabilizar")] as Array[Habilidad])
			_igual("al equipar dos, dos slots", _slots._vistas.size(), 2)
			_fase = 2
		2:
			if _ticks < 4:
				return
			print("--- el HUD no tapa el campo ---")
			_ok("la fila deja pasar el mouse",
				_slots.mouse_filter == Control.MOUSE_FILTER_IGNORE)
			_ok("y sus nodos tambien", _ninguno_intercepta(_slots))
			_fase = 3
		3:
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit(1 if _fallos > 0 else 0)
			_fase = 4

	if _ticks > 600:
		print("FALLA: el test no termino")
		quit(1)


## Un Control con mouse_filter STOP se come el click y el jugador no puede
## curar al soldado que quede debajo.
func _ninguno_intercepta(nodo: Node) -> bool:
	for hijo in nodo.get_children():
		if hijo is Control and hijo.mouse_filter == Control.MOUSE_FILTER_STOP:
			print("     intercepta: %s (%s)" % [hijo.name, hijo.get_class()])
			return false
		if not _ninguno_intercepta(hijo):
			return false
	return true


func _buscar(nombre: String) -> Habilidad:
	for habilidad: Habilidad in _todas:
		if habilidad.nombre == nombre:
			return habilidad
	return null


func _crear_aliado() -> Unidad3D:
	var u: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	u.configurar(Unidad3D.Bando.ALIADO, load("res://resources/soldados/escudero.tres"))
	u.position = _healer.global_position + Vector3(0.8, 0, 0)
	_contenedor.add_child(u)
	return u


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _igual(que: String, obtenido: int, esperado: int) -> void:
	var ok := obtenido == esperado
	if not ok:
		_fallos += 1
	print("  [%s] %-42s obtenido=%d esperado=%d" % [
		"OK" if ok else "FALLA", que, obtenido, esperado])
