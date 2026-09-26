class_name OverlayUnidades
extends Control
## Barras de vida y marcas de estado del prototipo 3D.
##
## En 3D no existe _draw() por nodo, asi que en vez de colgar un cartel de cada
## soldado se proyecta su posicion a pantalla y se dibuja todo aca, en 2D. Sale
## nitido, siempre encara al jugador y no pelea con el z-buffer.

const COLOR_SANGRADO := Color("c0392b")
const COLOR_BENDICION := Color("6fd3c7")
## El color de cada jugador: el de la marca a los pies del que tiene al frente
## y el del titulo de su ficha en el HUD. Con dos healers, es lo que dice cual
## de las dos elipses es la de cada uno.
const COLORES_JUGADOR: Dictionary[int, Color] = {
	1: Color("e8b84a"),  # dorado
	2: Color("5fd3c7"),  # turquesa
}
## Distancia a la que la barra se ve a tamano natural.
const DISTANCIA_BASE := 11.0

var _camara: Camera3D


## Blanco para una marca sin dueno (0) o un jugador que no existe.
static func color_jugador(jugador: int) -> Color:
	return COLORES_JUGADOR.get(jugador, Color.WHITE)


func seguir(camara: Camera3D) -> void:
	_camara = camara


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _camara == null:
		return

	for grupo in ["aliados", "enemigos"]:
		for unidad in get_tree().get_nodes_in_group(grupo):
			if not unidad.esta_viva() or unidad.is_queued_for_deletion():
				continue
			_dibujar_unidad(unidad)


func _dibujar_unidad(unidad: Node3D) -> void:
	# Cada tipo dice a que altura va su barra: el oso es mas bajo y el jefe mucho
	# mas alto que un soldado de 2 m.
	var cabeza: Vector3 = unidad.punto_cabeza()
	if _camara.is_position_behind(cabeza):
		return

	var en_pantalla := _camara.unproject_position(cabeza)
	var distancia := _camara.global_position.distance_to(unidad.global_position)
	# Escala suave con la distancia: si todas midieran igual, las del fondo se
	# verian enormes y romperian la profundidad.
	var escala := clampf(DISTANCIA_BASE / maxf(distancia, 0.1), 0.55, 1.35)

	if unidad.resaltada:
		_dibujar_resaltado(unidad, escala)

	if unidad.esta_derribada():
		_dibujar_derribada(unidad, escala)
		return

	var ancho := 44.0 * escala
	var alto := 6.0 * escala
	var origen := en_pantalla - Vector2(ancho * 0.5, 0.0)
	var marco := Rect2(origen, Vector2(ancho, alto))

	draw_rect(marco, Color(0, 0, 0, 0.55))
	var proporcion: float = clampf(unidad.vida / unidad.vida_maxima, 0.0, 1.0)
	draw_rect(Rect2(origen, Vector2(ancho * proporcion, alto)), _color_vida(proporcion))
	draw_rect(marco, Color(0, 0, 0, 0.7), false, maxf(1.0, escala))

	if unidad.esta_sangrando():
		var centro := origen + Vector2(ancho + 6.0 * escala, alto * 0.5)
		var r := 4.0 * escala
		draw_colored_polygon(PackedVector2Array([
			centro + Vector2(0, -r), centro + Vector2(r * 0.8, 0),
			centro + Vector2(0, r), centro + Vector2(-r * 0.8, 0),
		]), COLOR_SANGRADO)

	if unidad.esta_bendecida():
		draw_arc(origen + Vector2(-6.0 * escala, alto * 0.5), 3.5 * escala,
			0.0, TAU, 12, COLOR_BENDICION, maxf(1.5, 2.0 * escala))


## Elipse a los pies del objetivo apuntado, del color del jugador que lo tiene
## al frente. Se proyectan veinte puntos del contorno en el mundo para que la
## marca siga la perspectiva del suelo.
##
## Ya no hay color de "fuera de alcance": con el apuntado por posicion, lo que
## esta marcado esta en la caja de la ligera.
func _dibujar_resaltado(unidad: Node3D, escala: float) -> void:
	var color := color_jugador(unidad.resaltada_por)
	color.a = 0.9

	var radio := 0.55
	var puntos := PackedVector2Array()
	for i in 20:
		var angulo := TAU * i / 20.0
		var mundo: Vector3 = unidad.global_position + Vector3(
			cos(angulo) * radio, 0.02, sin(angulo) * radio)
		if _camara.is_position_behind(mundo):
			return
		puntos.append(_camara.unproject_position(mundo))

	draw_colored_polygon(puntos, Color(color.r, color.g, color.b, 0.18))
	puntos.append(puntos[0])
	draw_polyline(puntos, color, maxf(1.5, 2.0 * escala))


## Una derribada no muestra vida sino el tiempo que le queda: la barra se
## vacia y, al llegar a cero, muere. Va mas abajo porque el cuerpo esta
## tirado, y late mas rapido cuanto menos queda.
func _dibujar_derribada(unidad: Node3D, escala: float) -> void:
	var punto: Vector3 = unidad.global_position + Vector3(0, 0.9, 0)
	if _camara.is_position_behind(punto):
		return
	var en_pantalla := _camara.unproject_position(punto)
	var ancho := 44.0 * escala
	var alto := 6.0 * escala
	var origen := en_pantalla - Vector2(ancho * 0.5, 0.0)
	var marco := Rect2(origen, Vector2(ancho, alto))
	var fraccion: float = unidad.fraccion_derribada()
	var segundos := Time.get_ticks_msec() / 1000.0
	var pulso := 0.75 + 0.25 * sin(segundos * (4.0 + 10.0 * (1.0 - fraccion)))

	draw_rect(marco, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(origen, Vector2(ancho * fraccion, alto)), Color(0.95, 0.62, 0.2, pulso))
	draw_rect(marco, Color(1.0, 0.85, 0.5, 0.9), false, maxf(1.0, escala))


func _color_vida(proporcion: float) -> Color:
	if proporcion > 0.5:
		return Color("5fbf5f")
	if proporcion > 0.25:
		return Color("d9c04a")
	return Color("d2503c")
