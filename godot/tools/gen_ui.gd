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

# --- Cuerpos de letra ---------------------------------------------------------
# Pixelify Sans esta dibujada en una grilla de 11 pixeles por em (el pixel de
# diseno mide ~90.5 unidades de 1000). Sin suavizado, solo los multiplos de
# 11 caen enteros en esa grilla: a 16 o a 24 cada pixel de la letra sale de
# uno o de dos pixeles de pantalla segun donde caiga, y la letra se ve
# despareja. A 1920x1080 el lienzo escala 1.5, asi que los multiplos de 22
# siguen enteros alla tambien (22 -> 33, 44 -> 66).
const CHICO := 11
const NORMAL := 22
const GRANDE := 44
const ENORME := 66
## Un pixel de la fuente, para las sombras: la sombra corre un pixel de
## diseno, sea cual sea el cuerpo.
const PIXEL_FUENTE := 11

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
const TINTA_PANEL_TENUE := Color(0.13, 0.09, 0.05, 0.7)
## Las metas del resumen, sobre el crema: el verde y el rojo claros del HUD
## ahi no se leen.
const META_CUMPLIDA := Color("2e6a2a")
const META_FALLIDA := Color("8e2e1e")
const SOMBRA := Color(0, 0, 0, 0.8)
## Borde de barras y paneles del HUD: un pixel de la hoja del pack (2 px).
const BORDE_HUD := 2
const BORDE_OSCURO := Color(0, 0, 0, 0.85)

# --- Menu principal -----------------------------------------------------------
## El panel de madera mide lo mismo en todas sus vistas: si cambiara de ancho
## al pasar de la botonera a los controles, el menu saltaria. Lo que manda es
## la tabla de controles, la vista mas ancha.
const ANCHO_PANEL_MENU := 560.0
## El atardecer del campo, en capas: el cielo se estira y las demas se
## repiten en X. Cada una se dibuja al doble, como todo el pixel art del
## juego, y se apoya a `base` px del borde de abajo.
const CIELO := "res://assets/fondos/cielo.png"
const CAPAS_FONDO: Array[Dictionary] = [
	{"nombre": "Montanas", "ruta": "res://assets/fondos/montanas.png", "base": 96.0},
	{"nombre": "Castillo", "ruta": "res://assets/fondos/castillo.png", "base": 56.0},
	{"nombre": "Arboles", "ruta": "res://assets/fondos/arboles.png", "base": 0.0},
]
const ESCALA_FONDO := 2.0


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

## Titulo y bajada arriba, sobre el cielo; debajo el panel de madera, donde se
## turnan las vistas (botonera, lecciones, controles, opciones). Detras, el
## atardecer del campo en capas que menu_principal.gd corre despacio.
func _crear_menu_principal(tema: Theme) -> void:
	var raiz := Control.new()
	raiz.name = "MenuPrincipal"
	raiz.set_script(load("res://scripts/ui/menu_principal.gd"))
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = tema

	_fondo_vivo(raiz)

	var contenido := VBoxContainer.new()
	contenido.name = "Contenido"
	contenido.set_anchors_preset(Control.PRESET_FULL_RECT)
	contenido.offset_top = 36
	contenido.offset_bottom = -24
	contenido.add_theme_constant_override("separation", 4)
	contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hijo(raiz, contenido, raiz)

	var titulo := Label.new()
	titulo.name = "Titulo"
	titulo.text = "CASTLE DEFENSE"
	titulo.theme_type_variation = &"TituloGrande"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hijo(contenido, titulo, raiz, true)

	var bajada := Label.new()
	bajada.name = "Bajada"
	bajada.text = "Sos el medico de una batalla que no controlas. No podes salvar a todos."
	bajada.theme_type_variation = &"Subtitulo"
	bajada.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bajada.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hijo(contenido, bajada, raiz, true)

	var centro := CenterContainer.new()
	centro.name = "Centro"
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hijo(contenido, centro, raiz)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.theme_type_variation = &"PanelMenu"
	panel.custom_minimum_size = Vector2(ANCHO_PANEL_MENU, 0)
	_hijo(centro, panel, raiz, true)

	var columna := VBoxContainer.new()
	columna.name = "Columna"
	columna.add_theme_constant_override("separation", 10)
	_hijo(panel, columna, raiz)

	# Las vistas se turnan en el mismo hueco: botonera, lecciones, controles y
	# opciones.
	var botonera := VBoxContainer.new()
	botonera.name = "Botonera"
	botonera.add_theme_constant_override("separation", 8)
	_hijo(columna, botonera, raiz, true)
	_boton(botonera, raiz, "Jugar", "Jugar")
	_boton(botonera, raiz, "Lecciones_boton", "Lecciones")
	# Cuantos juegan, antes de los controles: es lo que se decide antes de
	# arrancar. El texto lo pone menu_principal.gd con lo que este anotado.
	_boton(botonera, raiz, "Jugadores", "Jugadores: 1")
	_boton(botonera, raiz, "Controles_boton", "Controles")
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

	_armar_controles(columna, raiz)
	_armar_opciones(columna, raiz, "Opciones")

	_guardar_escena(raiz, "%s/menu_principal.tscn" % DIR_ESCENAS)


