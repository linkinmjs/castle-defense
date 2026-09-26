extends SceneTree
## La pausa: que corte el juego, que lo devuelva, y sobre todo que nunca deje el
## arbol pausado.
##
## Si el arbol quedara pausado, las otras pruebas y las capturas que instancian
## la batalla se colgarian esperando frames que no llegan nunca.

var _battle: Node
var _pausa: CanvasLayer
var _fallos := 0
var _fase := 0
var _ticks := 0


func _initialize() -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	root.add_child(_battle)
	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	match _fase:
		0:
			if _ticks < 5:
				return
			_pausa = _battle.get_node_or_null("%MenuPausa")
			_ok("la batalla trae el menu de pausa", _pausa != null)
			if _pausa == null:
				_fase = 9
				return

			print("--- arranca invisible y sin pausar ---")
			_ok("empieza cerrado", not _pausa.esta_abierto())
			_ok("y el arbol corre", not paused)
			_ok("corre aunque el arbol se pause",
				_pausa.process_mode == Node.PROCESS_MODE_ALWAYS)
			_ok("va por encima del HUD", _pausa.layer > 1)
			_fase = 1
		1:
			print("--- Escape abre ---")
			_pausa._unhandled_input(_accion("pause"))
			_ok("quedo abierto", _pausa.esta_abierto())
			_ok("y el arbol quedo pausado", paused)
			_ticks = 0
			_fase = 2
		2:
			if _ticks < 3:
				return
			# Con el arbol pausado los soldados no tienen que moverse.
			var antes := _posiciones()
			_ticks = 0
			_fase = 3
			set_meta("posiciones", antes)
		3:
			if _ticks < 10:
				return
			_ok("las unidades no se movieron durante la pausa",
				_posiciones() == get_meta("posiciones"))

			print("--- Escape vuelve a cerrar ---")
			_pausa._unhandled_input(_accion("pause"))
			_ok("quedo cerrado", not _pausa.esta_abierto())
			_ok("y el arbol volvio a correr", not paused)
			_fase = 4
		4:
			print("--- abrir dos veces no rompe nada ---")
			_pausa.abrir()
			_pausa.abrir()
			_ok("sigue abierto una sola vez", _pausa.esta_abierto())
			_pausa.cerrar()
			_pausa.cerrar()
			_ok("y cerrar de mas tampoco", not _pausa.esta_abierto())
			_ok("el arbol quedo corriendo", not paused)
			# Se fuerza el final del encuentro en vez de esperarlo.
			_battle.tiempo_encuentro = _battle._actual.duracion
			_ticks = 0
			_fase = 6
		6:
			if not _battle.esta_terminada():
				return
			print("--- con el encuentro terminado, Start sigue y no pausa ---")
			# En el pad, Start es pause y continuar a la vez.
			var start := InputEventJoypadButton.new()
			start.button_index = JOY_BUTTON_START
			start.device = 0
			start.pressed = true
			_ok("Start es pause y continuar", start.is_action_pressed("pause")
				and start.is_action_pressed("continuar"))
			_pausa._unhandled_input(start)
			_ok("el menu no se queda con el Start", not _pausa.esta_abierto())
			_ok("y el arbol sigue corriendo", not paused)
			var antes: StringName = _battle._actual.id
			_battle._unhandled_input(start)
			_ok("la batalla lo toma como continuar", _battle._actual.id != antes)
			_ok("y el encuentro nuevo arranca en juego", not _battle.esta_terminada())

			# Mientras se juega, Start vuelve a ser pausa.
			_pausa._unhandled_input(start)
			_ok("jugando, Start pausa", _pausa.esta_abierto())
			_pausa.cerrar()
			_fase = 5
		5:
			print("--- soltar la batalla pausada no deja el arbol trabado ---")
			_pausa.abrir()
			_ok("pausado antes de soltar", paused)
			_battle.free()
			_battle = null
			_ok("al liberarla el arbol se despausa solo", not paused)
			_fase = 9
		9:
			print("")
			# Lo mas importante del test: si esto quedara en true, las demas
			# suites se colgarian.
			_ok("el arbol termina sin pausar", not paused)
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit(1 if _fallos > 0 else 0)
			_fase = 10

	if _ticks > 600:
		print("FALLA: el test no termino")
		paused = false
		quit(1)


## Un evento de accion fabricado: en headless no llega ningun teclado.
func _accion(nombre: StringName) -> InputEventAction:
	var evento := InputEventAction.new()
	evento.action = nombre
	evento.pressed = true
	return evento


func _posiciones() -> Array[Vector3]:
	var salida: Array[Vector3] = []
	for u in get_nodes_in_group("aliados"):
		if is_instance_valid(u):
			salida.append(u.global_position)
	return salida


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])
