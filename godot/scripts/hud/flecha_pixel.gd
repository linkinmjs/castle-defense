class_name FlechaPixel
extends Control
## Una flecha hacia la derecha dibujada con la grilla de la fuente de pixeles.
##
## Pixelify Sans no trae "→", y el que presta la fuente del sistema sale
## suavizado y de otro grosor al lado de las letras. Esta usa el mismo pixel
## que las letras de al lado (un onceavo del cuerpo: la fuente esta dibujada
## en una grilla de 11 por em) y el color y la sombra del tipo de Label que
## tiene al lado, asi que cambia si cambia el tema.

## La forma, fila por fila de arriba a abajo; '#' es un pixel lleno. Siete
## de alto, como las mayusculas de la fuente.
const FORMA: Array[String] = [
	"....#...",
	"....##..",
	"#######.",
	"########",
	"#######.",
	"....##..",
	"....#...",
]
## De que tipo de Label toma el color, la sombra y el cuerpo.
@export var tipo_tema: StringName = &"Cartel"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = _medida()


func _notification(que: int) -> void:
	if que == NOTIFICATION_THEME_CHANGED:
		custom_minimum_size = _medida()
		queue_redraw()


func _draw() -> void:
	var pixel := _pixel()
	var sombra := Vector2(
		get_theme_constant(&"shadow_offset_x", tipo_tema),
		get_theme_constant(&"shadow_offset_y", tipo_tema))
	var arriba := roundf((size.y - FORMA.size() * pixel - sombra.y) * 0.5)
	var origen := Vector2(0.0, arriba)
	if sombra != Vector2.ZERO:
		_forma(origen + sombra, pixel, get_theme_color(&"font_shadow_color", tipo_tema))
	_forma(origen, pixel, get_theme_color(&"font_color", tipo_tema))


func _forma(origen: Vector2, pixel: float, color: Color) -> void:
	for fila in FORMA.size():
		var renglon := FORMA[fila]
		for columna in renglon.length():
			if renglon[columna] == "#":
				draw_rect(Rect2(origen + Vector2(columna, fila) * pixel, Vector2(pixel, pixel)), color)


## Un pixel de la fuente a ese cuerpo: 44 -> 4.
func _pixel() -> float:
	return maxf(roundf(get_theme_font_size(&"font_size", tipo_tema) / 11.0), 1.0)


func _medida() -> Vector2:
	var pixel := _pixel()
	var sombra := Vector2(
		get_theme_constant(&"shadow_offset_x", tipo_tema),
		get_theme_constant(&"shadow_offset_y", tipo_tema))
	return Vector2(FORMA[0].length() * pixel, FORMA.size() * pixel) + sombra
