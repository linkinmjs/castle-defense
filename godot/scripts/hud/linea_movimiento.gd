class_name LineaMovimiento
extends HBoxContainer
## Un renglon de la tarjeta de la ficha: el icono de lo que saldria con un
## boton, la tecla de ese boton y lo que haria.
##
## Los nodos los arma tools/gen_hud.gd (Slot, Tecla/Letra y Texto); esto los
## llena con un renglon de TarjetaObjetivo. Solo toca lo que cambio: el HUD
## lo llama en cada frame, y cada override de color hace rearmar el texto.

const ALFA_APAGADO := 0.45
## Un movimiento que no esta listo se sigue leyendo, pero mas bajo: lo que
## importa en ese momento es el velo del icono.
const ALFA_NO_LISTO := 0.7

var _renglon: Dictionary = {}

@onready var _slot: SlotMovimiento = $Slot
@onready var _tecla: Label = $Tecla/Letra
@onready var _texto: Label = $Texto


func mostrar(renglon: Dictionary) -> void:
	_slot.mostrar(renglon)
	var boton: String = renglon.get("boton", "")
	if boton != _tecla.text:
		_tecla.text = boton

	var texto: String = renglon.get("texto", "")
	var color: Variant = renglon.get("color")
	var alfa := 1.0
	if renglon.get("apagado", false):
		alfa = ALFA_APAGADO
	elif renglon.get("sin_mana", false) or renglon.get("enfriamiento", 0.0) > 0.0:
		alfa = ALFA_NO_LISTO
	if texto != _renglon.get("texto", ""):
		_texto.text = texto
	if color != _renglon.get("color"):
		if color is Color:
			_texto.add_theme_color_override("font_color", color)
		else:
			_texto.remove_theme_color_override("font_color")
	_texto.modulate.a = alfa
	_renglon = renglon


## Lo que muestra el renglon, para las pruebas: la tecla y el movimiento, si
## el icono esta, si se esta enfriando (y cuanto le falta) y si falta mana.
func estado() -> Dictionary:
	return {
		"boton": _tecla.text,
		"movimiento": _renglon.get("movimiento", ""),
		"icono": _slot.icono(),
		"enfriando": _slot.enfriando(),
		"fraccion_enfriamiento": _slot.fraccion_enfriamiento(),
		"sin_mana": _slot.sin_mana(),
		"listo": _slot.listo(),
		"texto": _texto.text,
	}


func texto() -> String:
	return _texto.text
