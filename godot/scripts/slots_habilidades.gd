extends PanelContainer
## Fila de habilidades equipadas: icono, tecla, costo y enfriamiento.
##
## Igual que la tarjeta del objetivo, separa armar los datos de dibujarlos:
## _armar_slots() devuelve que hay que mostrar y se puede comprobar sin
## renderizar nada.
##
## Los nodos se rehacen solo cuando cambia el loadout. En cada frame cambian el
## enfriamiento y el mana, y recrear Labels sesenta veces por segundo seria un
## despilfarro de asignaciones.

const LADO_ICONO := 56.0
const ANCHO_SLOT := 78.0

var _componente: ComponenteHabilidades
var _healer: Node
var _fila: HBoxContainer
## Un diccionario de nodos por slot, en el mismo orden que las habilidades.
var _vistas: Array[Dictionary] = []


func _ready() -> void:
	# El nodo es el panel y no un Control con un panel adentro: un Control
	# pelado no le pasa al contenedor de arriba el tamano que ocupan sus hijos,
	# y la fila terminaba encimada con las barras.
	theme_type_variation = &"PanelAcciones"
	# El HUD entero deja pasar los clicks al campo: sin esto no se puede curar
	# haciendo click sobre un soldado que quede debajo de la fila.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_fila = HBoxContainer.new()
	_fila.add_theme_constant_override("separation", 6)
	_fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fila)


func seguir(healer: Node, componente: ComponenteHabilidades) -> void:
	_healer = healer
	_componente = componente
	_componente.loadout_cambio.connect(_reconstruir)
	_reconstruir()


func _process(_delta: float) -> void:
	if _componente == null:
		return
	var slots := _armar_slots()
	if slots.size() != _vistas.size():
		_reconstruir()
		return
	for i in slots.size():
		_refrescar(_vistas[i], slots[i])


## Que mostrar en cada slot. Sin nodos ni dibujo: solo los datos.
func _armar_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if _componente == null:
		return slots

	for habilidad: Habilidad in _componente.habilidades:
		if habilidad == null:
			continue
		var enfriando := _componente.fraccion_enfriamiento(habilidad)
		var sin_mana: bool = _healer != null and _healer.mana < habilidad.costo
		var pie := "%d mana" % habilidad.costo
		if enfriando > 0.0:
			pie = "%.1fs" % _componente.enfriamiento_restante(habilidad)
		elif sin_mana:
			pie = "sin mana"

		slots.append({
			"nombre": habilidad.nombre,
			"tecla": habilidad.tecla,
			"icono": habilidad.icono,
			"color": habilidad.color,
			"pie": pie,
			"enfriando": enfriando,
			"sin_mana": sin_mana,
			"disponible": enfriando <= 0.0 and not sin_mana,
		})
	return slots


func _reconstruir() -> void:
	for hijo in _fila.get_children():
		hijo.queue_free()
	_vistas.clear()

	for slot: Dictionary in _armar_slots():
		_vistas.append(_crear_slot(slot))


func _crear_slot(slot: Dictionary) -> Dictionary:
	var caja := PanelContainer.new()
	caja.custom_minimum_size = Vector2(ANCHO_SLOT, 0)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Un borde del color de la habilidad: es lo que la distingue de un vistazo,
	# antes de leer el nombre.
	var marco := StyleBoxFlat.new()
	marco.bg_color = Color(0, 0, 0, 0.5)
	marco.border_color = slot["color"]
	marco.set_border_width_all(2)
	marco.set_content_margin_all(4)
	caja.add_theme_stylebox_override("panel", marco)
	_fila.add_child(caja)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 2)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(columna)

	var tecla := Label.new()
	tecla.text = slot["tecla"]
	tecla.theme_type_variation = &"Chico"
	tecla.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(tecla)

	# El icono y el velo de enfriamiento comparten lugar: el velo se dibuja
	# encima y baja tapandolo a medida que corre el reloj.
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(LADO_ICONO, LADO_ICONO)
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(hueco)

	var icono := TextureRect.new()
	icono.texture = slot["icono"]
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.set_anchors_preset(Control.PRESET_FULL_RECT)
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hueco.add_child(icono)

	# Sin icono (assets sin extraer) queda el nombre, que alcanza para jugar.
	var nombre := Label.new()
	nombre.text = "" if slot["icono"] != null else slot["nombre"]
	nombre.theme_type_variation = &"Chico"
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nombre.set_anchors_preset(Control.PRESET_FULL_RECT)
	hueco.add_child(nombre)

	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.62)
	velo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hueco.add_child(velo)

	var pie := Label.new()
	pie.text = slot["pie"]
	pie.theme_type_variation = &"Chico"
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(pie)

	var vista := {
		"caja": caja, "marco": marco, "icono": icono,
		"velo": velo, "pie": pie, "hueco": hueco,
	}
	_refrescar(vista, slot)
	return vista


func _refrescar(vista: Dictionary, slot: Dictionary) -> void:
	var pie: Label = vista["pie"]
	pie.text = slot["pie"]

	var disponible: bool = slot["disponible"]
	var icono: TextureRect = vista["icono"]
	# Apagado cuando no se puede usar: el gris dice "ahora no" sin leer nada.
	icono.modulate = Color.WHITE if disponible else Color(0.55, 0.58, 0.66)
	var marco: StyleBoxFlat = vista["marco"]
	marco.border_color = slot["color"] if disponible else Color(0.35, 0.37, 0.45)

	var velo: ColorRect = vista["velo"]
	var hueco: Control = vista["hueco"]
	var fraccion: float = slot["enfriando"]
	velo.visible = fraccion > 0.0
	# offset_bottom y no size: con los anchors pegados arriba, el tamano lo
	# recalcula el motor y pisaria lo que se le asigne a mano.
	velo.offset_bottom = hueco.size.y * fraccion
