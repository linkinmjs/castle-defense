extends PruebaBase
## Input por jugador: el Input Map que escribe setup_input.gd, que cada healer
## lea solo lo suyo y que nadie se quede con un evento que tambien es de otro.
##
## En headless no hay teclado ni joystick: los eventos se fabrican. Los de
## accion (InputEventAction) prueban lo que hace el healer con cada boton; los
## de tecla y de joystick prueban el mapa en si, que es donde se separa a un
## jugador del otro.

const ENTRE_LIGERAS := 24
const CUALQUIER_PAD := -1
const TEXTO_P1 := "Mover WASD / Stick · Ligera J / X · Pesada K / Y · Saltar Espacio / A"

var _h1: Healer3D
var _h2: Healer3D
## El aliado que cada healer tiene al frente.
var _a1: Unidad3D
var _a2: Unidad3D
## Colgado antes que los healers: recibe el input despues que ellos. Si lo ve
## es que ninguno se lo quedo.
var _espia: Node
var _usados_h1: Array[String] = []
var _x: float = 0.0
var _x2: float = 0.0


func preparar() -> void:
	var contenedor := Node3D.new()
	root.add_child(contenedor)

	var guion := GDScript.new()
	guion.source_code = "\n".join([
		"extends Node",
		"var vistos: Array[InputEvent] = []",
		"func _unhandled_input(evento: InputEvent) -> void:",
		"\tvistos.append(evento)",
	])
	guion.reload()
	_espia = Node.new()
	_espia.set_script(guion)
	contenedor.add_child(_espia)

	_h1 = _healer(1, Vector3(15, 0, 3))
	_h2 = _healer(2, Vector3(15, 0, 7))
	contenedor.add_child(_h1)
	contenedor.add_child(_h2)
	_a1 = _aliado(Vector3(16, 0, 3))
	_a2 = _aliado(Vector3(16, 0, 7))
	contenedor.add_child(_a1)
	contenedor.add_child(_a2)


func fase(numero: int) -> void:
	match numero:
		0:
			if _ticks < 2:
				return
			_quietos()
			_h1.get_node("Combos").movimiento_usado.connect(
				func(mov: Movimiento, _o: Node3D, _e: float) -> void: _usados_h1.append(mov.nombre))
			_mapa()
			_dispositivos()
			_jugadores()
			_por_healer()
			siguiente()
		1:
			print("--- con solo Toque, L, L es Toque dos veces ---")
			_h1.reiniciar(_h1.global_position)
			_h1.get_node("Combos").equipar([_mov("Toque")] as Array[Movimiento])
			_a1.vida = 20.0
			_usados_h1.clear()
			_h1._unhandled_input(accion(&"p1_ligera"))
			siguiente()
		2:
			if _ticks < ENTRE_LIGERAS:
				return
			_h1._unhandled_input(accion(&"p1_ligera"))
			var esperados: Array[String] = ["Toque", "Toque"]
			_ok("salieron Toque y Toque (%s)" % ", ".join(PackedStringArray(_usados_h1)),
				_usados_h1 == esperados)
			_h1.reiniciar(_h1.global_position)
			_h1.get_node("Combos").equipar(_todos())
			siguiente()
		3:
			print("--- cada uno camina con lo suyo ---")
			Input.action_press(&"p1_derecha")
			_x = _h1.global_position.x
			_x2 = _h2.global_position.x
			siguiente()
		4:
			if _ticks < 20:
				return
			_ok("p1_derecha mueve al primero", _h1.global_position.x > _x + 0.5)
			_ok("y no al segundo", is_equal_approx(_h2.global_position.x, _x2))
			Input.action_release(&"p1_derecha")
			_h2._unhandled_input(accion(&"p1_saltar"))
			_ok("el salto del primero no hace saltar al segundo", not _h2.esta_en_el_aire())
			_h1._unhandled_input(accion(&"p1_saltar"))
			_ok("y al primero si", _h1.esta_en_el_aire())
			siguiente()
		5:
			if _h1.esta_en_el_aire():
				return
			print("--- rezando no camina ni salta ---")
			_h1.reiniciar(Vector3(15, 0, 3))
			_h1._sprite.flip_h = false
			_h1._unhandled_input(accion(&"p1_pesada"))
			_ok("la pesada sola se queda cargando", _h1.esta_en_wind_up())
			_h1._unhandled_input(accion(&"p1_saltar"))
			_ok("y el salto no sale", not _h1.esta_en_el_aire())
			Input.action_press(&"p1_derecha")
			_x = _h1.global_position.x
			siguiente()
		6:
			if _ticks < 15:
				return
			_ok("todavia carga", _h1.esta_en_wind_up())
			_igual("y no se movio", _h1.global_position.x, _x)
			siguiente()
		7:
			if _h1.esta_en_wind_up():
				return
			if _ticks < 45:
				return
			_ok("al salir la plegaria vuelve a caminar", _h1.global_position.x > _x + 0.3)
			Input.action_release(&"p1_derecha")
			siguiente()
		8:
			# Que frene del todo: lo que resbala por la friccion no es caminar.
			if _ticks < 15:
				return
			print("--- tirado no hace nada ---")
			_h1.recibir_dano(999.0)
			_ok("cayo", not _h1.esta_viva())
			_h1._unhandled_input(accion(&"p1_saltar"))
			_ok("no salta", not _h1.esta_en_el_aire())
			var mana := _h1.mana
			_h1._unhandled_input(accion(&"p1_ligera"))
			_igual("ni cura", _h1.mana, mana)
			Input.action_press(&"p1_derecha")
			_x = _h1.global_position.x
			siguiente()
		9:
			if _ticks < 10:
				return
			_igual("ni camina", _h1.global_position.x, _x)
			Input.action_release(&"p1_derecha")
			terminar()