## El atardecer del campo detras del menu: el cielo estirado y, delante, las
## montanas, el castillo y los arboles repetidos en X. Cada capa esta anclada
## abajo con el alto de su hoja y se agranda al doble desde su esquina de
## abajo; el ancho le sobra una repeticion entera, que es lo que
## menu_principal.gd va corriendo para el parallax.
func _fondo_vivo(raiz: Control) -> void:
	var fondo := Control.new()
	fondo.name = "Fondo"
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.clip_contents = true
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hijo(raiz, fondo, raiz, true)

	# Detras de todo, el color del pie de los arboles: si una capa quedara
	# corta, lo que asoma es noche y no gris.
	var base := ColorRect.new()
	base.name = "Base"
	base.color = FONDO
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hijo(fondo, base, raiz)

	var cielo := TextureRect.new()
	cielo.name = "Cielo"
	cielo.texture = load(CIELO)
	cielo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cielo.stretch_mode = TextureRect.STRETCH_SCALE
	cielo.set_anchors_preset(Control.PRESET_FULL_RECT)
	cielo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hijo(fondo, cielo, raiz, true)

	for capa: Dictionary in CAPAS_FONDO:
		var textura: Texture2D = load(capa["ruta"])
		var rect := TextureRect.new()
		rect.name = capa["nombre"]
		rect.texture = textura
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_TILE
		rect.anchor_left = 0.0
		rect.anchor_right = 1.0
		rect.anchor_top = 1.0
		rect.anchor_bottom = 1.0
		var alto := float(textura.get_height())
		var levantada: float = capa["base"]
		rect.offset_top = -alto - levantada
		rect.offset_bottom = -levantada
		rect.offset_left = 0.0
		rect.offset_right = float(textura.get_width())
		rect.scale = Vector2(ESCALA_FONDO, ESCALA_FONDO)
		rect.pivot_offset_ratio = Vector2(0.0, 1.0)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hijo(fondo, rect, raiz, true)


## La tabla de controles de los dos jugadores. La llena menu_principal.gd con
## Jugadores.etiquetas(), el mismo lugar que arma la leyenda del HUD: si
## cambia el mapa, cambian las dos.
func _armar_controles(padre: Node, duenio: Node) -> void:
	var vista := VBoxContainer.new()
	vista.name = "Controles"
	vista.add_theme_constant_override("separation", 12)
	vista.visible = false
	_hijo(padre, vista, duenio, true)

	var tabla := GridContainer.new()
	tabla.name = "TablaControles"
	tabla.columns = 3
	tabla.add_theme_constant_override("h_separation", 18)
	tabla.add_theme_constant_override("v_separation", 6)
	tabla.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hijo(vista, tabla, duenio, true)

	var pie := Label.new()
	pie.name = "PieControles"
	pie.theme_type_variation = &"ChicoPanel"
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hijo(vista, pie, duenio, true)

	_boton(vista, duenio, "VolverControles", "Volver")


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
	velo.color = Color(0.03, 0.02, 0.07, 0.68)
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
	panel.custom_minimum_size = Vector2(440, 0)
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
	resolucion.custom_minimum_size = Vector2(176, 0)
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
	# Ya empaquetado: el arbol armado no se usa mas, y sin liberarlo queda
	# colgado hasta que el proceso se va (y avisa la fuga al salir).
	nodo.free()


# --- Tema ---------------------------------------------------------------------

func _crear_tema() -> Theme:
	var tema := Theme.new()
	tema.default_font_size = NORMAL
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
	tema.set_font_size("font_size", "Button", NORMAL)


