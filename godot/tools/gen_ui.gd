extends SceneTree
## Genera el tema de la interfaz y las escenas de menu.
##
## El tema junta en un solo lugar lo que antes estaba repartido: cada Label
## repetia los mismos cinco overrides, los colores estaban duplicados en cinco
## scripts y las ProgressBar se estilaban a mano en runtime.
##
## Las coordenadas de cada pieza salieron de tools/inspeccionar_atlas.gd sobre
## las hojas del pack; estan en 1x y se multiplican por ESCALA, que tiene que
## coincidir con la de extraer_ui.gd.
##
## Correr DESPUES de extraer_ui.gd + --import:
##   godot --headless --path godot --script res://tools/gen_ui.gd

const ESCALA := 2

const DIR_TEMA := "res://resources/ui"
const RUTA_TEMA := "res://resources/ui/tema.tres"
const DIR_ESCENAS := "res://scenes/ui"
## Si algun dia entra una fuente de pixel art, alcanza con dejarla aca.
const RUTA_FUENTE := "res://assets/fonts/ui.ttf"

const BOTONES := "res://assets/ui/botones.png"
const PANEL_MENU := "res://assets/ui/panel_menu.png"
const PANEL_OPCIONES := "res://assets/ui/panel_opciones.png"
const PANEL_DESENLACE := "res://assets/ui/panel_desenlace.png"
const PANEL_FICHA := "res://assets/ui/panel_ficha.png"

# --- Regiones en 1x -----------------------------------------------------------
# Los botones del pack traen el texto en ingles dibujado encima (RESUME, QUIT).
# Estos cuatro son los que estan en blanco: el texto lo pone el Button.
const BOTON_NORMAL := Rect2i(3, 96, 42, 16)
const BOTON_PULSADO := Rect2i(3, 113, 42, 15)
const BOTON_ENCIMA := Rect2i(99, 96, 42, 16)
const BOTON_ENCIMA_PULSADO := Rect2i(99, 113, 42, 15)
## Margenes 9-slice del boton: cubren las esquinas redondeadas para que al
## estirarlo solo crezca el centro.
const BORDE_BOTON := Vector4i(8, 5, 8, 6)

## De cada hoja se usa el panel vacio, que es el que se puede estirar.
const MARCO_MENU := Rect2i(96, 4, 80, 168)
const MARCO_OPCIONES := Rect2i(7, 0, 98, 149)
const MARCO_DESENLACE := Rect2i(11, 299, 90, 74)
## El marco de madera mide 4 px; con 6 se toma ese borde y un respiro, y el
## centro que se estira queda relleno liso. Con margenes mas anchos entraban
## vetas del marco en la zona estirable y se veian como manchas alargadas.
const BORDE_MARCO := Vector4i(6, 6, 6, 6)

## Barra del panel de ficha: vacia y llena.
const FICHA_VACIA := Rect2i(2, 2, 84, 30)
const FICHA_LLENA := Rect2i(98, 2, 84, 30)

# --- Paleta -------------------------------------------------------------------
# La que el juego ya venia usando, ahora en un solo lugar.
const MANA := Color("4a9fd4")
const VIDA := Color("c94b3f")
const EXITO := Color("9fd88f")
const FALLO := Color("e07a6a")
const AVISO := Color(1.0, 0.92, 0.65)
const FONDO := Color("161a27")
const TINTA := Color(0.94, 0.95, 1.0)
const TINTA_TENUE := Color(0.72, 0.76, 0.88)
## El texto sobre los paneles de madera va oscuro: el relleno es crema.
const TINTA_PANEL := Color(0.13, 0.09, 0.05)
const SOMBRA := Color(0, 0, 0, 0.8)


func _initialize() -> void:
	if not ResourceLoader.exists(BOTONES):
		print("Faltan los assets. Correr primero:")
		print("  --script res://tools/extraer_ui.gd")
		print("  --import")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_TEMA))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_ESCENAS))

	var tema := _crear_tema()
	_guardar_recurso(tema, RUTA_TEMA)

	print("--- escenas ---")
	_crear_menu_principal(tema)
	_crear_menu_pausa(tema)

	print("")
	print("TODO OK")
	quit()


