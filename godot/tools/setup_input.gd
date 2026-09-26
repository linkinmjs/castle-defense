extends SceneTree
## Escribe en project.godot lo que conviene tener en codigo y no a mano en el
## editor: las acciones del Input Map, los nombres de las capas de colision,
## como se importan las texturas nuevas y la descripcion del proyecto.

const DESCRIPCION := "Beat-em-up 2.5D de healers: curas a un ejercito automatico que avanza por las filas enemigas."


func _initialize() -> void:
	_accion("habilidad_1", [KEY_1, KEY_Q])
	_accion("habilidad_2", [KEY_2, KEY_E])
	_accion("habilidad_3", [KEY_3])
	_accion("dash", [KEY_SHIFT])
	_accion("saltar", [KEY_SPACE])
	_accion("reiniciar", [KEY_R])
	_accion("continuar", [KEY_ENTER, KEY_KP_ENTER])
	_capas_3d()
	_importacion()
	ProjectSettings.set_setting("application/config/description", DESCRIPCION)
	ProjectSettings.save()
	print("project.godot actualizado")
	quit()


func _accion(nombre: String, teclas: Array) -> void:
	var eventos: Array = []
	for tecla: Key in teclas:
		var evento := InputEventKey.new()
		evento.physical_keycode = tecla
		eventos.append(evento)
	ProjectSettings.set_setting("input/" + nombre, {
		"deadzone": 0.2,
		"events": eventos,
	})


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
