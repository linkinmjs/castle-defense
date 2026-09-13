extends Control
## Que paso en el encuentro y por que.
##
## Es un informe corto, no una planilla, y no da una nota: una puntuacion
## unica terminaria enseñando que hay una sola forma correcta de jugar. La
## idea es que el jugador salga con una hipotesis para el proximo intento.
##
## No conoce la clase Telemetria: recibe un Dictionary, un texto y las metas.
## Asi la interfaz no ata al modelo, que tiene que poder correr sin ella.

const ANCHO := 520.0
const MARGEN := 22.0
const ALTO_LINEA := 22.0

const COLOR_FONDO := Color(0.05, 0.06, 0.09, 0.92)
const COLOR_TITULO := Color(0.95, 0.96, 1.0)
const COLOR_TENUE := Color(0.72, 0.76, 0.88)
const COLOR_CUMPLIDA := Color("9fd88f")
const COLOR_FALLIDA := Color("e07a6a")
const COLOR_OBSERVACION := Color(1.0, 0.92, 0.65)

var _titulo: String = ""
var _metricas: Array[String] = []
var _metas: Array[Dictionary] = []
var _observacion: String = ""
var _pie: String = ""


func mostrar(titulo: String, resumen: Dictionary, observacion: String,
		metas: Array[MetaEncuentro], pie: String) -> void:
	_titulo = titulo
	_observacion = observacion
	_pie = pie
	_metricas = _armar_metricas(resumen)

	_metas.clear()
	for meta in metas:
		if meta == null or meta.texto == "":
			continue
		_metas.append({"texto": meta.texto, "cumplida": meta.cumplida(resumen)})

	visible = true
	queue_redraw()


func ocultar() -> void:
	visible = false


## Seis lineas, no todo lo que se midio. El resto queda en la telemetria para
## cuando haga falta mirar en detalle.
func _armar_metricas(r: Dictionary) -> Array[String]:
	var lineas: Array[String] = []

	var emitida: float = r.get("curacion_emitida", 0.0)
	if emitida > 0.0:
		lineas.append("Curacion: %d util, %d desperdiciada (%d%%)" % [
			r.get("curacion_efectiva", 0.0),
			r.get("curacion_desperdiciada", 0.0),
			r.get("fraccion_desperdiciada", 0.0) * 100.0,
		])
	else:
		lineas.append("Curacion: no curaste a nadie")

	var sangrados: int = r.get("sangrados", 0)
	if sangrados > 0:
		lineas.append("Sangrados: %d cortados de %d, en %.1f s promedio" % [
			r.get("sangrados_estabilizados", 0), sangrados,
			r.get("tiempo_hasta_estabilizar", 0.0),
		])

	lineas.append("Caidos: %d, reanimados %d, muertos %d" % [
		r.get("caidas", 0), r.get("reanimaciones", 0), r.get("muertes", 0)])

	var causas: Dictionary = r.get("muertes_por_causa", {})
	if not causas.is_empty():
		var partes: Array[String] = []
		for causa: StringName in causas:
			partes.append("%d por %s" % [causas[causa], _nombrar_causa(causa)])
		lineas.append("Causas: %s" % ", ".join(partes))

	lineas.append("Mana: %d gastado, %d sin usar" % [
		r.get("mana_gastado", 0.0), r.get("mana_sin_usar", 0.0)])

	var al_tope: float = r.get("segundos_mana_al_tope", 0.0)
	var duracion: float = maxf(r.get("duracion", 0.0), 0.01)
	lineas.append("Duracion: %.0f s, %.0f s con el mana lleno (%d%%)" % [
		duracion, al_tope, al_tope / duracion * 100.0])

	return lineas


func _nombrar_causa(causa: StringName) -> String:
	match causa:
		&"sangrado":
			return "sangrado"
		&"sin_atencion":
			return "quedar sin atencion"
		&"golpe":
			return "golpes"
	return "causa desconocida"


func _draw() -> void:
	var fuente := get_theme_default_font()
	var cantidad := 2 + _metricas.size() + _metas.size() + (2 if _observacion != "" else 0)
	var alto := MARGEN * 2.0 + cantidad * ALTO_LINEA + 30.0
	custom_minimum_size = Vector2(ANCHO, alto)

	var caja := Rect2(0, 0, ANCHO, alto)
	draw_rect(caja, COLOR_FONDO)
	draw_rect(caja, Color(1, 1, 1, 0.16), false, 1.0)

	var y := MARGEN + 16.0
	draw_string(fuente, Vector2(MARGEN, y), _titulo,
		HORIZONTAL_ALIGNMENT_LEFT, ANCHO - MARGEN * 2.0, 22, COLOR_TITULO)
	y += ALTO_LINEA + 10.0

	for linea in _metricas:
		draw_string(fuente, Vector2(MARGEN, y), linea,
			HORIZONTAL_ALIGNMENT_LEFT, ANCHO - MARGEN * 2.0, 14, COLOR_TENUE)
		y += ALTO_LINEA

	for meta: Dictionary in _metas:
		var marca := "OK  " if meta["cumplida"] else "--  "
		draw_string(fuente, Vector2(MARGEN, y), marca + meta["texto"],
			HORIZONTAL_ALIGNMENT_LEFT, ANCHO - MARGEN * 2.0, 14,
			COLOR_CUMPLIDA if meta["cumplida"] else COLOR_FALLIDA)
		y += ALTO_LINEA

	# La observacion es lo unico que puede cambiar el proximo intento: va
	# separada y con su propio color para que no se lea como una metrica mas.
	if _observacion != "":
		y += ALTO_LINEA * 0.5
		draw_string(fuente, Vector2(MARGEN, y), _observacion,
			HORIZONTAL_ALIGNMENT_LEFT, ANCHO - MARGEN * 2.0, 15, COLOR_OBSERVACION)
		y += ALTO_LINEA * 1.5

	draw_string(fuente, Vector2(MARGEN, y), _pie,
		HORIZONTAL_ALIGNMENT_LEFT, ANCHO - MARGEN * 2.0, 13, COLOR_TENUE)
