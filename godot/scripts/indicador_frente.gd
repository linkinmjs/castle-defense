extends Control
## Tira y afloja del frente: donde esta el choque entre las dos bases. Es la
## lectura mas rapida de si se esta ganando o perdiendo terreno.

const COLOR_ALIADO := Color("4a7fd4")
const COLOR_ENEMIGO := Color("c4553f")

var _battle: Node


func seguir(battle: Node) -> void:
	_battle = battle


func _process(_delta: float) -> void:
	if _battle != null:
		queue_redraw()


func _draw() -> void:
	if _battle == null:
		return

	var ancho := size.x
	var y := size.y * 0.5
	draw_line(Vector2(0, y), Vector2(ancho, y), Color(1, 1, 1, 0.25), 3.0)
	# Las bases en los extremos, con el color de cada bando.
	draw_rect(Rect2(0, y - 8, 6, 16), COLOR_ALIADO)
	draw_rect(Rect2(ancho - 6, y - 8, 6, 16), COLOR_ENEMIGO)

	var base_a: float = _battle.base_aliada_x
	var base_e: float = _battle.base_enemiga_x
	var frente: float = _battle.frente_x()
	var t := clampf((frente - base_a) / maxf(base_e - base_a, 0.001), 0.0, 1.0)
	var x := lerpf(6.0, ancho - 6.0, t)

	# Relleno hasta el frente: cuanto terreno es nuestro.
	draw_rect(Rect2(6, y - 2, x - 6, 4), Color(0.4, 0.6, 1.0, 0.55))
	draw_circle(Vector2(x, y), 6.0, Color(1, 1, 1, 0.95))
	draw_circle(Vector2(x, y), 6.0, Color(0, 0, 0, 0.8), false, 1.5)
