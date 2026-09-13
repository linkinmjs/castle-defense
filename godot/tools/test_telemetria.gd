extends SceneTree
## Lo que se mide de un encuentro.
##
## Corre sin instanciar el HUD a proposito: si medir dependiera de la interfaz,
## el modelo de combate dejaria de poder probarse headless. La telemetria
## escucha señales y publica un Dictionary; nadie le pregunta nada a la UI.

var _contenedor: Node3D
var _tele: Telemetria
var _healer: Healer3D
var _componente: ComponenteHabilidades
var _aliado: Unidad3D
var _resumen: Dictionary = {}
var _cerrados := 0
var _fallos := 0
var _fase := 0
var _ticks := 0


func _initialize() -> void:
	_contenedor = Node3D.new()
	root.add_child(_contenedor)

	_healer = load("res://scenes/3d/healer3d.tscn").instantiate()
	_healer.position = Vector3(15, 0, 5)
	_contenedor.add_child(_healer)
	_componente = _healer.get_node("Habilidades")

	_tele = Telemetria.new()
	_contenedor.add_child(_tele)
	_tele.observar_healer(_healer)
	_tele.encuentro_cerrado.connect(func(r: Dictionary) -> void:
		_resumen = r
		_cerrados += 1)

	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	match _fase:
		0:
			if _ticks < 2:
				return
			# Sin batalla: se abre el encuentro a mano para dejar claro que la
			# telemetria no necesita la escena completa.
			_tele._on_encuentro_iniciado(_encuentro_falso(), 4242, 0)

			_aliado = _crear()
			_tele.observar_unidad(_aliado)
			_healer._apuntada = _aliado

			print("--- curacion emitida, efectiva y desperdiciada ---")
			_aliado.vida = _aliado.vida_maxima - 10.0
			_aliado.curar(35.0)
			var r := _tele.resumen()
			_igual("emitida", r["curacion_emitida"], 35.0)
			_igual("efectiva", r["curacion_efectiva"], 10.0)
			_igual("desperdiciada", r["curacion_desperdiciada"], 25.0)
			_igual("fraccion desperdiciada", r["fraccion_desperdiciada"], 25.0 / 35.0, 0.01)

			print("--- sangrado: cuantos, cuantos tratados y cuanto se tardo ---")
			_aliado.dano_sangrado = 0.0
			_aliado.probabilidad_sangrado = 0.0
			_aliado.aplicar_sangrado(8.0)
			_aliado._actualizar_sangrado(2.0)
			_aliado.estabilizar()
			r = _tele.resumen()
			_igual("un sangrado", r["sangrados"], 1.0)
			_igual("estabilizado", r["sangrados_estabilizados"], 1.0)
			_igual("tardo 2 segundos", r["tiempo_hasta_estabilizar"], 2.0, 0.1)
			_igual("ninguno sin tratar", r["sangrados_sin_tratar"], 0.0)

			# Uno que nadie corta.
			_aliado.aplicar_sangrado(1.0)
			_aliado._actualizar_sangrado(1.5)
			_igual("ahora hay uno sin tratar", _tele.resumen()["sangrados_sin_tratar"], 1.0)
			_fase = 1
		1:
			print("--- que habilidades se usaron y cuanto mana costaron ---")
			_healer.mana = _healer.mana_maximo
			_componente._restante.clear()
			_aliado.vida = 10.0
			_componente.intentar(_componente.habilidad_por_nombre("Curar"))
			var r := _tele.resumen()
			_igual("se anota el uso", float(r["usos_por_habilidad"].get("Curar", 0)), 1.0)
			_igual("y el mana que costo", r["mana_gastado"], 25.0)
			_fase = 2
		2:
			print("--- muertes con causa y con lo que habia a mano ---")
			_aliado.probabilidad_sangrado = 0.0
			_aliado.recibir_dano(500.0)
			_igual("cuenta la caida", _tele.resumen()["caidas"], 1.0)
			_aliado.derribada_restante = 0.05
			_ticks = 0
			_fase = 3
		3:
			if _ticks < 12:
				return
			var r := _tele.resumen()
			_igual("cuenta la muerte", r["muertes"], 1.0)
			_igual("y la agrupa por causa",
				float(r["muertes_por_causa"].get(&"sin_atencion", 0)), 1.0)

			var muerte := _buscar_evento(&"muerte")
			_ok("el evento de muerte existe", not muerte.is_empty())
			_ok("y guarda si Curar estaba disponible", muerte.has("curar_disponible"))
			_ok("la causa viaja en el evento", muerte.get("causa", &"") == &"sin_atencion")
			_fase = 4
		4:
			print("--- reanimar se cuenta aparte ---")
			var vivo := _crear()
			_tele.observar_unidad(vivo)
			vivo.probabilidad_sangrado = 0.0
			vivo.recibir_dano(500.0)
			vivo.reanimar()
			_igual("una reanimacion", _tele.resumen()["reanimaciones"], 1.0)
			vivo.free()
			_fase = 5
		5:
			print("--- cerrar publica el resumen una sola vez ---")
			_tele.cerrar(true)
			_igual("aviso una vez", float(_cerrados), 1.0)
			_ok("y dice si se gano", _resumen.get("victoria", false) == true)
			_igual("con la semilla del encuentro", float(_resumen.get("semilla", 0)), 4242.0)
			_ok("y con su id", _resumen.get("encuentro_id", &"") == &"prueba")

			_tele.cerrar(true)
			_igual("cerrar de nuevo no hace nada", float(_cerrados), 1.0)
			_fase = 6
		6:
			print("--- abrir otro encuentro empieza de cero ---")
			_tele._on_encuentro_iniciado(_encuentro_falso(), 77, 1)
			var r := _tele.resumen()
			_igual("la curacion vuelve a cero", r["curacion_emitida"], 0.0)
			_igual("las muertes tambien", r["muertes"], 0.0)
			_igual("y los sangrados", r["sangrados"], 0.0)
			_ok("los eventos se vacian", _tele.eventos().is_empty())
			_fase = 7
		7:
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit(1 if _fallos > 0 else 0)
			_fase = 8

	if _ticks > 600:
		print("FALLA: el test no termino")
		quit(1)


func _encuentro_falso() -> Encuentro:
	var enc := Encuentro.new()
	enc.id = &"prueba"
	return enc


func _crear() -> Unidad3D:
	var u: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	u.configurar(Unidad3D.Bando.ALIADO, load("res://resources/soldados/escudero.tres"))
	u.sembrar(1)
	u.position = Vector3(15.8, 0, 5)
	_contenedor.add_child(u)
	return u


func _buscar_evento(nombre: StringName) -> Dictionary:
	for evento in _tele.eventos():
		if evento.get("evento", &"") == nombre:
			return evento
	return {}


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _igual(que: String, obtenido: float, esperado: float, tolerancia: float = 0.01) -> void:
	var ok := absf(obtenido - esperado) < tolerancia
	if not ok:
		_fallos += 1
	print("  [%s] %-44s obtenido=%.2f esperado=%.2f" % [
		"OK" if ok else "FALLA", que, obtenido, esperado])
