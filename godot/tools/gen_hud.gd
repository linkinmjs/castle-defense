extends SceneTree
## Genera el HUD de la batalla.
##
## Vive aparte de gen_scenes3d.gd porque cambia por otras razones: depende del
## tema y de los assets de interfaz, y se retoca mucho mas seguido que el mundo.
## Separado, tocar un panel no obliga a regenerar las escenas 3D; la batalla
## solo instancia lo que sale de aca.
##
## La disposicion es la de un beat-em-up. Arriba, sobre el cielo, una ficha
## por jugador en cada esquina y entre las dos lo que es de todos: la barra
## del nivel, el encuentro y los conteos. El cartel de avanzar va a la derecha
## a media altura, la barra del jefe abajo al centro, y los controles de cada
## jugador abajo, del lado de su ficha. El centro queda libre hasta el final:
## por ahi pasa la linea de combate (a 720p el suelo empieza en y ~ 255, y
## nada fijo baja de ahi salvo el borde de abajo).
##
## Correr DESPUES de gen_ui.gd, que genera el tema, y ANTES de gen_scenes3d.gd,
## que mete el HUD dentro de la batalla (la batalla lo instancia: con la
## escena ya generada, alcanza con correr esto):
##   godot --headless --path godot --script res://tools/gen_hud.gd

const RUTA_TEMA := "res://resources/ui/tema.tres"
const RUTA_HUD := "res://scenes/ui/hud.tscn"
const SCRIPT_FICHA := "res://scripts/hud/ficha_jugador.gd"
const SCRIPT_BARRA_FANTASMA := "res://scripts/hud/barra_fantasma.gd"
const SCRIPT_LINEA := "res://scripts/hud/linea_movimiento.gd"
const SCRIPT_SLOT := "res://scripts/hud/slot_movimiento.gd"
const SCRIPT_BARRA_NIVEL := "res://scripts/hud/barra_nivel.gd"
const SCRIPT_ENCABEZADO := "res://scripts/hud/encabezado_sector.gd"
const SCRIPT_CARTEL := "res://scripts/hud/cartel_avanzar.gd"
const SCRIPT_FLECHA := "res://scripts/hud/flecha_pixel.gd"
const SCRIPT_JEFE := "res://scripts/hud/barra_jefe.gd"
const SCRIPT_LEYENDA := "res://scripts/leyenda_controles.gd"
const SCRIPT_RESUMEN := "res://scripts/resumen_encuentro.gd"
## Ancho de cada ficha y de cada esquina. Las dos esquinas miden esto aunque la
## del segundo este vacia: asi lo de arriba al centro queda centrado con uno o
## con dos jugadores.
const ANCHO_FICHA := 320.0
## Separacion de todo con los bordes de la pantalla.
const MARGEN_LADO := 20.0
const MARGEN_ARRIBA := 14.0
const MARGEN_ABAJO := 14.0
## La barra del nivel: ancha para que los sectores se distingan, y lo justo
## de alto para las banderas y las marcas de los healers.
const MEDIDA_BARRA_NIVEL := Vector2(440, 28)
## Alto de los renglones fijos de la ficha. Fijos para que la ficha no cambie
## de alto cuando aparece la raya del combo o la barra de carga.
const ALTO_VENTANA := 4.0
const ALTO_VIDA := 14.0
const ALTO_MANA := 10.0
const ALTO_ESTADO := 26.0
const ANCHO_NUMERO := 60.0
## La barra del jefe: ancha, como en los beat-em-up.
const ANCHO_JEFE := 560.0
const ALTO_JEFE := 16.0
## El cartel de avanzar: a la derecha, un poco por encima de la mitad.
const ALTURA_CARTEL := 0.42
const MARGEN_CARTEL := 48.0


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

	# En este orden se dibujan: lo del final (el velo y el informe) va ultimo,
	# por encima de todo lo que queda puesto durante la batalla.
	_hud_superior(raiz, hud)
	_cartel_avanzar(raiz, hud)
	_barra_jefe(raiz, hud)
	_hud_inferior(raiz, hud)
	_hud_centro(raiz, hud)

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


