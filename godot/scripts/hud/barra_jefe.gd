class_name BarraJefe
extends VBoxContainer
## La barra del jefe: abajo al centro, ancha y con su nombre, como en los
## beat-em-up. Dice de lejos cuanto le falta al que hay que voltear.
##
## Aparece cuando la batalla crea una unidad con es_jefe y se va cuando esa
## unidad muere. La vida no llega por senal (a una unidad no le avisa nadie
## cuando le pegan), asi que se lee en cada frame; la barra es la misma de las
## fichas, con fantasma.
##
## Todo se pregunta por nombre: es_jefe, vida y murio son de la unidad, y la
## batalla de hoy no tiene jefes.

const ENTRADA := 0.35
## Al morir, la barra se vacia (el fantasma cae hasta cero) y despues se va.
const ESPERA_SALIDA := 0.8
const SALIDA := 0.4
## Sube desde abajo al entrar.
const DISTANCIA_ENTRADA := 40.0
const NOMBRE_POR_DEFECTO := "Jefe"

var _jefe: Node
var _tween: Tween

@onready var _nombre: Label = $Nombre
@onready var _barra: BarraFantasma = $Barra


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func seguir(battle: Node) -> void:
	if battle.has_signal(&"unidad_creada"):
		battle.connect(&"unidad_creada", _on_unidad_creada)
	if battle.has_signal(&"encuentro_iniciado"):
		battle.connect(&"encuentro_iniciado", _on_encuentro_iniciado)


## Muestra la barra de esta unidad. Un jefe nuevo reemplaza al anterior.
func seguir_jefe(unidad: Node) -> void:
	if unidad == null:
		return
	_soltar()
	_jefe = unidad
	if unidad.has_signal(&"murio"):
		unidad.connect(&"murio", _on_murio)
	_nombre.text = nombre_de(unidad)
	_barra.fijar(_leer(unidad, &"vida"), _leer(unidad, &"vida_maxima"), true)

	_cortar()
	visible = true
	modulate.a = 0.0
	offset_transform_position = Vector2(0.0, DISTANCIA_ENTRADA)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "offset_transform_position", Vector2.ZERO, ENTRADA) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, ENTRADA)


## Si hay un jefe vivo en pantalla. Pasa a false en cuanto muere, aunque la
## barra tarde un momento en irse.
func mostrando_jefe() -> bool:
	return _jefe != null and is_instance_valid(_jefe)


func jefe() -> Node:
	return _jefe if mostrando_jefe() else null


func nombre() -> String:
	return _nombre.text


func vida_mostrada() -> float:
	return _barra.valor()


func fantasma() -> float:
	return _barra.fantasma()


## Su nombre propio si lo tiene; si no, el de su tipo ("Ogro"); si no,
## "Jefe".
static func nombre_de(unidad: Node) -> String:
	var propio: Variant = unidad.get(&"nombre_unidad")
	if propio is String and propio != "":
		return propio
	var tipo: Variant = unidad.get(&"tipo")
	if tipo is Object and is_instance_valid(tipo):
		var del_tipo: Variant = (tipo as Object).get(&"nombre")
		if del_tipo is String and del_tipo != "":
			return del_tipo
	return NOMBRE_POR_DEFECTO


func _process(_delta: float) -> void:
	if _jefe == null:
		return
	if not is_instance_valid(_jefe) or _jefe.is_queued_for_deletion():
		# Se fue sin morir: el encuentro se reinicio o lo sacaron del campo.
		_jefe = null
		_irse(0.0)
		return
	_barra.fijar(_leer(_jefe, &"vida"), _leer(_jefe, &"vida_maxima"))


func _on_unidad_creada(unidad: Node) -> void:
	if unidad != null and unidad.get(&"es_jefe") == true:
		seguir_jefe(unidad)


func _on_murio(_unidad: Variant = null) -> void:
	if _jefe == null:
		return
	var maximo := _leer(_jefe, &"vida_maxima")
	_soltar()
	_barra.fijar(0.0, maximo)
	_irse(ESPERA_SALIDA)


func _on_encuentro_iniciado(_encuentro: Object, _semilla: int, _indice: int) -> void:
	_soltar()
	_cortar()
	visible = false


## Se desvanece despues de `espera` segundos y queda oculta.
func _irse(espera: float) -> void:
	_cortar()
	_tween = create_tween()
	if espera > 0.0:
		_tween.tween_interval(espera)
	_tween.tween_property(self, "modulate:a", 0.0, SALIDA)
	_tween.tween_callback(func() -> void: visible = false)


func _soltar() -> void:
	if _jefe != null and is_instance_valid(_jefe) and _jefe.has_signal(&"murio") \
			and _jefe.is_connected(&"murio", _on_murio):
		_jefe.disconnect(&"murio", _on_murio)
	_jefe = null


func _cortar() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


static func _leer(unidad: Node, propiedad: StringName) -> float:
	var valor: Variant = unidad.get(propiedad)
	return float(valor) if valor != null else 0.0
