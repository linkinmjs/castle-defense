class_name ResumenEncuentro
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
##
## Los numeros entran contando desde 0, como el marcador de un beat-em-up: el
## ojo va a lo que se mueve, y lo que se mueve es lo que se midio. Cada
## metrica se guarda como formato y valores para poder contarla; el texto
## final es siempre el mismo que sin animacion.

## Entre las dos fichas, sin pisarlas.
const ANCHO := 600.0
## Lo que tardan los numeros en llegar a su valor.
const CUENTA := 0.8

## Los demas colores vienen del tema. Este no: la observacion tiene que
## despegarse del resto sin dejar de leerse sobre el panel claro.
const COLOR_OBSERVACION := Color(0.45, 0.16, 0.08)

var _titulo: String = ""
## Cada metrica: {formato, valores}. El texto es formato % valores.
var _metricas: Array[Dictionary] = []
var _metas: Array[Dictionary] = []
var _observacion: String = ""
var _pie: String = ""
var _columna: VBoxContainer
## Las etiquetas de las metricas, en el orden de _metricas, para contarlas.
var _etiquetas_metricas: Array[Label] = []
var _tween: Tween
## Por donde va la cuenta de los numeros, 0 a 1.
var _avance: float = 1.0


func mostrar(titulo: String, resumen: Dictionary, observacion: String,
		metas: Array[MetaEncuentro], pie: String) -> void:
	_titulo = titulo
	_observacion = observacion
	_pie = pie
	_metricas = _metricas_contables(resumen)

	_metas.clear()
	for meta in metas:
		if meta == null or meta.texto == "":
			continue
		_metas.append({"texto": meta.texto, "cumplida": meta.cumplida(resumen)})

	visible = true
	_volcar()


func ocultar() -> void:
	_cortar()
	visible = false


## Los numeros a mitad de la cuenta; 1 cuando llegaron.
func avance_cuenta() -> float:
	return 1.0 if _tween == null or not _tween.is_valid() else _avance


## Unas pocas lineas, no todo lo que se midio. El resto queda en la
## telemetria para cuando haga falta mirar en detalle.
func _armar_metricas(r: Dictionary) -> Array[String]:
	var lineas: Array[String] = []
	for metrica in _metricas_contables(r):
		lineas.append(_texto_metrica(metrica, 1.0))
	return lineas


## Las mismas metricas, como formato y valores.
func _metricas_contables(r: Dictionary) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []

	var emitida: float = r.get("curacion_emitida", 0.0)
	if emitida > 0.0:
		lista.append(_metrica("Curacion: %d util, %d desperdiciada (%d%%)", [
			r.get("curacion_efectiva", 0.0),
			r.get("curacion_desperdiciada", 0.0),
			r.get("fraccion_desperdiciada", 0.0) * 100.0,
		]))
	else:
		lista.append(_metrica("Curacion: no curaste a nadie", []))

	var sangrados: int = r.get("sangrados", 0)
	if sangrados > 0:
		lista.append(_metrica("Sangrados: %d cortados de %d, en %.1f s promedio", [
			r.get("sangrados_estabilizados", 0), sangrados,
			r.get("tiempo_hasta_estabilizar", 0.0),
		]))

	lista.append(_metrica("Caidos: %d, reanimados %d, muertos %d", [
		r.get("caidas", 0), r.get("reanimaciones", 0), r.get("muertes", 0)]))

	var causas: Dictionary = r.get("muertes_por_causa", {})
	if not causas.is_empty():
		var partes: Array[String] = []
		for causa: StringName in causas:
			partes.append("%d por %s" % [causas[causa], _nombrar_causa(causa)])
		# Las causas son texto: no se cuentan.
		lista.append(_metrica("Causas: %s" % ", ".join(partes), []))

	lista.append(_metrica("Mana: %d gastado, %d sin usar", [
		r.get("mana_gastado", 0.0), r.get("mana_sin_usar", 0.0)]))

	# Solo si encadeno algo: "Combo maximo: 1" diria lo mismo que no decir
	# nada, y ocuparia un renglon.
	var combo: int = r.get("combo_maximo", 0)
	if combo > 1:
		lista.append(_metrica("Combo maximo: %d", [combo]))

	# Con dos jugadores, cuanto hizo cada uno: sin nota, solo la cuenta. Sirve
	# para ver si uno curo por los dos.
	var usos: Dictionary = r.get("usos_por_jugador", {})
	if int(r.get("jugadores", usos.size())) >= 2 and usos.size() >= 2:
		var jugadores: Array = usos.keys()
		jugadores.sort()
		var formato := PackedStringArray()
		var valores: Array = []
		for jugador: Variant in jugadores:
			formato.append("J%d %%d" % int(jugador))
			valores.append(usos[jugador])
		lista.append(_metrica("Movimientos: " + " · ".join(formato), valores))

	var al_tope: float = r.get("segundos_mana_al_tope", 0.0)
	var duracion: float = maxf(r.get("duracion", 0.0), 0.01)
	lista.append(_metrica("Duracion: %.0f s, %.0f s con el mana lleno (%d%%)", [
		duracion, al_tope, al_tope / duracion * 100.0]))

	return lista


func _metrica(formato: String, valores: Array) -> Dictionary:
	return {"formato": formato, "valores": valores}


## El texto de una metrica con sus numeros a esa altura de la cuenta.
static func _texto_metrica(metrica: Dictionary, avance: float) -> String:
	var valores: Array = metrica["valores"]
	if valores.is_empty():
		return metrica["formato"]
	var parciales: Array = []
	for valor: Variant in valores:
		parciales.append(float(valor) * avance)
	return metrica["formato"] % parciales


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
## es para que la vista sepa con que estilo mostrarlo. Los numeros van con su
## valor final: la cuenta es solo de la vista.
func contenido() -> Array[Dictionary]:
	var filas: Array[Dictionary] = [{"texto": _titulo, "clase": "titulo"}]

	for metrica in _metricas:
		filas.append({"texto": _texto_metrica(metrica, 1.0), "clase": "metrica"})

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


## Todo el texto del informe, un renglon por fila.
func texto() -> String:
	var textos := PackedStringArray()
	for fila in contenido():
		textos.append(fila["texto"])
	return "\n".join(textos)


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
	_cortar()
	for hijo in _columna.get_children():
		hijo.queue_free()
	_etiquetas_metricas.clear()

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
		elif fila["clase"] == "pie":
			etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if fila["clase"] == "metrica":
			_etiquetas_metricas.append(etiqueta)
		_columna.add_child(etiqueta)

	_avance = 0.0
	_contar(0.0)
	_tween = create_tween()
	_tween.tween_method(_contar, 0.0, 1.0, CUENTA) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _contar(avance: float) -> void:
	_avance = avance
	for i in mini(_etiquetas_metricas.size(), _metricas.size()):
		_etiquetas_metricas[i].text = _texto_metrica(_metricas[i], avance)


func _cortar() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## El panel es de madera clara: el texto va oscuro, salvo las metas y la
## observacion, que tienen su propio color.
func _variacion(clase: String) -> StringName:
	match clase:
		"titulo":
			return &"TituloPanel"
		"meta_cumplida":
			return &"MetaCumplida"
		"meta_fallida":
			return &"MetaFallida"
		"pie":
			return &"PiePanel"
	return &"SobrePanel"