## Entre las dos esquinas: la barra del nivel, que encuentro es y que enseña
## (con el cartel que lo anuncia), y cuantos quedan de cada lado.
func _encuentro(fila: Control, hud: Node) -> void:
	var columna := VBoxContainer.new()
	columna.name = "Encuentro"
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_theme_constant_override("separation", 4)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(fila, columna, hud)

	var barra := Control.new()
	barra.name = "BarraNivel"
	barra.set_script(load(SCRIPT_BARRA_NIVEL))
	barra.custom_minimum_size = MEDIDA_BARRA_NIVEL
	barra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(columna, barra, hud, true)

	# Los conteos, chicos y pegados a la barra: se miran de reojo, no se leen.
	# Van antes del encabezado para que el cartel que baja de el no les pase
	# por encima.
	var contadores := _etiqueta("Contadores", &"Chico")
	contadores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_colgar(columna, contadores, hud, true)

	_encabezado(columna, hud)


## El renglon del encuentro y, colgado de el, el cartel que entra desde arriba.
## El cartel no cuenta para el alto (lo pone el renglon) y se dibuja por encima
## de lo que haya debajo: entra y sale sin empujar a nadie.
##
##   Encabezado (EncabezadoSector)
##     Linea: "1. Mantener la linea · Curar a tiempo sostiene el frente."
##     Cartel: Titulo (grande) y Subtitulo (el objetivo)
func _encabezado(columna: Control, hud: Node) -> void:
	var encabezado := Control.new()
	encabezado.name = "Encabezado"
	encabezado.set_script(load(SCRIPT_ENCABEZADO))
	encabezado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encabezado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(columna, encabezado, hud, true)

	var linea := _etiqueta("Linea", &"ChicoClaro")
	linea.set_anchors_preset(Control.PRESET_TOP_WIDE)
	linea.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	linea.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_colgar(encabezado, linea, hud)

	var cartel := VBoxContainer.new()
	cartel.name = "Cartel"
	cartel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cartel.offset_top = 2
	cartel.offset_bottom = 2
	cartel.add_theme_constant_override("separation", 2)
	cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Por encima de lo que venga despues en la columna o en el campo.
	cartel.z_index = 1
	# Encoge hacia arriba al centro: hacia el renglon que queda.
	cartel.offset_transform_enabled = true
	cartel.offset_transform_pivot_ratio = Vector2(0.5, 0.0)
	cartel.visible = false
	_colgar(encabezado, cartel, hud)

	var titulo := _etiqueta("Titulo", &"Titulo")
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_colgar(cartel, titulo, hud)

	var subtitulo := _etiqueta("Subtitulo", &"Subtitulo")
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_colgar(cartel, subtitulo, hud)


## La ficha de un jugador (FichaJugador). Las dos salen de aca con los mismos
## nombres adentro, porque el script llega a cada nodo por su ruta:
##
##   FichaN (PanelFicha)
##     Columna
##       Cabecera: Titulo ("Jugador 1") y Combo ("x2 VENDAJE")
##       Ventana: BarraVentana, la raya de lo que queda para encadenar
##       Vida: PilaVida (BarraFantasma: Fantasma y Vida) y TextoVida
##       Mana: BarraMana y TextoMana
##       Estado: Aviso ("+18", "Sin mana") o Carga (NombreCarga y BarraCarga)
##       Objetivo: quien esta al frente
##       Ligera y Pesada (LineaMovimiento): Slot, Tecla/Letra y Texto
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
	columna.add_theme_constant_override("separation", 3)
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
	# El golpe de cada paso escala desde el borde derecho, donde esta el texto.
	combo.offset_transform_enabled = true
	combo.offset_transform_pivot_ratio = Vector2(1.0, 0.5)
	_colgar(cabecera, combo, hud, jugador == 1)

	var ventana := _hueco("Ventana", ALTO_VENTANA)
	_colgar(columna, ventana, hud)
	var raya := _barra("BarraVentana", &"BarraVentana")
	raya.set_anchors_preset(Control.PRESET_FULL_RECT)
	raya.max_value = 1.0
	raya.visible = false
	_colgar(ventana, raya, hud)

	_fila_vida(columna, hud)
	_fila_mana(columna, hud)
	_fila_estado(columna, hud, jugador)

	# Quien esta al frente: un renglon chico, recortado y no partido en dos,
	# que la ficha no puede cambiar de alto a cada paso.
	var objetivo := _etiqueta("Objetivo", &"Chico")
	objetivo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_colgar(columna, objetivo, hud)

	for nombre: String in ["Ligera", "Pesada"]:
		_linea_movimiento(columna, hud, nombre)


## Vida con fantasma: dos barras una encima de la otra, el fantasma atras.
func _fila_vida(columna: Control, hud: Node) -> void:
	var fila := HBoxContainer.new()
	fila.name = "Vida"
	fila.add_theme_constant_override("separation", 8)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(columna, fila, hud)

	var pila := _pila_fantasma("PilaVida", ALTO_VIDA)
	_colgar(fila, pila, hud)
	_colgar_barras_fantasma(pila, hud)

	_colgar(fila, _numero("TextoVida"), hud)


