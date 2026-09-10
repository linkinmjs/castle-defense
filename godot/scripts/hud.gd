extends CanvasLayer
## HUD del prototipo: lo minimo para poder jugar y para leer como va la batalla.

const COLOR_MANA := Color("4a9fd4")
const DURACION_AVISO := 1.8

@onready var _barra_mana: ProgressBar = %BarraMana
@onready var _texto_mana: Label = %TextoMana
@onready var _contadores: Label = %Contadores
@onready var _aviso: Label = %Aviso
@onready var _slots: Control = %Slots

var _tiempo_aviso: float = 0.0


func _ready() -> void:
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = COLOR_MANA
	relleno.corner_radius_top_left = 2
	relleno.corner_radius_top_right = 2
	relleno.corner_radius_bottom_left = 2
	relleno.corner_radius_bottom_right = 2
	_barra_mana.add_theme_stylebox_override("fill", relleno)

	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0, 0, 0, 0.55)
	_barra_mana.add_theme_stylebox_override("background", fondo)

	_aviso.modulate.a = 0.0


## La batalla llama a esto cuando el healer ya esta en el arbol.
func seguir(healer: Healer) -> void:
	healer.mana_cambio.connect(_on_mana_cambio)
	healer.aviso.connect(_on_aviso)
	_on_mana_cambio(healer.mana, healer.mana_maximo)

	var habilidades: ComponenteHabilidades = healer.get_node("Habilidades")
	habilidades.habilidad_usada.connect(_on_habilidad_usada)
	habilidades.habilidad_fallo.connect(_on_habilidad_fallo)
	_slots.seguir(healer, habilidades)


func _process(delta: float) -> void:
	_contadores.text = "Aliados %d      Enemigos %d" % [
		_vivos("aliados"), _vivos("enemigos")
	]

	if _tiempo_aviso > 0.0:
		_tiempo_aviso -= delta
		_aviso.modulate.a = clampf(_tiempo_aviso / DURACION_AVISO, 0.0, 1.0)


func _on_mana_cambio(actual: float, maximo: float) -> void:
	_barra_mana.max_value = maximo
	_barra_mana.value = actual
	_texto_mana.text = "%d / %d" % [actual, maximo]


func _on_habilidad_usada(_habilidad: Habilidad, texto: String) -> void:
	if texto != "":
		_on_aviso(texto)


func _on_habilidad_fallo(_habilidad: Habilidad, motivo: String) -> void:
	_on_aviso(motivo)


func _on_aviso(texto: String) -> void:
	_aviso.text = texto
	_tiempo_aviso = DURACION_AVISO
	_aviso.modulate.a = 1.0


func _vivos(grupo: String) -> int:
	var total := 0
	for unidad in get_tree().get_nodes_in_group(grupo):
		if unidad.esta_viva():
			total += 1
	return total
