extends PanelContainer
## Que paso en el encuentro y por que.
##
## Es un informe corto, no una planilla, y no da una nota: una puntuacion
## unica terminaria enseñando que hay una sola forma correcta de jugar. La
## idea es que el jugador salga con una hipotesis para el proximo intento.
##
## No conoce la clase Telemetria: recibe un Dictionary, un texto y las metas.
## Asi la interfaz no ata al modelo, que tiene que poder correr sin ella.
##
## contenido() arma los renglones como datos y los nodos los reflejan; el alto
## lo resuelve el container, que antes habia que calcular a mano contando
## caracteres para estimar cuantos renglones iba a ocupar la observacion.

const ANCHO := 560.0

## Los demas colores vienen del tema. Este no: la observacion tiene que
## despegarse del resto sin dejar de leerse sobre el panel claro.
const COLOR_OBSERVACION := Color(0.45, 0.16, 0.08)

var _titulo: String = ""
var _metricas: Array[String] = []
var _metas: Array[Dictionary] = []
var _observacion: String = ""
var _pie: String = ""
var _columna: VBoxContainer


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
	_volcar()


func ocultar() -> void:
	visible = false


## Unas pocas lineas, no todo lo que se midio. El resto queda en la
## telemetria para cuando haga falta mirar en detalle.
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

	# Solo si encadeno algo: "Combo maximo: 1" diria lo mismo que no decir
	# nada, y ocuparia un renglon.
	var combo: int = r.get("combo_maximo", 0)
	if combo > 1:
		lineas.append("Combo maximo: %d" % combo)

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


## Los renglones del informe, en orden, como datos. Cada uno dice de que tipo
## es para que la vista sepa con que estilo mostrarlo.
func contenido() -> Array[Dictionary]:
	var filas: Array[Dictionary] = [{"texto": _titulo, "clase": "titulo"}]

	for linea in _metricas:
		filas.append({"texto": linea, "clase": "metrica"})

	for meta: Dictionary in _metas:
		filas.append({
			"texto": ("[ok] " if meta["cumplida"] else "[--] ") + meta["texto"],
			"clase": "meta_cumplida" if meta["cumplida"] else "meta_fallida",
		})

	# La observacion es lo unico que puede cambiar el proximo intento: va
	# aparte para que no se lea como una metrica mas.
	if _observacion != "":
		filas.append({"texto": _observacion, "clase": "observacion"})

	filas.append({"texto": _pie, "clase": "pie"})
	return filas


func _ready() -> void:
	theme_type_variation = &"PanelResumen"
	custom_minimum_size = Vector2(ANCHO, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_columna = VBoxContainer.new()
	_columna.add_theme_constant_override("separation", 6)
	_columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_columna)


func _volcar() -> void:
	if _columna == null:
		return
	for hijo in _columna.get_children():
		hijo.queue_free()

	for fila: Dictionary in contenido():
		var etiqueta := Label.new()
		etiqueta.text = fila["texto"]
		etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Una frase larga sigue en el renglon siguiente en vez de cortarse: el
		# container ajusta el alto solo.
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.theme_type_variation = _variacion(fila["clase"])
		if fila["clase"] == "observacion":
			etiqueta.add_theme_color_override("font_color", COLOR_OBSERVACION)
		_columna.add_child(etiqueta)


## El panel es de madera clara: el texto va oscuro, salvo las metas y la
## observacion, que tienen su propio color.
func _variacion(clase: String) -> StringName:
	match clase:
		"titulo":
			return &"TituloPanel"
		"meta_cumplida":
			return &"Exito"
		"meta_fallida":
			return &"Fallo"
		"observacion", "pie":
			return &"SobrePanel"
	return &"SobrePanel"