## Las acciones del proyecto y a que las ata cada evento.
func _mapa() -> void:
	print("--- el mapa: siete acciones por jugador y tres compartidas ---")
	var faltan := PackedStringArray()
	for jugador in range(1, Jugadores.MAXIMO + 1):
		for entrada in Jugadores.ENTRADAS:
			if not InputMap.has_action(Jugadores.accion(jugador, entrada)):
				faltan.append(Jugadores.accion(jugador, entrada))
	for compartida: StringName in [&"pause", &"continuar", &"reiniciar"]:
		if not InputMap.has_action(compartida):
			faltan.append(compartida)
	_ok("existen las 2 x 7 + 3 (faltan: %s)" % ", ".join(faltan), faltan.is_empty())
	for vieja: StringName in [&"move_left", &"select", &"cancel", &"habilidad_1", &"dash", &"saltar"]:
		_ok("ya no existe %s" % vieja, not InputMap.has_action(vieja))

	_ok("p1_ligera tiene la J", _tiene_tecla(&"p1_ligera", KEY_J))
	_ok("y la X del pad 0", _tiene_boton(&"p1_ligera", JOY_BUTTON_X, 0))
	_ok("p2_ligera tiene la coma y el 1 del teclado numerico",
		_tiene_tecla(&"p2_ligera", KEY_COMMA) and _tiene_tecla(&"p2_ligera", KEY_KP_1))
	_ok("y la X del pad 1", _tiene_boton(&"p2_ligera", JOY_BUTTON_X, 1))
	_ok("pause tiene el Start de cualquier pad", _tiene_boton(&"pause", JOY_BUTTON_START, CUALQUIER_PAD))
	_ok("continuar tambien", _tiene_boton(&"continuar", JOY_BUTTON_START, CUALQUIER_PAD))
	_ok("reiniciar tiene el Back de cualquier pad",
		_tiene_boton(&"reiniciar", JOY_BUTTON_BACK, CUALQUIER_PAD))
	_igual("el stick tiene zona muerta de 0.25", InputMap.action_get_deadzone(&"p1_izquierda"), 0.25)
	_igual("los botones, de 0.2", InputMap.action_get_deadzone(&"p1_ligera"), 0.2)

	print("--- el device separa a un jugador del otro ---")
	var x_pad_2 := _boton(JOY_BUTTON_X, 1)
	_ok("la X del pad 1 dispara p2_ligera", x_pad_2.is_action_pressed(&"p2_ligera"))
	_ok("y no p1_ligera", not x_pad_2.is_action_pressed(&"p1_ligera"))
	var x_pad_1 := _boton(JOY_BUTTON_X, 0)
	_ok("la del pad 0 es al reves",
		x_pad_1.is_action_pressed(&"p1_ligera") and not x_pad_1.is_action_pressed(&"p2_ligera"))
	var j := _tecla(KEY_J)
	_ok("la J es p1_ligera", j.is_action_pressed(&"p1_ligera") and not j.is_action_pressed(&"p2_ligera"))
	var coma := _tecla(KEY_COMMA)
	_ok("la coma es p2_ligera", coma.is_action_pressed(&"p2_ligera"))
	var stick := _eje(JOY_AXIS_LEFT_X, 1.0, 1)
	_ok("el stick del pad 1 a la derecha es p2_derecha",
		stick.is_action_pressed(&"p2_derecha") and not stick.is_action_pressed(&"p1_derecha"))
	_ok("un stick apenas movido no dispara nada",
		not _eje(JOY_AXIS_LEFT_X, 0.2, 1).is_action_pressed(&"p2_derecha"))
	_ok("el Start de cualquier pad pausa",
		_boton(JOY_BUTTON_START, 0).is_action_pressed(&"pause")
			and _boton(JOY_BUTTON_START, 1).is_action_pressed(&"pause"))


