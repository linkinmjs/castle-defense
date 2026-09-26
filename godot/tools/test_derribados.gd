extends SceneTree
## Derribados y reanimacion, sobre ticks de fisica reales.

## Mas que la recuperacion de la pesada (0.6 s): lo que tarda en poder volver
## a apretarse.
const TRAS_PESADA := 40

var _contenedor: Node3D
var _healer: Healer3D
var _combos: ComponenteCombos
var _aliado: Unidad3D
var _enemigo: Unidad3D
var _avisos: Array[String] = []
var _fallos := 0
var _fase := 0
var _ticks := 0


func _initialize() -> void:
	_contenedor = Node3D.new()
	root.add_child(_contenedor)
	_healer = load("res://scenes/3d/healer3d.tscn").instantiate()
	_healer.position = Vector3(15, 0, 5)
	_contenedor.add_child(_healer)
	# Sin regeneracion: cada comprobacion de mana mide solo lo que se cobro.
	_healer.regeneracion_mana = 0.0
	# A 1 m al frente del healer, que mira hacia +X: dentro de las dos cajas.
	_aliado = _crear(Unidad3D.Bando.ALIADO, Vector3(16, 0, 5))
	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	match _fase:
		0:
			_combos = _healer.get_node("Combos")
			_combos.aviso.connect(func(t: String) -> void: _avisos.append(t))
			_combos.movimiento_fallo.connect(
				func(_m: Movimiento, motivo: String) -> void: _avisos.append(motivo))

			print("--- caer ---")
			_aliado.probabilidad_sangrado = 0.0
			_aliado.recibir_dano(500.0)
			_ok("a cero queda derribada", _aliado.esta_derribada())
			_ok("derribada sigue contando como viva", _aliado.esta_viva())
			_igual("la vida queda en cero", _aliado.vida, 0.0)
			_aliado.recibir_dano(20.0)
			_ok("derribada no recibe mas dano", _aliado.vida == 0.0)
			_igual("curar no la levanta", _aliado.curar(30.0), 0.0)
			_igual("el reloj arranca lleno", _aliado.fraccion_derribada(), 1.0, 0.02)
			_fase = 1
		1:
			_ok("la colision se apaga", _aliado._colision.disabled)
			print("--- los enemigos la ignoran ---")
			# El enemigo tiene a la derribada a 0.8 m y al healer a 1.8 m.
			_enemigo = _crear(Unidad3D.Bando.ENEMIGO, Vector3(16.8, 0, 5))
			_ticks = 0
			_fase = 2
		2:
			if _ticks < 3:
				return
			_ok("el enemigo no elige a la derribada", _enemigo._objetivo != _aliado)
			_ok("elige al healer, mas lejos pero en pie", _enemigo._objetivo == _healer)
			_enemigo.free()

			print("--- movimientos con una derribada al frente ---")
			_igual("el healer trae los 8 movimientos", _combos.movimientos.size(), 8.0)
			_ok("Reanimar esta equipado", _combos.movimiento_por_nombre("Reanimar") != null)
			_healer.mana = 100.0
			_avisos.clear()
			_ok("la ligera no toca a una derribada",
				not _healer.pulsar(&"ligera") and _tiene_aviso(ComponenteCombos.EN_VACIO))
			_igual("y no cobra", _healer.mana, 100.0)

			_ok("la pesada resuelve a Reanimar", _resuelve(&"pesada") == "Reanimar")
			_avisos.clear()
			_ok("la pesada sale", _healer.pulsar(&"pesada"))
			_ok("y lo avisa", _tiene_aviso("Reanimado"))
			_ok("vuelve a estar en pie", not _aliado.esta_derribada() and _aliado.esta_viva())
			_igual("vuelve con parte de la vida",
				_aliado.vida, _aliado.vida_maxima * _aliado.vida_al_reanimar)
			_igual("Reanimar cobra 40", _healer.mana, 60.0)
			_ok("en pie, la pesada vuelve a ser Plegaria", _resuelve(&"pesada") == "Plegaria")
			_ticks = 0
			_fase = 3
		3:
			if _ticks < TRAS_PESADA:
				return
			_ok("la colision vuelve", not _aliado._colision.disabled)
			_ok("apretada, la pesada reza la Plegaria",
				_healer.pulsar(&"pesada") and _en_curso() == "Plegaria")
			_ok("y el healer queda comprometido", _healer.esta_en_wind_up())
			_ticks = 0
			_fase = 4
		4:
			if _healer.esta_en_wind_up():
				return
			_ok("la Plegaria salio sobre el reanimado", _tiene_aviso("Plegaria"))
			print("--- si nadie llega, muere ---")
			_aliado.recibir_dano(500.0)
			_aliado.derribada_restante = 0.2
			_ticks = 0
			_fase = 5
		5:
			if _ticks < 30:
				return
			_ok("pasado el tiempo muere de verdad", not _aliado.esta_viva())
			_fase = 6
		6:
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit(1 if _fallos > 0 else 0)
			_fase = 7

	if _ticks > 2000:
		print("FALLA: el test no termino")
		quit(1)


func _crear(bando: Unidad3D.Bando, pos: Vector3) -> Unidad3D:
	var u: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	u.configurar(bando)
	u.position = pos
	_contenedor.add_child(u)
	return u


func _resuelve(entrada: StringName) -> String:
	var mov := _combos.resolver(entrada)
	return mov.nombre if mov != null else ""


func _en_curso() -> String:
	var mov := _combos.movimiento_en_curso()
	return mov.nombre if mov != null else ""


func _tiene_aviso(fragmento: String) -> bool:
	for a in _avisos:
		if a.to_lower().contains(fragmento.to_lower()):
			return true
	return false


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _igual(que: String, obtenido: float, esperado: float, tolerancia: float = 0.01) -> void:
	var ok := absf(obtenido - esperado) < tolerancia
	if not ok:
		_fallos += 1
	print("  [%s] %-40s obtenido=%.2f esperado=%.2f" % [
		"OK" if ok else "FALLA", que, obtenido, esperado])