# --- Escenas ------------------------------------------------------------------

func _crear_menu_principal(tema: Theme) -> void:
	var raiz := Control.new()
	raiz.name = "MenuPrincipal"
	raiz.set_script(load("res://scripts/ui/menu_principal.gd"))
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = tema

	var fondo := ColorRect.new()
	fondo.name = "Fondo"
	fondo.color = FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hijo(raiz, fondo, raiz)

	var centro := CenterContainer.new()
	centro.name = "Centro"
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hijo(raiz, centro, raiz)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.theme_type_variation = &"PanelMenu"
	panel.custom_minimum_size = Vector2(460, 0)
	_hijo(centro, panel, raiz)

	var columna := VBoxContainer.new()
	columna.name = "Columna"
	columna.add_theme_constant_override("separation", 14)
	_hijo(panel, columna, raiz)

	var titulo := Label.new()
	titulo.name = "Titulo"
	titulo.text = "CASTLE DEFENSE"
	titulo.theme_type_variation = &"TituloPanel"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hijo(columna, titulo, raiz)

	var bajada := Label.new()
	bajada.name = "Bajada"
	bajada.text = "Sos el medico de una batalla que no controlas.
No podes salvar a todos."
	bajada.theme_type_variation = &"SobrePanel"
	bajada.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hijo(columna, bajada, raiz)

	# Las tres vistas se turnan en el mismo hueco: botonera, lecciones, opciones.
	var botonera := VBoxContainer.new()
	botonera.name = "Botonera"
	botonera.add_theme_constant_override("separation", 8)
	_hijo(columna, botonera, raiz, true)
	_boton(botonera, raiz, "Jugar", "Jugar")
	# Cuantos juegan, al lado de Jugar: es lo que se decide antes de arrancar.
	# El texto lo pone menu_principal.gd con lo que este anotado.
	_boton(botonera, raiz, "Jugadores", "Jugadores: 1")
	_boton(botonera, raiz, "Lecciones_boton", "Lecciones")
	_boton(botonera, raiz, "Opciones_boton", "Opciones")
	_boton(botonera, raiz, "Salir", "Salir")

	var lecciones := VBoxContainer.new()
	lecciones.name = "Lecciones"
	lecciones.add_theme_constant_override("separation", 10)
	lecciones.visible = false
	_hijo(columna, lecciones, raiz, true)
	var lista := VBoxContainer.new()
	lista.name = "ListaLecciones"
	lista.add_theme_constant_override("separation", 10)
	_hijo(lecciones, lista, raiz, true)
	_boton(lecciones, raiz, "VolverLecciones", "Volver")

	_armar_opciones(columna, raiz, "Opciones")

	_guardar_escena(raiz, "%s/menu_principal.tscn" % DIR_ESCENAS)