## Sin pads conectados (headless), cada jugador queda con el pad del mapa.
func _dispositivos() -> void:
	print("--- repartir los pads ---")
	_ok("no hay pads en esta prueba", Input.get_connected_joypads().is_empty())
	_ok("sin pads, P1 queda con el 0 y P2 con el 1",
		Jugadores.pad_de(1) == 0 and Jugadores.pad_de(2) == 1)
	Jugadores.aplicar_dispositivos()
	_ok("aplicar_dispositivos no rompe nada sin pads",
		_tiene_boton(&"p1_ligera", JOY_BUTTON_X, 0) and _tiene_boton(&"p2_ligera", JOY_BUTTON_X, 1))
	_ok("ni toca las compartidas", _tiene_boton(&"pause", JOY_BUTTON_START, CUALQUIER_PAD))


func _jugadores() -> void:
	print("--- Jugadores ---")
	_ok("accion(2, saltar) es p2_saltar", Jugadores.accion(2, &"saltar") == &"p2_saltar")
	_ok("etiquetas(2) nombra las flechas", Jugadores.etiquetas(2)["mover"].contains("Flechas"))
	_ok("etiquetas(1) son las de P1", Jugadores.etiquetas(1) == {
		"mover": "WASD / Stick", "ligera": "J / X", "pesada": "K / Y", "saltar": "Espacio / A"})
	var leyenda: GDScript = load("res://scripts/leyenda_controles.gd")
	var texto: String = leyenda.texto(1)
	_ok("la leyenda de P1 (%s)" % texto, texto == TEXTO_P1)
	_ok("es_entrada_de reconoce al dueno del boton",
		Jugadores.es_entrada_de(2, _boton(JOY_BUTTON_X, 1))
			and not Jugadores.es_entrada_de(1, _boton(JOY_BUTTON_X, 1)))
	_ok("y soltar no cuenta", not Jugadores.es_entrada_de(2, _boton(JOY_BUTTON_X, 1, false)))
	_ok("sin anotacion juega uno", Jugadores.cantidad_pedida(self) == 1)
	Jugadores.pedir_cantidad(self, 2)
	_ok("se pueden pedir dos", Jugadores.cantidad_pedida(self) == 2)
	Jugadores.pedir_cantidad(self, 7)
	_ok("y no mas de dos", Jugadores.cantidad_pedida(self) == Jugadores.MAXIMO)
	remove_meta(Jugadores.CANTIDAD)