func _tema_etiquetas(tema: Theme) -> void:
	tema.set_color("font_color", "Label", TINTA)
	tema.set_color("font_shadow_color", "Label", SOMBRA)
	_sombra(tema, "Label", NORMAL)
	tema.set_font_size("font_size", "Label", NORMAL)

	# Variaciones: el nombre dice para que sirve, no como se ve.
	_variacion_etiqueta(tema, "Titulo", GRANDE, TINTA)
	# El titulo del juego en el menu y el cartel del final.
	_variacion_etiqueta(tema, "TituloGrande", ENORME, AVISO)
	_variacion_etiqueta(tema, "Subtitulo", NORMAL, TINTA)
	_variacion_etiqueta(tema, "Chico", CHICO, TINTA_TENUE)
	# Chico pero para leer, no de reojo: el renglon del encuentro.
	_variacion_etiqueta(tema, "ChicoClaro", CHICO, TINTA)
	_variacion_etiqueta(tema, "Aviso", NORMAL, AVISO)
	_variacion_etiqueta(tema, "Exito", NORMAL, EXITO)
	_variacion_etiqueta(tema, "Fallo", NORMAL, FALLO)
	# Sobre el relleno crema de los paneles el texto claro no se lee.
	_variacion_etiqueta(tema, "SobrePanel", NORMAL, TINTA_PANEL, false)
	_variacion_etiqueta(tema, "ChicoPanel", CHICO, TINTA_PANEL, false)
	_variacion_etiqueta(tema, "PiePanel", NORMAL, TINTA_PANEL_TENUE, false)
	_variacion_etiqueta(tema, "TituloPanel", GRANDE, TINTA_PANEL, false)
	_variacion_etiqueta(tema, "MetaCumplida", NORMAL, META_CUMPLIDA, false)
	_variacion_etiqueta(tema, "MetaFallida", NORMAL, META_FALLIDA, false)
	# La ficha de cada jugador (FichaJugador). El color del titulo y el del
	# combo los pone la ficha: son del jugador y del movimiento.
	_variacion_etiqueta(tema, "TituloFicha", NORMAL, TINTA)
	_variacion_etiqueta(tema, "ComboFicha", NORMAL, AVISO)
	_variacion_etiqueta(tema, "AvisoFicha", NORMAL, AVISO)
	# La letra dentro de la tecla dibujada: la tecla ya la despega del fondo.
	_variacion_etiqueta(tema, "LetraTecla", NORMAL, TINTA, false)
	# "¡AVANZAR →!": grande y del color de los avisos.
	_variacion_etiqueta(tema, "Cartel", GRANDE, AVISO)

	var chica := _fuente_chica(tema.default_font)
	if chica != null:
		for nombre in ["Chico", "ChicoClaro", "ChicoPanel"]:
			tema.set_font("font", nombre, chica)


## La misma fuente con mas aire entre palabras, para el cuerpo chico. El
## espacio de Pixelify Sans mide 200 unidades: a 11 px son 2 pixeles, casi lo
## mismo que separa dos letras, y "el frente" se leia "elfrente". A 22 ya son
## 4, y ahi no hace falta.
func _fuente_chica(base: Font) -> Font:
	if base == null:
		return null
	var variacion := FontVariation.new()
	variacion.base_font = base
	variacion.spacing_space = 2
	return variacion


func _variacion_etiqueta(tema: Theme, nombre: String, tamano: int, color: Color,
		con_sombra: bool = true) -> void:
	tema.set_type_variation(nombre, "Label")
	tema.set_font_size("font_size", nombre, tamano)
	tema.set_color("font_color", nombre, color)
	tema.set_color("font_shadow_color", nombre, SOMBRA if con_sombra else Color(0, 0, 0, 0))
	if con_sombra:
		_sombra(tema, nombre, tamano)
	else:
		tema.set_constant("shadow_offset_x", nombre, 0)
		tema.set_constant("shadow_offset_y", nombre, 0)
		tema.set_constant("shadow_outline_size", nombre, 0)


