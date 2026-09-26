extends SceneTree
## Genera el HUD de la batalla.
##
## Vive aparte de gen_scenes3d.gd porque cambia por otras razones: depende del
## tema y de los assets de interfaz, y se retoca mucho mas seguido que el mundo.
## Separado, tocar un panel no obliga a regenerar las escenas 3D; la batalla
## solo instancia lo que sale de aca.
##
## Arriba va una ficha por jugador, cada una en su esquina, y entre las dos lo
## que es de todos: el frente, el encuentro y los conteos. Abajo, los controles
## de cada jugador, del lado de su ficha. El centro queda libre hasta el final:
## por ahi pasa la linea de combate.
##
## Correr DESPUES de gen_ui.gd, que genera el tema, y ANTES de gen_scenes3d.gd,
## que mete el HUD dentro de la batalla:
##   godot --headless --path godot --script res://tools/gen_hud.gd

const RUTA_TEMA := "res://resources/ui/tema.tres"
const RUTA_HUD := "res://scenes/ui/hud.tscn"
const SCRIPT_FICHA := "res://scripts/hud/ficha_jugador.gd"
const SCRIPT_LEYENDA := "res://scripts/leyenda_controles.gd"
## Ancho de cada ficha y de cada esquina. Las dos esquinas miden esto aunque la
## del segundo este vacia: asi lo de arriba al centro queda centrado con uno o
## con dos jugadores.
const ANCHO_FICHA := 300.0
## Separacion de todo con los bordes de la pantalla.
const MARGEN_LADO := 24.0
const MARGEN_ARRIBA := 16.0
const MARGEN_ABAJO := 20.0


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
	# Todo el HUD ignora el mouse: no hay nada que clickear, y un panel que
	# se quedara con el mouse no tiene por que cambiar el foco de nadie.
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = load(RUTA_TEMA)
	hud.add_child(raiz)
	raiz.owner = hud

	_hud_superior(raiz, hud)
	_hud_centro(raiz, hud)
	_hud_inferior(raiz, hud)

	_guardar(hud, RUTA_HUD)


## Arriba, de punta a punta: la ficha de cada jugador en su esquina y, entre
## las dos, lo del encuentro. Arriba el campo es cielo: lo que va ahi no le
## tapa nada al jugador.
func _hud_superior(raiz: Control, hud: Node) -> void:
	var fila := HBoxContainer.new()
	fila.name = "Superior"
	fila.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# Solo el borde de arriba: el alto lo pone lo que tiene adentro, y crece
	# hacia abajo.
	fila.offset_left = MARGEN_LADO
	fila.offset_right = -MARGEN_LADO
	fila.offset_top = MARGEN_ARRIBA
	fila.offset_bottom = MARGEN_ARRIBA
	fila.add_theme_constant_override("separation", 16)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(raiz, fila, hud)

	var izquierda := _esquina("Esquina1")
	_colgar(fila, izquierda, hud)
	_ficha(izquierda, hud, 1)

	_encuentro(fila, hud)

	var derecha := _esquina("Esquina2")
	_colgar(fila, derecha, hud)
	_ficha(derecha, hud, 2)
	# Mientras el segundo no entro, en el lugar de su ficha se lo invita. Cual
	# de las dos se ve lo decide hud.gd.
	var invitacion := _etiqueta("Invitacion", &"Chico")
	invitacion.text = "Jugador 2: apreta un boton para entrar"
	invitacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	invitacion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	invitacion.visible = false
	_colgar(derecha, invitacion, hud, true)


## Columna de ancho fijo contra un borde. Lo de adentro se apila arriba.
func _esquina(nombre: String) -> VBoxContainer:
	var esquina := VBoxContainer.new()
	esquina.name = nombre
	esquina.custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	esquina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return esquina


## Entre las dos esquinas: el tira y afloja del frente, que encuentro es y que
## enseña, y cuantos quedan de cada lado.
func _encuentro(fila: Control, hud: Node) -> void:
	var columna := VBoxContainer.new()
	columna.name = "Encuentro"
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_theme_constant_override("separation", 6)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(fila, columna, hud)

	var frente := Control.new()
	frente.name = "Frente"
	frente.set_script(load("res://scripts/indicador_frente.gd"))
	frente.custom_minimum_size = Vector2(400, 26)
	frente.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(columna, frente, hud, true)

	# Titulo del encuentro y que enseña. Con autowrap: el objetivo del tercero
	# no entra en un renglon entre las dos fichas.
	var encabezado := _etiqueta("Encabezado", &"Subtitulo")
	encabezado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	encabezado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_colgar(columna, encabezado, hud, true)

	# Los conteos, debajo y mas chicos: se miran de reojo, no se leen.
	var contadores := _etiqueta("Contadores", &"Chico")
	contadores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_colgar(columna, contadores, hud, true)


