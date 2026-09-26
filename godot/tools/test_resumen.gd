extends SceneTree
## La observacion del final y las metas del encuentro.
##
## Una sola observacion por encuentro, la primera que aplica de una lista
## ordenada por lo que mas le conviene revisar al jugador. Un informe con seis
## consejos no se lee, y si se lee no deja claro por donde empezar.

var _fallos := 0


func _initialize() -> void:
	print("--- prioridad: lo que se podia evitar va primero ---")
	var tele := _con_muerte(&"sangrado", {"vendaje_disponible": true})
	# Ademas del muerto hay desperdicio alto: igual gana el muerto evitable.
	tele._curacion_emitida = 200.0
	tele._curacion_efectiva = 100.0
	_contiene("una muerte evitable manda sobre el desperdicio",
		tele.observacion_causal(), "Vendaje estaba listo")
	_contiene("y dice como se hace", tele.observacion_causal(),
		"ligera dos veces sobre el mismo corta el sangrado")

	print("--- cada situacion tiene su observacion ---")
	tele = _con_muerte(&"sin_atencion", {"reanimar_disponible": true})
	_contiene("morir tirado con Reanimar a mano",
		tele.observacion_causal(), "Reanimar disponible")

	tele = _con_muerte(&"sin_atencion", {"reanimar_disponible": false})
	_contiene("morir tirado sin poder levantarlo",
		tele.observacion_causal(), "el reloj corre")

	tele = _nueva()
	tele._curacion_emitida = 200.0
	tele._curacion_efectiva = 100.0
	_contiene("curar sin mirar a quien", tele.observacion_causal(), "50%")

	tele = _nueva()
	tele._sangrados = 2
	tele._sangrados_sin_tratar = 2
	_contiene("sangrados que nadie corto",
		tele.observacion_causal(), "sin tratar")

	tele = _nueva()
	tele._duracion = 60.0
	tele._usos_por_movimiento["Toque"] = 3
	tele._segundos_mana_al_tope = 40.0
	_contiene("esperar en vez de intervenir",
		tele.observacion_causal(), "mana lleno")

	# Ganar sin tocar nada es la señal de alarma del documento: si la linea se
	# sostiene sola, el encuentro no planteo ninguna decision.
	tele = _nueva()
	tele._duracion = 60.0
	tele._victoria = true
	_contiene("ganar sin usar un movimiento",
		tele.observacion_causal(), "sin usar un solo movimiento")

	print("--- ganar limpio tambien dice algo ---")
	tele = _nueva()
	tele._victoria = true
	tele._usos_por_movimiento["Vendaje"] = 3
	tele._sangrados = 3
	tele._sangrados_estabilizados = 3
	tele._tiempo_total_estabilizar = 6.0
	_contiene("nombra lo que salio bien",
		tele.observacion_causal(), "no perdiste a nadie")

	print("--- singular y plural ---")
	tele = _con_muerte(&"sangrado", {"vendaje_disponible": true})
	_contiene("con uno habla en singular",
		tele.observacion_causal(), "Perdiste un soldado")
	tele = _con_muerte(&"sangrado", {"vendaje_disponible": true})
	_muerte(tele, &"sangrado", {"vendaje_disponible": true})
	_contiene("con dos, en plural", tele.observacion_causal(), "Perdiste 2 soldados")

	print("--- una muerte inevitable no genera reproche ---")
	tele = _con_muerte(&"sangrado", {"vendaje_disponible": false})
	var texto := tele.observacion_causal()
	_ok("no dice que Vendaje estaba listo",
		not texto.contains("Vendaje estaba listo"))

	print("--- metas: se evaluan sobre el resumen ---")
	var resumen := {"fraccion_desperdiciada": 0.10, "sangrados_sin_tratar": 0.0}
	_ok("menor que, cumplida",
		_meta(&"fraccion_desperdiciada", MetaEncuentro.Comparador.MENOR_QUE, 0.15).cumplida(resumen))
	_ok("menor que, fallida",
		not _meta(&"fraccion_desperdiciada", MetaEncuentro.Comparador.MENOR_QUE, 0.05).cumplida(resumen))
	_ok("igual, cumplida",
		_meta(&"sangrados_sin_tratar", MetaEncuentro.Comparador.IGUAL, 0.0).cumplida(resumen))
	_ok("mayor o igual, fallida",
		not _meta(&"fraccion_desperdiciada", MetaEncuentro.Comparador.MAYOR_IGUAL, 0.5).cumplida(resumen))
	_ok("una clave que no existe no se da por cumplida",
		not _meta(&"inventada", MetaEncuentro.Comparador.MENOR_IGUAL, 99.0).cumplida(resumen))

	print("--- el informe nombra el combo mas largo, si hubo ---")
	var informe = load("res://scripts/resumen_encuentro.gd").new()
	root.add_child(informe)
	tele = _nueva()
	tele._combo_maximo = 3
	var lineas: Array[String] = informe._armar_metricas(tele.resumen())
	_ok("con un combo de 3 dice \"Combo maximo: 3\"", lineas.has("Combo maximo: 3"))
	tele._combo_maximo = 1
	lineas = informe._armar_metricas(tele.resumen())
	_ok("tocando de a uno no ocupa un renglon",
		not " ".join(lineas).contains("Combo maximo"))
	_ok("el resumen trae los golpes al aire", tele.resumen().has("movimientos_en_vacio"))
	_ok("y los usos por movimiento", tele.resumen().has("usos_por_movimiento"))

	print("--- los encuentros de la campania traen sus metas ---")
	var e2: Encuentro = load("res://resources/encuentros/e2_no_desperdiciar.tres")
	_ok("el de eficiencia mide el desperdicio", e2.metas.size() == 1)
	_ok("y la meta apunta a una clave real",
		tele.resumen().has(e2.metas[0].clave))

	var e3: Encuentro = load("res://resources/encuentros/e3_tratar_la_causa.tres")
	_ok("el del sangrado tiene dos metas", e3.metas.size() == 2)
	for meta in e3.metas:
		_ok("la clave '%s' existe en el resumen" % meta.clave,
			tele.resumen().has(meta.clave))

	print("")
	print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Una telemetria con un encuentro abierto y nada anotado.
func _nueva() -> Telemetria:
	var tele := Telemetria.new()
	root.add_child(tele)
	var enc := Encuentro.new()
	enc.id = &"prueba"
	tele._on_encuentro_iniciado(enc, 1, 0)
	return tele


func _con_muerte(causa: StringName, extra: Dictionary) -> Telemetria:
	var tele := _nueva()
	_muerte(tele, causa, extra)
	return tele


## Anota una muerte como lo haria la unidad, sin tener que armar el combate.
func _muerte(tele: Telemetria, causa: StringName, extra: Dictionary) -> void:
	tele._muertes += 1
	tele._muertes_por_causa[causa] = tele._muertes_por_causa.get(causa, 0) + 1
	var datos := extra.duplicate()
	datos["causa"] = causa
	tele.registrar(&"muerte", datos)


func _meta(clave: StringName, comparador: MetaEncuentro.Comparador, valor: float) -> MetaEncuentro:
	var m := MetaEncuentro.new()
	m.clave = clave
	m.comparador = comparador
	m.valor = valor
	m.texto = "prueba"
	return m


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _contiene(que: String, texto: String, fragmento: String) -> void:
	if not texto.contains(fragmento):
		_fallos += 1
		print("  [FALLA] %s -> \"%s\"" % [que, texto])
		return
	print("  [OK] %s" % que)