func _fila_mana(columna: Control, hud: Node) -> void:
	var fila := HBoxContainer.new()
	fila.name = "Mana"
	fila.add_theme_constant_override("separation", 8)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(columna, fila, hud)

	var barra := _barra("BarraMana", &"BarraMana")
	barra.custom_minimum_size = Vector2(0, ALTO_MANA)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_colgar(fila, barra, hud)

	_colgar(fila, _numero("TextoMana"), hud)


## El renglon del aviso, que mientras algo carga muestra la carga en su lugar:
## las dos cosas no pasan juntas, y asi la ficha no suma un renglon.
func _fila_estado(columna: Control, hud: Node, jugador: int) -> void:
	var estado := _hueco("Estado", ALTO_ESTADO)
	_colgar(columna, estado, hud)

	var aviso := _etiqueta("Aviso", &"AvisoFicha")
	aviso.set_anchors_preset(Control.PRESET_FULL_RECT)
	aviso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aviso.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_colgar(estado, aviso, hud, jugador == 1)

	var carga := HBoxContainer.new()
	carga.name = "Carga"
	carga.set_anchors_preset(Control.PRESET_FULL_RECT)
	carga.add_theme_constant_override("separation", 8)
	carga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carga.visible = false
	_colgar(estado, carga, hud)

	var nombre := _etiqueta("NombreCarga", &"AvisoFicha")
	nombre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_colgar(carga, nombre, hud)

	var barra := _barra("BarraCarga", &"BarraCarga")
	barra.max_value = 1.0
	barra.custom_minimum_size = Vector2(0, ALTO_MANA)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_colgar(carga, barra, hud)


## Un boton de la tarjeta: icono en su marco, la tecla y lo que haria.
func _linea_movimiento(columna: Control, hud: Node, nombre: String) -> void:
	var linea := HBoxContainer.new()
	linea.name = nombre
	linea.set_script(load(SCRIPT_LINEA))
	linea.add_theme_constant_override("separation", 6)
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(columna, linea, hud)

	var slot := Control.new()
	slot.name = "Slot"
	slot.set_script(load(SCRIPT_SLOT))
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(linea, slot, hud)

	var tecla := PanelContainer.new()
	tecla.name = "Tecla"
	tecla.theme_type_variation = &"TeclaFicha"
	tecla.custom_minimum_size = Vector2(26, 0)
	tecla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tecla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(linea, tecla, hud)

	var letra := _etiqueta("Letra", &"LetraTecla")
	letra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_colgar(tecla, letra, hud)

	# Hasta dos renglones: "Plegaria: +35 HP (5 se desperdician)" no entra en
	# uno al lado del icono, y dos entran en el alto del icono.
	var texto := _etiqueta("Texto", &"Chico")
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.max_lines_visible = 2
	texto.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_colgar(linea, texto, hud)


## Un hueco de alto fijo, para lo que aparece y desaparece sin mover lo demas.
func _hueco(nombre: String, alto: float) -> Control:
	var hueco := Control.new()
	hueco.name = nombre
	hueco.custom_minimum_size = Vector2(0, alto)
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hueco


## Una BarraFantasma vacia, del alto dado. Las barras se cuelgan aparte:
## _colgar_barras_fantasma necesita que la pila ya este en el arbol.
func _pila_fantasma(nombre: String, alto: float) -> Control:
	var pila := Control.new()
	pila.name = nombre
	pila.set_script(load(SCRIPT_BARRA_FANTASMA))
	pila.custom_minimum_size = Vector2(0, alto)
	pila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pila.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pila


## El fantasma atras (con el fondo de la barra) y la vida adelante.
func _colgar_barras_fantasma(pila: Control, hud: Node) -> void:
	var fantasma := _barra("Fantasma", &"BarraFantasma")
	fantasma.set_anchors_preset(Control.PRESET_FULL_RECT)
	_colgar(pila, fantasma, hud)
	var vida := _barra("Vida", &"BarraVida")
	vida.set_anchors_preset(Control.PRESET_FULL_RECT)
	_colgar(pila, vida, hud)


func _barra(nombre: String, variacion: StringName) -> ProgressBar:
	var barra := ProgressBar.new()
	barra.name = nombre
	barra.theme_type_variation = variacion
	barra.show_percentage = false
	barra.step = 0.0
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return barra


