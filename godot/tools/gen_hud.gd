extends SceneTree
## Genera el HUD de la batalla.
##
## Vive aparte de gen_scenes3d.gd porque cambia por otras razones: depende del
## tema y de los assets de interfaz, y se retoca mucho mas seguido que el mundo.
## Separado, tocar un panel no obliga a regenerar las escenas 3D; la batalla
## solo instancia lo que sale de aca.
##
## Correr DESPUES de gen_ui.gd, que genera el tema, y ANTES de gen_scenes3d.gd,
## que mete el HUD dentro de la batalla:
##   godot --headless --path godot --script res://tools/gen_hud.gd

const RUTA_TEMA := "res://resources/ui/tema.tres"
const RUTA_HUD := "res://scenes/ui/hud.tscn"


func _initialize() -> void:
	if not ResourceLoader.exists(RUTA_TEMA):
		print("Falta el tema. Correr primero:")
		print("  --script res://tools/gen_ui.gd")
		quit(1)
		return

	_crear_hud()
	quit()


func _crear_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/hud.gd"))
	# Explicito: el menu de pausa va en la 10 y tiene que quedar por encima.
	hud.layer = 1

	var raiz := Control.new()
	raiz.name = "Raiz"
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Todo el HUD ignora el mouse: los clicks tienen que llegar al campo.
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = load(RUTA_TEMA)
	hud.add_child(raiz)
	raiz.owner = hud

	_hud_superior(raiz, hud)
	_hud_centro(raiz, hud)
	_hud_inferior(raiz, hud)
	_hud_tarjeta(raiz, hud)

	_guardar(hud, RUTA_HUD)


## Arriba: los conteos a la izquierda y el frente al centro.
func _hud_superior(raiz: Control, hud: Node) -> void:
	var contadores := _etiqueta("Contadores", &"Subtitulo")
	contadores.set_anchors_preset(Control.PRESET_TOP_LEFT)
	contadores.position = Vector2(24, 16)
	_colgar(raiz, contadores, hud, true)

	var frente := Control.new()
	frente.name = "Frente"
	frente.set_script(load("res://scripts/indicador_frente.gd"))
	frente.set_anchors_preset(Control.PRESET_CENTER_TOP)
	frente.position = Vector2(-200, 14)
	frente.size = Vector2(400, 26)
	frente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(raiz, frente, hud, true)

	# Titulo del encuentro y que enseña, debajo del indicador de frente.
	var encabezado := _etiqueta("Encabezado", &"Subtitulo")
	encabezado.set_anchors_preset(Control.PRESET_CENTER_TOP)
	encabezado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	encabezado.position = Vector2(-320, 46)
	encabezado.size = Vector2(640, 52)
	_colgar(raiz, encabezado, hud, true)


## El centro se usa solo al terminar: el cartel y, debajo, el informe.
func _hud_centro(raiz: Control, hud: Node) -> void:
	var centro := CenterContainer.new()
	centro.name = "Centro"
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(raiz, centro, hud)

	var columna := VBoxContainer.new()
	columna.name = "ColumnaCentro"
	columna.add_theme_constant_override("separation", 12)
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(centro, columna, hud)

	var desenlace := _etiqueta("Desenlace", &"Titulo")
	desenlace.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desenlace.add_theme_font_size_override("font_size", 48)
	desenlace.visible = false
	_colgar(columna, desenlace, hud, true)

	var resumen := PanelContainer.new()
	resumen.name = "Resumen"
	resumen.set_script(load("res://scripts/resumen_encuentro.gd"))
	resumen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resumen.visible = false
	_colgar(columna, resumen, hud, true)


## Abajo a la izquierda: estado del healer, sus acciones y la ayuda.
func _hud_inferior(raiz: Control, hud: Node) -> void:
	var columna := VBoxContainer.new()
	columna.name = "Inferior"
	# Anclado abajo a la izquierda y creciendo hacia arriba: asi el bloque se
	# acomoda solo cuando un encuentro equipa mas o menos habilidades.
	columna.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	columna.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Offsets y no position: con position el contenedor arranca ahi y se apila
	# hacia abajo, saliendose de la pantalla. Fijando el borde de abajo, crece
	# hacia arriba y el bloque entero queda apoyado sobre el margen inferior.
	columna.offset_left = 24
	columna.offset_bottom = -20
	columna.add_theme_constant_override("separation", 6)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(raiz, columna, hud)

	var aviso := _etiqueta("Aviso", &"Aviso")
	_colgar(columna, aviso, hud, true)

	var slots := PanelContainer.new()
	slots.name = "Slots"
	slots.set_script(load("res://scripts/slots_habilidades.gd"))
	# Que mida lo que ocupan sus slots y no todo el ancho de la columna, que lo
	# fija el renglon de ayuda.
	slots.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(columna, slots, hud, true)

	_barra(columna, hud, "BarraVida", "TextoVida", &"BarraVida")
	_barra(columna, hud, "BarraMana", "TextoMana", &"BarraMana")

	var ayuda := _etiqueta("Ayuda", &"Chico")
	ayuda.text = "WASD mover     Espacio saltar     Click sobre un aliado para actuar     Esc pausa"
	_colgar(columna, ayuda, hud)


## La ficha del apuntado, abajo a la derecha: lejos de los slots y del centro,
## que es por donde pasa la linea de combate.
func _hud_tarjeta(raiz: Control, hud: Node) -> void:
	var tarjeta := PanelContainer.new()
	tarjeta.name = "Tarjeta"
	tarjeta.set_script(load("res://scripts/tarjeta_objetivo.gd"))
	tarjeta.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	tarjeta.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tarjeta.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tarjeta.offset_right = -24
	tarjeta.offset_bottom = -20
	tarjeta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(raiz, tarjeta, hud, true)


## Una barra con su numero al lado.
func _barra(columna: Control, hud: Node, nombre: String, nombre_texto: String,
		variacion: StringName) -> void:
	var fila := HBoxContainer.new()
	fila.name = nombre + "Fila"
	fila.add_theme_constant_override("separation", 10)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(columna, fila, hud)

	var barra := ProgressBar.new()
	barra.name = nombre
	barra.theme_type_variation = variacion
	barra.custom_minimum_size = Vector2(280, 18)
	barra.show_percentage = false
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(fila, barra, hud, true)

	var texto := _etiqueta(nombre_texto, &"Chico")
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_colgar(fila, texto, hud, true)


## Los colores y tamanos ya no se repiten por nodo: los pone el tema, y la
## variacion dice para que sirve cada etiqueta.
func _etiqueta(nombre: String, variacion: StringName) -> Label:
	var etiqueta := Label.new()
	etiqueta.name = nombre
	etiqueta.theme_type_variation = variacion
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


func _colgar(padre: Node, nodo: Node, duenio: Node, unico: bool = false) -> void:
	padre.add_child(nodo)
	nodo.owner = duenio
	if unico:
		nodo.unique_name_in_owner = true


func _guardar(nodo: Node, ruta: String) -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(ruta.get_base_dir()))
	var empaquetada := PackedScene.new()
	var err := empaquetada.pack(nodo)
	if err != OK:
		push_error("No se pudo empaquetar %s: %d" % [ruta, err])
		return
	err = ResourceSaver.save(empaquetada, ruta)
	print("%s -> %s" % [ruta, "OK" if err == OK else "ERROR %d" % err])
