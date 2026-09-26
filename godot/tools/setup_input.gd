extends SceneTree
## Escribe en project.godot lo que conviene tener en codigo y no a mano en el
## editor: las acciones del Input Map, los nombres de las capas de colision,
## como se importan las texturas nuevas y la descripcion del proyecto.
##
## El Input Map sale entero de aca: tres botones y el movimiento por jugador,
## sin mouse, mas las tres acciones compartidas. Las acciones que ya no se usan
## se borran para que no queden teclas fantasma en el proyecto.
##
##               Teclado P1   Teclado P2        Joystick (device 0 = P1, 1 = P2)
##   mover       WASD         flechas           stick izquierdo y cruceta
##   ligera      J            , y Num 1         X
##   pesada      K            . y Num 2         Y
##   saltar      Espacio      / y Num 0         A
##   pause       Esc                            Start (cualquier pad)
##   continuar   Enter y Num Enter              Start (cualquier pad)
##   reiniciar   R                              Back (cualquier pad)

const DESCRIPCION := "Beat-em-up 2.5D de healers: curas a un ejercito automatico que avanza por las filas enemigas."

## Las del esquema de mouse y habilidades, que ya no existen.
const VIEJAS: Array[String] = [
	"move_left", "move_right", "move_up", "move_down", "select", "cancel",
	"habilidad_1", "habilidad_2", "habilidad_3", "dash", "saltar",
]
const ZONA_MUERTA := 0.2
## El stick con 0.2 todavia se movia solo en algunos pads gastados.
const ZONA_MUERTA_MOVER := 0.25
## Device -1: cualquier joystick. Para lo que no es de un jugador en particular.
const CUALQUIER_PAD := -1

## Por jugador: teclas de cada entrada (la primera es la que se muestra).
const TECLAS := {
	1: {
		&"izquierda": [KEY_A], &"derecha": [KEY_D], &"arriba": [KEY_W], &"abajo": [KEY_S],
		&"ligera": [KEY_J], &"pesada": [KEY_K], &"saltar": [KEY_SPACE],
	},
	2: {
		&"izquierda": [KEY_LEFT], &"derecha": [KEY_RIGHT], &"arriba": [KEY_UP], &"abajo": [KEY_DOWN],
		&"ligera": [KEY_COMMA, KEY_KP_1], &"pesada": [KEY_PERIOD, KEY_KP_2],
		&"saltar": [KEY_SLASH, KEY_KP_0],
	},
}
## Igual para todos los jugadores: cambia solo el device.
const EJES := {
	&"izquierda": [JOY_AXIS_LEFT_X, -1.0], &"derecha": [JOY_AXIS_LEFT_X, 1.0],
	&"arriba": [JOY_AXIS_LEFT_Y, -1.0], &"abajo": [JOY_AXIS_LEFT_Y, 1.0],
}
const BOTONES := {
	&"izquierda": JOY_BUTTON_DPAD_LEFT, &"derecha": JOY_BUTTON_DPAD_RIGHT,
	&"arriba": JOY_BUTTON_DPAD_UP, &"abajo": JOY_BUTTON_DPAD_DOWN,
	&"ligera": JOY_BUTTON_X, &"pesada": JOY_BUTTON_Y, &"saltar": JOY_BUTTON_A,
}


func _initialize() -> void:
	for vieja in VIEJAS:
		ProjectSettings.set_setting("input/" + vieja, null)

	for jugador in range(1, Jugadores.MAXIMO + 1):
		_jugador(jugador)

	_accion("pause", [_tecla(KEY_ESCAPE), _boton(JOY_BUTTON_START, CUALQUIER_PAD)])
	_accion("continuar", [
		_tecla(KEY_ENTER), _tecla(KEY_KP_ENTER), _boton(JOY_BUTTON_START, CUALQUIER_PAD),
	])
	_accion("reiniciar", [_tecla(KEY_R), _boton(JOY_BUTTON_BACK, CUALQUIER_PAD)])

	_capas_3d()
	_importacion()
	ProjectSettings.set_setting("application/config/description", DESCRIPCION)
	ProjectSettings.save()
	print("project.godot actualizado")
	quit()


## Las siete acciones de un jugador. El pad de cada uno es el del Input Map
## de fabrica (P1 el 0, P2 el 1); Jugadores.aplicar_dispositivos() lo corrige
## en runtime con los ids que haya de verdad.
func _jugador(jugador: int) -> void:
	var pad := jugador - 1
	var teclas: Dictionary = TECLAS[jugador]
	for entrada: StringName in Jugadores.ENTRADAS:
		var eventos: Array = []
		for tecla: Key in teclas[entrada]:
			eventos.append(_tecla(tecla))
		var mueve := EJES.has(entrada)
		if mueve:
			eventos.append(_eje(EJES[entrada][0], EJES[entrada][1], pad))
		eventos.append(_boton(BOTONES[entrada], pad))
		_accion(Jugadores.accion(jugador, entrada), eventos,
			ZONA_MUERTA_MOVER if mueve else ZONA_MUERTA)


## Sin tipar la lista a proposito: un Array[InputEvent] se guardaria en
## project.godot con otra sintaxis que la que escribe el editor.
func _accion(nombre: String, eventos: Array, zona_muerta: float = ZONA_MUERTA) -> void:
	ProjectSettings.set_setting("input/" + nombre, {
		"deadzone": zona_muerta,
		"events": eventos,
	})


## Por posicion fisica y no por letra: en un teclado AZERTY la A de WASD esta
## en otro lado, y lo que importa es la mano, no lo que dice la tecla.
func _tecla(tecla: Key) -> InputEventKey:
	var evento := InputEventKey.new()
	evento.physical_keycode = tecla
	# Explicito: desde 4.7 el teclado no es el device 0, que ahora puede ser un
	# joystick. Es el mismo valor que ya tenian las teclas del proyecto.
	evento.device = InputEvent.DEVICE_ID_KEYBOARD
	return evento


func _boton(boton: JoyButton, device: int) -> InputEventJoypadButton:
	var evento := InputEventJoypadButton.new()
	evento.button_index = boton
	evento.device = device
	return evento


func _eje(eje: JoyAxis, valor: float, device: int) -> InputEventJoypadMotion:
	var evento := InputEventJoypadMotion.new()
	evento.axis = eje
	evento.axis_value = valor
	evento.device = device
	return evento


## Solo los nombres: los bits los siguen fijando los scripts (las unidades en
## configurar, el healer en su _ready). Con nombre, el inspector y el
## depurador de fisica dicen que es cada capa en vez de mostrar un numero.
func _capas_3d() -> void:
	ProjectSettings.set_setting("layer_names/3d_physics/layer_1", "mundo")
	ProjectSettings.set_setting("layer_names/3d_physics/layer_2", "jugadores")
	ProjectSettings.set_setting("layer_names/3d_physics/layer_3", "aliados")
	ProjectSettings.set_setting("layer_names/3d_physics/layer_4", "enemigos")


## Todo el arte es pixel art: la compresion con perdida y los mipmaps le
## ensucian los bordes duros. Vale para los PNG que entren de ahora en mas; los
## que ya tienen su .import siguen con lo que diga ese archivo.
##
## Sin detect_3d no alcanza: al ver una textura usada en 3D (todo sprite de
## este juego lo es), el editor la pasa solo a VRAM con mipmaps. Asi quedaron
## grilla.png y el idle del healer.
func _importacion() -> void:
	ProjectSettings.set_setting("importer_defaults/texture", {
		"compress/mode": 0,
		"mipmaps/generate": false,
		"detect_3d/compress_to": 0,
	})
