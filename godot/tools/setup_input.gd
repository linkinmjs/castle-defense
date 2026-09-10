extends SceneTree
## Agrega las acciones de las habilidades al Input Map del proyecto.


func _initialize() -> void:
	_accion("habilidad_1", [KEY_1, KEY_Q])
	_accion("habilidad_2", [KEY_2, KEY_E])
	_accion("habilidad_3", [KEY_3])
	_accion("dash", [KEY_SHIFT])
	_accion("saltar", [KEY_SPACE])
	ProjectSettings.save()
	print("acciones de habilidades agregadas")
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
