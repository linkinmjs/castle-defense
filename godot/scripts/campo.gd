extends Node2D
## Terreno provisional del campo de batalla.
##
## Dibuja el suelo, marcas de distancia para percibir el desplazamiento y las
## dos bases. Se reemplazara por arte real mas adelante.

@export var ancho: float = 1800.0
@export var banda_alta: float = 40.0
@export var banda_baja: float = 280.0
@export var base_aliada_x: float = 100.0
@export var base_enemiga_x: float = 1700.0

const COLOR_CIELO := Color("161a27")
const COLOR_TIERRA := Color("2c3145")
const COLOR_BANDA := Color("353b52")
const COLOR_MARCA := Color(1, 1, 1, 0.05)
const COLOR_BASE_ALIADA := Color("4a7fd4")
const COLOR_BASE_ENEMIGA := Color("c4553f")


func _draw() -> void:
	# Cielo y tierra, generosos hacia afuera para cubrir toda la camara.
	draw_rect(Rect2(-200, -600, ancho + 400, 600 + banda_alta), COLOR_CIELO)
	draw_rect(Rect2(-200, banda_alta, ancho + 400, 600), COLOR_TIERRA)

	# La banda transitable, apenas mas clara que el resto del suelo.
	draw_rect(Rect2(0, banda_alta, ancho, banda_baja - banda_alta), COLOR_BANDA)

	# Marcas de distancia: sin ellas no se percibe el avance lateral.
	for x in range(0, int(ancho) + 1, 150):
		draw_line(Vector2(x, banda_alta), Vector2(x, banda_baja + 260), COLOR_MARCA, 2.0)

	_dibujar_base(base_aliada_x, COLOR_BASE_ALIADA)
	_dibujar_base(base_enemiga_x, COLOR_BASE_ENEMIGA)


func _dibujar_base(x: float, color: Color) -> void:
	var alto := 260.0
	var ancho_base := 90.0
	draw_rect(Rect2(x - ancho_base * 0.5, banda_baja - alto, ancho_base, alto), color)
	draw_rect(Rect2(x - ancho_base * 0.5, banda_baja - alto, ancho_base, alto), color.darkened(0.4), false, 3.0)