func _crear_menu_pausa(tema: Theme) -> void:
	var capa := CanvasLayer.new()
	capa.name = "MenuPausa"
	capa.set_script(load("res://scripts/ui/menu_pausa.gd"))
	# Por encima del HUD, que esta en la capa 1.
	capa.layer = 10

	var raiz := Control.new()
	raiz.name = "Raiz"
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = tema
	# STOP y no IGNORE: con el menu abierto los clicks no tienen que llegar al
	# campo, o se cura mientras el juego esta pausado.
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_hijo(capa, raiz, capa)

	var velo := ColorRect.new()
	velo.name = "Velo"
	velo.color = Color(0, 0, 0, 0.6)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hijo(raiz, velo, capa)

	var centro := CenterContainer.new()
	centro.name = "Centro"
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hijo(raiz, centro, capa)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.theme_type_variation = &"PanelMenu"
	panel.custom_minimum_size = Vector2(420, 0)
	_hijo(centro, panel, capa)

	var columna := VBoxContainer.new()
	columna.name = "Columna"
	columna.add_theme_constant_override("separation", 14)
	_hijo(panel, columna, capa)

	var titulo := Label.new()
	titulo.name = "Titulo"
	titulo.text = "EN PAUSA"
	titulo.theme_type_variation = &"TituloPanel"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hijo(columna, titulo, capa)

	var botonera := VBoxContainer.new()
	botonera.name = "BotoneraPausa"
	botonera.add_theme_constant_override("separation", 8)
	_hijo(columna, botonera, capa, true)
	_boton(botonera, capa, "Continuar", "Continuar")
	_boton(botonera, capa, "Reiniciar", "Reiniciar encuentro")
	_boton(botonera, capa, "OpcionesBoton", "Opciones")
	_boton(botonera, capa, "AlMenu", "Volver al menu")

	_armar_opciones(columna, capa, "OpcionesPausa")

	_guardar_escena(capa, "%s/menu_pausa.tscn" % DIR_ESCENAS)


## El mismo panel de ajustes sirve en el menu y en la pausa: se arma dos veces
## en vez de instanciar una escena aparte, asi cada menu es autocontenido.
func _armar_opciones(padre: Node, duenio: Node, nombre: String) -> Control:
	var raiz := VBoxContainer.new()
	raiz.name = nombre
	raiz.set_script(load("res://scripts/ui/panel_opciones.gd"))
	raiz.add_theme_constant_override("separation", 10)
	raiz.visible = false
	# Colgado antes de armar los hijos: set_owner exige que el nodo ya este en
	# el arbol del dueño.
	_hijo(padre, raiz, duenio, true)

	var completa := Button.new()
	completa.name = "PantallaCompleta"
	completa.text = "Pantalla completa: no"
	completa.toggle_mode = true
	_hijo(raiz, completa, duenio, true)

	var fila := HBoxContainer.new()
	fila.name = "FilaResolucion"
	fila.add_theme_constant_override("separation", 8)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	_hijo(raiz, fila, duenio, true)

	_boton(fila, duenio, "Anterior", "<")
	var resolucion := Label.new()
	resolucion.name = "Resolucion"
	resolucion.text = "1280 x 720"
	resolucion.theme_type_variation = &"SobrePanel"
	resolucion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resolucion.custom_minimum_size = Vector2(150, 0)
	_hijo(fila, resolucion, duenio, true)
	_boton(fila, duenio, "Siguiente", ">")

	_boton(raiz, duenio, "Volver", "Volver")
	return raiz


func _boton(padre: Node, duenio: Node, nombre: String, texto: String) -> Button:
	var boton := Button.new()
	boton.name = nombre
	boton.text = texto
	_hijo(padre, boton, duenio, true)
	return boton


## add_child + owner, que es lo que hace falta para que el nodo se guarde en la
## escena empaquetada.
func _hijo(padre: Node, nodo: Node, duenio: Node, unico: bool = false) -> void:
	padre.add_child(nodo)
	nodo.owner = duenio
	if unico:
		nodo.unique_name_in_owner = true


func _guardar_escena(nodo: Node, ruta: String) -> void:
	var empaquetada := PackedScene.new()
	var err := empaquetada.pack(nodo)
	if err == OK:
		err = ResourceSaver.save(empaquetada, ruta)
	print("  %s -> %s" % [ruta, "OK" if err == OK else "ERROR %d" % err])


# --- Tema ---------------------------------------------------------------------

func _crear_tema() -> Theme:
	var tema := Theme.new()
	tema.default_font_size = 16
	if ResourceLoader.exists(RUTA_FUENTE):
		tema.default_font = load(RUTA_FUENTE)
		print("  fuente: %s" % RUTA_FUENTE)
	else:
		print("  sin %s: se usa la fuente del motor" % RUTA_FUENTE)

	_tema_botones(tema)
	_tema_etiquetas(tema)
	_tema_paneles(tema)
	_tema_barras(tema)
	return tema