## El numero al lado de una barra. Ancho fijo: si no, la barra cambia de
## largo cuando la vida pasa de 100 a 99.
func _numero(nombre: String) -> Label:
	var texto := _etiqueta(nombre, &"Chico")
	texto.custom_minimum_size = Vector2(ANCHO_NUMERO, 0)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return texto


## "¡AVANZAR →!" a la derecha, un poco por encima de la mitad. Crece hacia la
## izquierda desde el margen: su ancho lo pone el texto.
func _cartel_avanzar(raiz: Control, hud: Node) -> void:
	var cartel := HBoxContainer.new()
	cartel.name = "CartelAvanzar"
	cartel.set_script(load(SCRIPT_CARTEL))
	cartel.anchor_left = 1.0
	cartel.anchor_right = 1.0
	cartel.anchor_top = ALTURA_CARTEL
	cartel.anchor_bottom = ALTURA_CARTEL
	cartel.offset_left = -MARGEN_CARTEL
	cartel.offset_right = -MARGEN_CARTEL
	cartel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	cartel.grow_vertical = Control.GROW_DIRECTION_BOTH
	cartel.add_theme_constant_override("separation", 10)
	cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartel.offset_transform_enabled = true
	cartel.visible = false
	_colgar(raiz, cartel, hud, true)

	var texto := _etiqueta("Texto", &"Cartel")
	texto.text = "¡AVANZAR"
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_colgar(cartel, texto, hud)

	var flecha := Control.new()
	flecha.name = "Flecha"
	flecha.set_script(load(SCRIPT_FLECHA))
	flecha.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flecha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flecha.offset_transform_enabled = true
	_colgar(cartel, flecha, hud)

	var cierre := _etiqueta("Cierre", &"Cartel")
	cierre.text = "!"
	cierre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_colgar(cartel, cierre, hud)


## El centro se usa solo al terminar: el velo que apaga el campo, el cartel y,
## debajo, el informe.
func _hud_centro(raiz: Control, hud: Node) -> void:
	var velo := ColorRect.new()
	velo.name = "VeloFinal"
	velo.color = Color(0.02, 0.02, 0.05, 0.5)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.visible = false
	_colgar(raiz, velo, hud, true)

	var centro := CenterContainer.new()
	centro.name = "Centro"
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(raiz, centro, hud)

	var columna := VBoxContainer.new()
	columna.name = "ColumnaCentro"
	columna.add_theme_constant_override("separation", 10)
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(centro, columna, hud)

	var desenlace := _etiqueta("Desenlace", &"TituloGrande")
	desenlace.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Entra creciendo desde el centro y se sacude: sobre la transformacion
	# visual, para no mover el informe que tiene debajo.
	desenlace.offset_transform_enabled = true
	desenlace.visible = false
	_colgar(columna, desenlace, hud, true)

	var resumen := PanelContainer.new()
	resumen.name = "Resumen"
	resumen.set_script(load(SCRIPT_RESUMEN))
	resumen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resumen.visible = false
	_colgar(columna, resumen, hud, true)


## Abajo al centro, ancha, con el nombre encima. Apoyada sobre las leyendas,
## que van al pie.
func _barra_jefe(raiz: Control, hud: Node) -> void:
	var jefe := VBoxContainer.new()
	jefe.name = "BarraJefe"
	jefe.set_script(load(SCRIPT_JEFE))
	jefe.anchor_left = 0.5
	jefe.anchor_right = 0.5
	jefe.anchor_top = 1.0
	jefe.anchor_bottom = 1.0
	jefe.offset_left = -ANCHO_JEFE * 0.5
	jefe.offset_right = ANCHO_JEFE * 0.5
	jefe.offset_top = -MARGEN_ABAJO - 26.0
	jefe.offset_bottom = -MARGEN_ABAJO - 26.0
	jefe.grow_vertical = Control.GROW_DIRECTION_BEGIN
	jefe.add_theme_constant_override("separation", 2)
	jefe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jefe.offset_transform_enabled = true
	jefe.visible = false
	_colgar(raiz, jefe, hud, true)

	var nombre := _etiqueta("Nombre", &"Subtitulo")
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_colgar(jefe, nombre, hud)

	var pila := _pila_fantasma("Barra", ALTO_JEFE)
	_colgar(jefe, pila, hud)
	_colgar_barras_fantasma(pila, hud)


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
	# Ya empaquetado: sin liberarlo, el arbol queda colgado hasta el final del
	# proceso y Godot avisa la fuga al salir.
	nodo.free()