func _por_healer() -> void:
	print("--- cada healer escucha solo a su jugador ---")
	_h1._unhandled_input(accion(&"p1_ligera"))
	_igual("p1_ligera hace curar al jugador 1", _h1.mana, 90.0)
	_igual("que cura al que tiene enfrente", _a1.vida, 58.0)
	_h2._unhandled_input(accion(&"p1_ligera"))
	_igual("y no al jugador 2", _h2.mana, 100.0)
	_igual("que no toca a su aliado", _a2.vida, 40.0)

	# Por el viewport, como llega de verdad: todos los healers ven el evento y
	# ninguno se lo queda.
	_espia.vistos.clear()
	root.push_input(accion(&"p2_ligera"))
	_igual("p2_ligera por el viewport hace curar al 2", _h2.mana, 90.0)
	_igual("y el 1 no cobra nada", _h1.mana, 90.0)
	_ok("el evento sigue viaje despues de los healers", _espia.vistos.size() == 1)


# --- Ayudantes ----------------------------------------------------------------

func _healer(jugador: int, pos: Vector3) -> Healer3D:
	var healer: Healer3D = load("res://scenes/3d/healer3d.tscn").instantiate()
	healer.jugador = jugador
	healer.position = pos
	return healer


## A 1 m al frente: en la caja de la ligera de su healer y lejos de la del
## otro, que esta 4 m mas alla en profundidad.
func _aliado(pos: Vector3) -> Unidad3D:
	var unidad: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	unidad.configurar(Unidad3D.Bando.ALIADO)
	unidad.position = pos
	unidad.vida = 40.0
	unidad.probabilidad_sangrado = 0.0
	return unidad


## Sin regeneracion ni combate: cada comprobacion mide solo lo que se apreto.
func _quietos() -> void:
	_h1.regeneracion_mana = 0.0
	_h2.regeneracion_mana = 0.0
	_a1.set_physics_process(false)
	_a2.set_physics_process(false)


func _mov(nombre: String) -> Movimiento:
	for mov in _todos():
		if mov.nombre == nombre:
			return mov
	return null


func _todos() -> Array[Movimiento]:
	var lista: Array[Movimiento] = []
	for archivo in ["toque", "vendaje", "plegaria", "bendicion", "oleada", "reanimar", "impulso", "caida"]:
		lista.append(load("res://resources/movimientos/%s.tres" % archivo))
	return lista


func _tiene_tecla(accion_: StringName, tecla: Key) -> bool:
	for evento in InputMap.action_get_events(accion_):
		if evento is InputEventKey and evento.physical_keycode == tecla:
			return true
	return false


func _tiene_boton(accion_: StringName, boton: JoyButton, device: int) -> bool:
	for evento in InputMap.action_get_events(accion_):
		if evento is InputEventJoypadButton and evento.button_index == boton \
				and evento.device == device:
			return true
	return false


func _tecla(tecla: Key) -> InputEventKey:
	var evento := InputEventKey.new()
	evento.physical_keycode = tecla
	evento.device = InputEvent.DEVICE_ID_KEYBOARD
	evento.pressed = true
	return evento


func _boton(boton: JoyButton, device: int, apretado: bool = true) -> InputEventJoypadButton:
	var evento := InputEventJoypadButton.new()
	evento.button_index = boton
	evento.device = device
	evento.pressed = apretado
	return evento


func _eje(eje: JoyAxis, valor: float, device: int) -> InputEventJoypadMotion:
	var evento := InputEventJoypadMotion.new()
	evento.axis = eje
	evento.axis_value = valor
	evento.device = device
	return evento