func _tema_botones(tema: Theme) -> void:
	var textura: Texture2D = load(BOTONES)
	tema.set_stylebox("normal", "Button", _marco(textura, BOTON_NORMAL, BORDE_BOTON))
	tema.set_stylebox("hover", "Button", _marco(textura, BOTON_ENCIMA, BORDE_BOTON))
	tema.set_stylebox("pressed", "Button", _marco(textura, BOTON_ENCIMA_PULSADO, BORDE_BOTON))
	# Deshabilitado: el mismo dibujo hundido, apagado con el color de la fuente.
	tema.set_stylebox("disabled", "Button", _marco(textura, BOTON_PULSADO, BORDE_BOTON))
	# Sin recuadro de foco: el estado "encima" ya dice donde esta el cursor, y el
	# marco punteado de Godot no pega con el pixel art.
	tema.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	tema.set_color("font_color", "Button", TINTA_PANEL)
	tema.set_color("font_hover_color", "Button", TINTA_PANEL)
	tema.set_color("font_pressed_color", "Button", TINTA_PANEL)
	tema.set_color("font_focus_color", "Button", TINTA_PANEL)
	tema.set_color("font_disabled_color", "Button", Color(0.13, 0.09, 0.05, 0.45))
	tema.set_font_size("font_size", "Button", 16)


func _tema_etiquetas(tema: Theme) -> void:
	tema.set_color("font_color", "Label", TINTA)
	tema.set_color("font_shadow_color", "Label", SOMBRA)
	tema.set_constant("shadow_offset_x", "Label", ESCALA)
	tema.set_constant("shadow_offset_y", "Label", ESCALA)
	tema.set_font_size("font_size", "Label", 16)

	# Variaciones: el nombre dice para que sirve, no como se ve.
	_variacion_etiqueta(tema, "Titulo", 34, TINTA)
	_variacion_etiqueta(tema, "Subtitulo", 20, TINTA)
	_variacion_etiqueta(tema, "Chico", 13, TINTA_TENUE)
	_variacion_etiqueta(tema, "Aviso", 22, AVISO)
	_variacion_etiqueta(tema, "Exito", 16, EXITO)
	_variacion_etiqueta(tema, "Fallo", 16, FALLO)
	# Sobre el relleno crema de los paneles el texto claro no se lee.
	_variacion_etiqueta(tema, "SobrePanel", 16, TINTA_PANEL, false)
	_variacion_etiqueta(tema, "TituloPanel", 26, TINTA_PANEL, false)
	# La ficha de cada jugador (FichaJugador): mas chica que el aviso de antes,
	# porque ahora son dos y van en las esquinas. El color del titulo y el del
	# combo los pone la ficha: son del jugador y del movimiento.
	_variacion_etiqueta(tema, "TituloFicha", 16, TINTA)
	_variacion_etiqueta(tema, "ComboFicha", 18, AVISO)
	_variacion_etiqueta(tema, "AvisoFicha", 16, AVISO)


func _variacion_etiqueta(tema: Theme, nombre: String, tamano: int, color: Color,
		con_sombra: bool = true) -> void:
	tema.set_type_variation(nombre, "Label")
	tema.set_font_size("font_size", nombre, tamano)
	tema.set_color("font_color", nombre, color)
	tema.set_color("font_shadow_color", nombre, SOMBRA if con_sombra else Color(0, 0, 0, 0))
	tema.set_constant("shadow_offset_x", nombre, ESCALA if con_sombra else 0)
	tema.set_constant("shadow_offset_y", nombre, ESCALA if con_sombra else 0)