## La sombra corre un pixel de la fuente hacia abajo y a la derecha, sin
## contorno: con contorno la sombra engorda y la letra de pixeles se empasta.
func _sombra(tema: Theme, tipo: String, tamano: int) -> void:
	var corrimiento := maxi(floori(float(tamano) / PIXEL_FUENTE), 1)
	tema.set_constant("shadow_offset_x", tipo, corrimiento)
	tema.set_constant("shadow_offset_y", tipo, corrimiento)
	tema.set_constant("shadow_outline_size", tipo, 0)


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
	# El informe lleva menos margen: entra entre las dos fichas, y con el del
	# menu sus renglones se partian en dos.
	_variacion_panel(tema, "PanelResumen", load(PANEL_DESENLACE), MARCO_DESENLACE, 10)

	# Las fichas de los jugadores y la fila de acciones siguen oscuras y
	# translucidas: van encima del campo y un panel de madera opaco taparia la
	# batalla. El marco de la ficha lo tine despues la ficha con el color de
	# su jugador.
	_variacion_panel_plano(tema, "PanelFicha", Color(0.02, 0.03, 0.06, 0.78), 8, BORDE_HUD)
	_variacion_panel_plano(tema, "PanelAcciones", Color(0, 0, 0, 0.45), 8, 1)

	# La tecla dibujada de la tarjeta: oscura, con borde claro y mas gruesa
	# abajo, que es lo que la hace leer como una tecla.
	tema.set_type_variation("TeclaFicha", "PanelContainer")
	var tecla := StyleBoxFlat.new()
	tecla.bg_color = Color(0.1, 0.11, 0.16, 0.95)
	tecla.border_color = Color(0.86, 0.88, 0.95, 0.8)
	tecla.set_border_width_all(BORDE_HUD)
	tecla.border_width_bottom = BORDE_HUD * 2
	tecla.content_margin_left = 5
	tecla.content_margin_right = 5
	tecla.content_margin_top = 0
	tecla.content_margin_bottom = BORDE_HUD * 2
	tema.set_stylebox("panel", "TeclaFicha", tecla)


func _variacion_panel(tema: Theme, nombre: String, textura: Texture2D, region: Rect2i,
		margen: int = 18) -> void:
	tema.set_type_variation(nombre, "PanelContainer")
	tema.set_stylebox("panel", nombre, _marco(textura, region, BORDE_MARCO, margen))


func _variacion_panel_plano(tema: Theme, nombre: String, color: Color, margen: int,
		borde: int) -> void:
	tema.set_type_variation(nombre, "PanelContainer")
	var caja := StyleBoxFlat.new()
	caja.bg_color = color
	caja.border_color = Color(1, 1, 1, 0.14)
	caja.set_border_width_all(borde)
	caja.set_content_margin_all(margen)
	tema.set_stylebox("panel", nombre, caja)


## Las barras son rectangulos planos con un borde oscuro de un pixel del pack
## (2 px) y sin esquinas redondeadas: con radio, a este tamano, las esquinas
## salian con medio pixel suavizado al lado de todo lo demas duro.
func _tema_barras(tema: Theme) -> void:
	var fondo := _caja(Color(0, 0, 0, 0.6), BORDE_HUD)
	tema.set_stylebox("background", "ProgressBar", fondo)
	tema.set_stylebox("fill", "ProgressBar", _caja(VIDA, BORDE_HUD))

	# La vida va adelante de su fantasma: sin fondo propio, o lo taparia.
	_variacion_barra(tema, "BarraVida", StyleBoxEmpty.new(), _caja(VIDA, BORDE_HUD))
	# Detras, el fantasma del golpe: el rojo de la vida, oscurecido.
	_variacion_barra(tema, "BarraFantasma", fondo, _caja(VIDA.darkened(0.4), BORDE_HUD))
	_variacion_barra(tema, "BarraMana", fondo, _caja(MANA, BORDE_HUD))
	# La ventana del combo es una raya: sin borde, que en 4 px no entra.
	_variacion_barra(tema, "BarraVentana", _caja(Color(0, 0, 0, 0.5), 0), _caja(AVISO, 0))
	_variacion_barra(tema, "BarraCarga", fondo, _caja(AVISO, BORDE_HUD))


func _variacion_barra(tema: Theme, nombre: String, fondo: StyleBox, relleno: StyleBox) -> void:
	tema.set_type_variation(nombre, "ProgressBar")
	tema.set_stylebox("background", nombre, fondo)
	tema.set_stylebox("fill", nombre, relleno)


func _caja(color: Color, borde: int) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = color
	caja.border_color = BORDE_OSCURO
	caja.set_border_width_all(borde)
	caja.anti_aliasing = false
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
