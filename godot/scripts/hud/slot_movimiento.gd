class_name SlotMovimiento
extends Control
## El icono del movimiento que saldria con un boton, en un marco chico.
##
## Sigue a los slots de habilidades de antes: el marco del color del
## movimiento cuando esta listo y gris cuando no, y un velo oscuro que baja de
## arriba hacia abajo mientras se enfria. Sin mana el icono se apaga y el
## marco toma el color del mana, que es lo que falta.
##
## Se dibuja a mano y no con nodos: el velo cambia en cada frame y un marco de
## dos pixeles con un icono adentro no justifica tres nodos mas.

## Los iconos son de 64 px pero dibujados al doble: a 32 se ven con sus
## pixeles de origen, sin reescalar nada.
const LADO_ICONO := 32
const BORDE := 1
const COLOR_FONDO := Color(0, 0, 0, 0.55)
const COLOR_APAGADO := Color(0.35, 0.37, 0.45)
const COLOR_MANA := Color("4a9fd4")
const VELO := Color(0, 0, 0, 0.62)
## El filo del velo, para que se vea que baja aunque el icono sea oscuro.
const FILO := Color(1, 1, 1, 0.55)
const ALFA_NO_LISTO := 0.4

var _icono: Texture2D
var _color: Color = COLOR_APAGADO
var _inicial: String = ""
var _enfriamiento: float = 0.0
var _sin_mana: bool = false
var _vacio: bool = true


func _ready() -> void:
	custom_minimum_size = Vector2(LADO_ICONO + 2 * BORDE, LADO_ICONO + 2 * BORDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Muestra un renglon de TarjetaObjetivo. Solo repinta si algo cambio: el HUD
## lo llama en cada frame.
func mostrar(renglon: Dictionary) -> void:
	var nombre: String = renglon.get("movimiento", "")
	var icono: Texture2D = renglon.get("icono") as Texture2D
	var color: Color = renglon.get("color", COLOR_APAGADO)
	var enfriamiento: float = renglon.get("enfriamiento", 0.0)
	var sin_mana: bool = renglon.get("sin_mana", false)
	var vacio := nombre == ""
	if icono == _icono and color == _color and is_equal_approx(enfriamiento, _enfriamiento) \
			and sin_mana == _sin_mana and vacio == _vacio:
		return
	_icono = icono
	_color = color
	_inicial = nombre.substr(0, 1).to_upper()
	_enfriamiento = enfriamiento
	_sin_mana = sin_mana
	_vacio = vacio
	queue_redraw()


func icono() -> Texture2D:
	return _icono


func enfriando() -> bool:
	return _enfriamiento > 0.0


func fraccion_enfriamiento() -> float:
	return _enfriamiento


func sin_mana() -> bool:
	return _sin_mana


func listo() -> bool:
	return not _vacio and _enfriamiento <= 0.0 and not _sin_mana


func _draw() -> void:
	var caja := Rect2(Vector2.ZERO, custom_minimum_size)
	var adentro := Rect2(Vector2(BORDE, BORDE), Vector2(LADO_ICONO, LADO_ICONO))
	draw_rect(caja, COLOR_FONDO)
	if not _vacio:
		var tinte := Color(1, 1, 1, 1.0 if listo() else ALFA_NO_LISTO)
		if _icono != null:
			draw_texture_rect(_icono, adentro, false, tinte)
		else:
			# Sin icono, la inicial del movimiento: sigue diciendo cual es.
			var fuente := get_theme_default_font()
			var tamano := 22
			var ancho := fuente.get_string_size(_inicial, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
			draw_string(fuente, Vector2(adentro.get_center().x - ancho * 0.5,
				adentro.position.y + tamano), _inicial, HORIZONTAL_ALIGNMENT_LEFT, -1,
				tamano, _color * tinte)
		if _enfriamiento > 0.0:
			var alto := roundf(LADO_ICONO * _enfriamiento)
			draw_rect(Rect2(adentro.position, Vector2(LADO_ICONO, alto)), VELO)
			draw_rect(Rect2(adentro.position + Vector2(0, alto), Vector2(LADO_ICONO, 1)), FILO)
	var borde := COLOR_APAGADO
	if _sin_mana:
		borde = COLOR_MANA
	elif listo():
		borde = _color
	_marco(caja, borde if not _vacio else Color(COLOR_APAGADO, 0.5))


## Cuatro rectangulos llenos y no draw_rect sin relleno: con ancho, ese traza
## la linea centrada en el borde y el marco sale corrido medio pixel.
func _marco(caja: Rect2, color: Color) -> void:
	draw_rect(Rect2(caja.position, Vector2(caja.size.x, BORDE)), color)
	draw_rect(Rect2(caja.position + Vector2(0, caja.size.y - BORDE), Vector2(caja.size.x, BORDE)), color)
	draw_rect(Rect2(caja.position, Vector2(BORDE, caja.size.y)), color)
	draw_rect(Rect2(caja.position + Vector2(caja.size.x - BORDE, 0), Vector2(BORDE, caja.size.y)), color)
