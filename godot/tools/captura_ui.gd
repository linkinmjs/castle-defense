extends SceneTree
## Capturas de las pantallas de menu.
##
## Las pruebas dicen que los botones existen; esto dice si se ven bien. Correr
## SIN --headless: sin ventana no hay textura que guardar.
##   godot --path godot --script res://tools/captura_ui.gd

var _menu: Control
var _pausa: CanvasLayer
var _battle: Node
var _inicio := 0
var _paso := 0


func _initialize() -> void:
	_menu = load("res://scenes/ui/menu_principal.tscn").instantiate()
	root.add_child(_menu)
	_inicio = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	var t := (Time.get_ticks_msec() - _inicio) / 1000.0

	match _paso:
		0:
			if t >= 0.8:
				_tomar("ui_1_menu.png", "menu principal")
		1:
			if t >= 1.2:
				_menu.get_node("%Lecciones_boton").pressed.emit()
				_paso += 1
		2:
			if t >= 1.8:
				_tomar("ui_2_lecciones.png", "lista de lecciones")
		3:
			if t >= 2.2:
				_menu.get_node("%VolverLecciones").pressed.emit()
				_menu.get_node("%Opciones_boton").pressed.emit()
				_paso += 1
		4:
			if t >= 2.8:
				_tomar("ui_3_opciones.png", "opciones")
		5:
			if t >= 3.2:
				# La pausa se mira sobre la batalla, que es donde vive.
				_menu.queue_free()
				_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
				root.add_child(_battle)
				_paso += 1
		6:
			if t >= 4.5:
				_pausa = _battle.get_node("%MenuPausa")
				_pausa.abrir()
				_paso += 1
		7:
			if t >= 5.2:
				_tomar("ui_4_pausa.png", "menu de pausa")
		8:
			if t >= 5.6:
				_pausa.get_node("%OpcionesBoton").pressed.emit()
				_paso += 1
		9:
			if t >= 6.2:
				_tomar("ui_5_pausa_opciones.png", "opciones desde la pausa")
		10:
			# Sin esto el arbol queda pausado y el proceso no cierra bien.
			_pausa.cerrar()
			print("listo")
			return true
	return false


func _tomar(archivo: String, que: String) -> void:
	root.get_texture().get_image().save_png("user://" + archivo)
	print("  %-28s %s" % [archivo, que])
	_paso += 1
