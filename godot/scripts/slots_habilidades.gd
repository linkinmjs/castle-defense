extends Control
## Fila de habilidades del HUD: tecla, nombre, costo y enfriamiento.
##
## Se dibuja a mano en vez de armar nodos por slot porque el contenido cambia
## todos los frames y asi queda todo el layout en un solo lugar.

const ANCHO_SLOT := 104.0
const ALTO_SLOT := 62.0
const SEPARACION := 8.0

var _componente: ComponenteHabilidades
var _healer: Node


func seguir(healer: Node, componente: ComponenteHabilidades) -> void:
	_healer = healer
	_componente = componente
	custom_minimum_size = Vector2(
		_componente.habilidades.size() * (ANCHO_SLOT + SEPARACION), ALTO_SLOT)
	queue_redraw()


func _process(_delta: float) -> void:
	# El enfriamiento baja de forma continua, hay que repintar seguido.
	if _componente != null:
		queue_redraw()


func _draw() -> void:
	if _componente == null:
		return

	var fuente := get_theme_default_font()
	var x := 0.0

	for habilidad: Habilidad in _componente.habilidades:
		var caja := Rect2(x, 0, ANCHO_SLOT, ALTO_SLOT)
		var enfriando := _componente.fraccion_enfriamiento(habilidad)
		# _healer es Node (sirve para el healer 2D y el 3D), asi que el tipo
		# de estas dos hay que declararlo a mano.
		var sin_mana: bool = _healer != null and _healer.mana < habilidad.costo
		var disponible: bool = enfriando <= 0.0 and not sin_mana

		draw_rect(caja, Color(0, 0, 0, 0.55))

		# El relleno baja de arriba a abajo mientras se enfria.
		if enfriando > 0.0:
			draw_rect(Rect2(x, 0, ANCHO_SLOT, ALTO_SLOT * enfriando), Color(0, 0, 0, 0.55))

		var borde := habilidad.color if disponible else Color(0.35, 0.37, 0.45)
		draw_rect(caja, borde, false, 2.0)

		var tinta := Color(1, 1, 1, 1) if disponible else Color(1, 1, 1, 0.45)
		# Tecla, nombre y costo en tres renglones: en uno solo, teclas como
		# "LMB" se comen el nombre de la habilidad.
		draw_string(fuente, Vector2(x + 8, 18), habilidad.tecla,
			HORIZONTAL_ALIGNMENT_LEFT, ANCHO_SLOT - 12, 12,
			Color(0.72, 0.78, 0.9) if disponible else Color(0.6, 0.62, 0.7))
		draw_string(fuente, Vector2(x + 8, 39), habilidad.nombre,
			HORIZONTAL_ALIGNMENT_LEFT, ANCHO_SLOT - 12, 15, tinta)

		var pie := "%d mana" % habilidad.costo
		if enfriando > 0.0:
			pie = "%.1fs" % _componente.enfriamiento_restante(habilidad)
		elif sin_mana:
			pie = "sin mana"
		var color_pie := Color(0.65, 0.72, 0.85) if disponible else Color(0.95, 0.55, 0.45)
		draw_string(fuente, Vector2(x + 8, 55), pie,
			HORIZONTAL_ALIGNMENT_LEFT, ANCHO_SLOT - 12, 12, color_pie)

		x += ANCHO_SLOT + SEPARACION