## La ficha de un jugador (FichaJugador). Las dos salen de aca con los mismos
## nombres adentro, porque el script llega a cada nodo por su ruta:
##
##   FichaN (PanelFicha)
##     Columna
##       Cabecera: Titulo ("Jugador 1") y Combo ("x2 VENDAJE")
##       Vida: BarraVida y TextoVida
##       Mana: BarraMana y TextoMana
##       Aviso ("+18", "Sin mana")
##       Objetivo, Ligera y Pesada: la tarjeta (quien esta al frente y que
##       sale con cada boton)
func _ficha(padre: Control, hud: Node, jugador: int) -> void:
	var ficha := PanelContainer.new()
	ficha.name = "Ficha%d" % jugador
	ficha.set_script(load(SCRIPT_FICHA))
	ficha.set(&"jugador", jugador)
	ficha.theme_type_variation = &"PanelFicha"
	ficha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# La del segundo arranca oculta: aparece cuando entra.
	ficha.visible = jugador == 1
	_colgar(padre, ficha, hud, true)

	var columna := VBoxContainer.new()
	columna.name = "Columna"
	columna.add_theme_constant_override("separation", 4)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(ficha, columna, hud)

	# El combo va en la cabecera y no en un renglon propio: la ficha tiene que
	# ser baja, y "Jugador 1 ... x2 VENDAJE" se lee de una.
	var cabecera := HBoxContainer.new()
	cabecera.name = "Cabecera"
	cabecera.add_theme_constant_override("separation", 8)
	cabecera.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(columna, cabecera, hud)

	var titulo := _etiqueta("Titulo", &"TituloFicha")
	titulo.text = "Jugador %d" % jugador
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_colgar(cabecera, titulo, hud)

	# El combo y el aviso del jugador 1 conservan el nombre unico que tenian
	# en el HUD de uno solo (%Combo, %Aviso): las capturas los buscan asi. Los
	# del segundo no pueden llamarse igual en el mismo dueño.
	var combo := _etiqueta("Combo", &"ComboFicha")
	combo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_colgar(cabecera, combo, hud, jugador == 1)

	_barra(columna, hud, "Vida", &"BarraVida")
	_barra(columna, hud, "Mana", &"BarraMana")

	var aviso := _etiqueta("Aviso", &"AvisoFicha")
	aviso.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_colgar(columna, aviso, hud, jugador == 1)

	# La tarjeta: tres renglones chicos que llena TarjetaObjetivo. Recortados
	# y no partidos en dos: la ficha no puede cambiar de alto a cada paso.
	for nombre: String in ["Objetivo", "Ligera", "Pesada"]:
		var renglon := _etiqueta(nombre, &"Chico")
		renglon.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_colgar(columna, renglon, hud)


## Una barra con su numero al lado. El numero tiene ancho fijo: si no, la barra
## cambia de largo cuando la vida pasa de 100 a 99.
func _barra(columna: Control, hud: Node, nombre: String, variacion: StringName) -> void:
	var fila := HBoxContainer.new()
	fila.name = nombre
	fila.add_theme_constant_override("separation", 8)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(columna, fila, hud)

	var barra := ProgressBar.new()
	barra.name = "Barra" + nombre
	barra.theme_type_variation = variacion
	barra.custom_minimum_size = Vector2(0, 14)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barra.show_percentage = false
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(fila, barra, hud)

	var texto := _etiqueta("Texto" + nombre, &"Chico")
	texto.custom_minimum_size = Vector2(64, 0)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_colgar(fila, texto, hud)


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


## Abajo, los controles de cada jugador del lado de su ficha. La del segundo
## arranca oculta: con uno solo, no hay nada que leer ahi.
func _hud_inferior(raiz: Control, hud: Node) -> void:
	var fila := HBoxContainer.new()
	fila.name = "Inferior"
	# Anclada abajo y creciendo hacia arriba: queda apoyada sobre el margen
	# inferior, sea cual sea el alto del texto.
	fila.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fila.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fila.offset_left = MARGEN_LADO
	fila.offset_right = -MARGEN_LADO
	fila.offset_top = -MARGEN_ABAJO
	fila.offset_bottom = -MARGEN_ABAJO
	fila.add_theme_constant_override("separation", 16)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(raiz, fila, hud)

	_leyenda(fila, hud, "Leyenda", 1, HORIZONTAL_ALIGNMENT_LEFT)
	_leyenda(fila, hud, "Leyenda2", 2, HORIZONTAL_ALIGNMENT_RIGHT)


## Los tres botones y el movimiento de un jugador: es todo lo que hay que
## recordar.
func _leyenda(fila: Control, hud: Node, nombre: String, jugador: int,
		alineacion: HorizontalAlignment) -> void:
	var leyenda := _etiqueta(nombre, &"Chico")
	leyenda.set_script(load(SCRIPT_LEYENDA))
	leyenda.set(&"jugador", jugador)
	leyenda.horizontal_alignment = alineacion
	leyenda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leyenda.visible = jugador == 1
	_colgar(fila, leyenda, hud, true)


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