func _tema_paneles(tema: Theme) -> void:
	# El panel por defecto es el oscuro translucido que ya usaba el HUD: sirve
	# para lo que se superpone al campo sin taparlo del todo.
	var oscuro := StyleBoxFlat.new()
	oscuro.bg_color = Color(0.05, 0.06, 0.09, 0.88)
	oscuro.border_color = Color(1, 1, 1, 0.14)
	oscuro.set_border_width_all(1)
	oscuro.set_content_margin_all(10)
	tema.set_stylebox("panel", "PanelContainer", oscuro)

	_variacion_panel(tema, "PanelMenu", load(PANEL_MENU), MARCO_MENU)
	_variacion_panel(tema, "PanelOpciones", load(PANEL_OPCIONES), MARCO_OPCIONES)
	_variacion_panel(tema, "PanelResumen", load(PANEL_DESENLACE), MARCO_DESENLACE)

	# Las fichas de los jugadores y la fila de acciones siguen oscuras y
	# translucidas: van encima del campo y un panel de madera opaco taparia la
	# batalla.
	_variacion_panel_plano(tema, "PanelFicha", Color(0, 0, 0, 0.72), 10)
	_variacion_panel_plano(tema, "PanelAcciones", Color(0, 0, 0, 0.45), 8)


func _variacion_panel(tema: Theme, nombre: String, textura: Texture2D, region: Rect2i) -> void:
	tema.set_type_variation(nombre, "PanelContainer")
	tema.set_stylebox("panel", nombre, _marco(textura, region, BORDE_MARCO, 18))


func _variacion_panel_plano(tema: Theme, nombre: String, color: Color, margen: int) -> void:
	tema.set_type_variation(nombre, "PanelContainer")
	var caja := StyleBoxFlat.new()
	caja.bg_color = color
	caja.border_color = Color(1, 1, 1, 0.12)
	caja.set_border_width_all(1)
	caja.set_content_margin_all(margen)
	tema.set_stylebox("panel", nombre, caja)


func _tema_barras(tema: Theme) -> void:
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0, 0, 0, 0.55)
	fondo.set_corner_radius_all(2)
	tema.set_stylebox("background", "ProgressBar", fondo)
	tema.set_stylebox("fill", "ProgressBar", _relleno(VIDA))

	# Una variación por barra: el color dice cual es sin leer el numero.
	tema.set_type_variation("BarraVida", "ProgressBar")
	tema.set_stylebox("fill", "BarraVida", _relleno(VIDA))
	tema.set_type_variation("BarraMana", "ProgressBar")
	tema.set_stylebox("fill", "BarraMana", _relleno(MANA))


func _relleno(color: Color) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = color
	caja.set_corner_radius_all(2)
	return caja


## Un stylebox recortado de una hoja del pack, estirable por 9-slice.
##
## StyleBoxTexture tiene region_rect propio, asi que no hace falta AtlasTexture:
## la textura es la hoja entera y la region dice que pedazo se dibuja.
func _marco(textura: Texture2D, region: Rect2i, borde: Vector4i,
		margen_interno: int = 0) -> StyleBoxTexture:
	var caja := StyleBoxTexture.new()
	caja.texture = textura
	caja.region_rect = Rect2(
		region.position.x * ESCALA, region.position.y * ESCALA,
		region.size.x * ESCALA, region.size.y * ESCALA)
	caja.texture_margin_left = borde.x * ESCALA
	caja.texture_margin_top = borde.y * ESCALA
	caja.texture_margin_right = borde.z * ESCALA
	caja.texture_margin_bottom = borde.w * ESCALA
	# Lo que separa el contenido del borde dibujado. Sin esto el texto se apoya
	# contra el marco.
	caja.content_margin_left = (borde.x + margen_interno) * ESCALA
	caja.content_margin_top = (borde.y + margen_interno) * ESCALA
	caja.content_margin_right = (borde.z + margen_interno) * ESCALA
	caja.content_margin_bottom = (borde.w + margen_interno) * ESCALA
	return caja


func _guardar_recurso(recurso: Resource, ruta: String) -> void:
	var err := ResourceSaver.save(recurso, ruta)
	print("  %s -> %s" % [ruta, "OK" if err == OK else "ERROR %d" % err])
	if err == OK:
		recurso.take_over_path(ruta)
