extends PanelContainer
## Ficha del soldado al que apunta el mouse.
##
## El campo muestra un solo problema por unidad para que se pueda leer de un
## vistazo con quince soldados amontonados; el detalle completo va aca. Dice
## que haria cada herramienta sobre ese paciente, pero nunca cual conviene:
## elegir es el juego.
##
## _armar_lineas() dice que mostrar y los nodos lo reflejan. Los Labels se
## rehacen solo cuando cambia la cantidad de renglones: recrearlos en cada
## frame, como se redibujaba antes, seria tirar asignaciones al pedo.

const ANCHO := 280.0

const COLOR_NOMBRE := Color(0.94, 0.95, 1.0)
const COLOR_TENUE := Color(0.70, 0.74, 0.85)
const COLOR_LEJOS := Color(1.0, 0.55, 0.42)

## Un color por familia de problema, el mismo que usa el overlay del campo.
const COLORES := {
	&"derribada": Color(0.95, 0.62, 0.2),
	&"sangrado": Color("c0392b"),
	&"vida_baja": Color("d9c04a"),
	&"retirada": Color(0.75, 0.78, 0.9),
	&"bendicion": Color("6fd3c7"),
}

const ETIQUETAS := {
	&"derribada": "Derribado",
	&"sangrado": "Sangrado",
	&"vida_baja": "Malherido",
	&"retirada": "Retirandose",
	&"bendicion": "Bendecido",
}

var _healer: Node
var _componente: ComponenteHabilidades
var _apuntada: Unidad3D
var _columna: VBoxContainer
var _renglones: Array[Label] = []


func seguir(healer: Node, componente: ComponenteHabilidades) -> void:
	_healer = healer
	_componente = componente
	healer.apuntada_cambio.connect(_on_apuntada_cambio)


func _on_apuntada_cambio(unidad: Unidad3D) -> void:
	_apuntada = unidad


func _ready() -> void:
	theme_type_variation = &"PanelFicha"
	custom_minimum_size = Vector2(ANCHO, 0)
	# Todo el HUD deja pasar los clicks: la tarjeta va abajo a la derecha y
	# taparia a los soldados que queden debajo.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_columna = VBoxContainer.new()
	_columna.add_theme_constant_override("separation", 3)
	_columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_columna)


func _process(_delta: float) -> void:
	# La vida y los relojes cambian solos aunque el mouse no se mueva.
	if _healer != null:
		_apuntada = _healer.unidad_apuntada()

	if _apuntada == null or not is_instance_valid(_apuntada):
		visible = false
		return

	visible = true
	var lineas := _armar_lineas()
	if lineas.size() != _renglones.size():
		_rehacer(lineas)
	else:
		_refrescar(lineas)


## Un Label por renglon. Solo cuando cambia la cantidad: mientras el paciente
## siga teniendo los mismos datos, alcanza con reescribir el texto.
func _rehacer(lineas: Array[Dictionary]) -> void:
	for hijo in _columna.get_children():
		hijo.queue_free()
	_renglones.clear()

	for linea: Dictionary in lineas:
		var etiqueta := Label.new()
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_columna.add_child(etiqueta)
		_renglones.append(etiqueta)
	_refrescar(lineas)


func _refrescar(lineas: Array[Dictionary]) -> void:
	for i in lineas.size():
		var linea: Dictionary = lineas[i]
		var etiqueta := _renglones[i]
		etiqueta.text = linea["texto"]
		etiqueta.add_theme_color_override("font_color", linea["color"])
		etiqueta.add_theme_font_size_override("font_size", linea.get("tamano", 13))



## Cuatro bloques: quien es, como esta, cual es su problema, y que puede hacer
## el jugador al respecto.
func _armar_lineas() -> Array[Dictionary]:
	var lineas: Array[Dictionary] = []

	var titulo: String = _apuntada.nombre_unidad
	var rol: String = _apuntada.tipo.nombre if _apuntada.tipo != null else ""
	if titulo != "" and rol != "":
		titulo = "%s · %s" % [titulo, rol]
	elif titulo == "":
		titulo = rol if rol != "" else "Soldado"
	lineas.append({"texto": titulo, "color": COLOR_NOMBRE, "tamano": 15})

	lineas.append({
		"texto": "%d / %d HP" % [ceilf(_apuntada.vida), _apuntada.vida_maxima],
		"color": COLOR_TENUE,
	})

	var estado: StringName = _apuntada.estado_dominante()
	if ETIQUETAS.has(estado):
		var texto: String = ETIQUETAS[estado]
		var segundos: float = _apuntada.segundos_estado()
		if segundos > 0.0:
			texto += " · %.1f s" % segundos
		lineas.append({"texto": texto, "color": COLORES.get(estado, COLOR_TENUE)})

	# Fuera de alcance no se oculta lo que haria: saber que vale la pena llegar
	# es parte de la decision.
	if not _healer.en_rango(_apuntada):
		lineas.append({"texto": "Fuera de alcance", "color": COLOR_LEJOS})

	# Solo las habilidades equipadas en este encuentro: el primero tiene una
	# sola, y la ficha tiene que verse igual de simple que el encuentro.
	if _componente != null:
		for habilidad: Habilidad in _componente.habilidades:
			if habilidad == null:
				continue
			var texto := habilidad.previsualizar(_healer, _apuntada)
			if texto != "":
				lineas.append({"texto": texto, "color": habilidad.color, "tamano": 12})

	return lineas
