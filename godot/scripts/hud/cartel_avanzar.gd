class_name CartelAvanzar
extends HBoxContainer
## "¡AVANZAR →!": el cartel de los beat-em-up que dice que el tramo quedo
## limpio y que hay que seguir. Aparece cuando la batalla libera un sector y
## se va cuando arranca el siguiente o termina la batalla.
##
## La flecha se dibuja a mano: la fuente de pixeles no trae el signo, y uno
## prestado de la fuente del sistema saldria suavizado al lado de letras
## duras. Titila (opacidad 1 y 0.4, cada 0.4 s) y la flecha empuja hacia la
## derecha, que es para donde hay que ir.

const PERIODO := 0.4
const ALFA_BAJO := 0.4
## Cuanto se corre la flecha en cada latido.
const EMPUJE_FLECHA := 8.0
## Entra desde la derecha: tan rapido que no demora el primer latido.
const ENTRADA := 0.25
const DISTANCIA_ENTRADA := 160.0
const TEXTO := "¡AVANZAR →!"

var _tween: Tween

@onready var _flecha: Control = $Flecha


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Engancha las senales de la batalla que tenga: la de hoy no libera sectores,
## y entonces el cartel no sale nunca.
func seguir(battle: Node) -> void:
	if battle.has_signal(&"sector_liberado"):
		battle.connect(&"sector_liberado", _on_sector_liberado)
	if battle.has_signal(&"sector_iniciado"):
		battle.connect(&"sector_iniciado", _on_sector_iniciado)
	if battle.has_signal(&"batalla_terminada"):
		battle.connect(&"batalla_terminada", _on_batalla_terminada)
	if battle.has_signal(&"encuentro_iniciado"):
		battle.connect(&"encuentro_iniciado", _on_encuentro_iniciado)


func mostrar() -> void:
	_cortar()
	visible = true
	modulate.a = 1.0
	offset_transform_position = Vector2(DISTANCIA_ENTRADA, 0.0)
	_flecha.offset_transform_position = Vector2.ZERO
	_tween = create_tween()
	_tween.tween_property(self, "offset_transform_position", Vector2.ZERO, ENTRADA) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_titilar)


func ocultar() -> void:
	_cortar()
	visible = false
	offset_transform_position = Vector2.ZERO


func texto() -> String:
	return TEXTO


## El latido, en un tween propio que se repite solo: opacidad y flecha a la
## vez, bajando y volviendo.
func _titilar() -> void:
	_cortar()
	_tween = create_tween().set_loops()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", ALFA_BAJO, PERIODO)
	_tween.tween_property(_flecha, "offset_transform_position", Vector2(EMPUJE_FLECHA, 0.0), PERIODO) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_property(self, "modulate:a", 1.0, PERIODO)
	_tween.parallel().tween_property(_flecha, "offset_transform_position", Vector2.ZERO, PERIODO) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _cortar() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _on_sector_liberado(_indice: int) -> void:
	mostrar()


func _on_sector_iniciado(_indice: int, _sector: Variant) -> void:
	ocultar()


func _on_batalla_terminada(_victoria: bool) -> void:
	ocultar()


func _on_encuentro_iniciado(_encuentro: Object, _semilla: int, _indice: int) -> void:
	ocultar()
