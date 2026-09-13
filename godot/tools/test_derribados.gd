extends SceneTree
## Derribados y reanimacion, sobre ticks de fisica reales.

var _contenedor: Node3D
var _healer: Healer3D
var _componente: ComponenteHabilidades
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
	_aliado = _crear(Unidad3D.Bando.ALIADO, Vector3(16, 0, 5))
	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	match _fase:
		0:
			_componente = _healer.get_node("Habilidades")
			_componente.habilidad_usada.connect(func(_h: Habilidad, t: String) -> void: _avisos.append(t))
			_componente.habilidad_fallo.connect(func(_h: Habilidad, m: String) -> void: _avisos.append(m))

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

			print("--- habilidades sobre una derribada ---")
			_healer._apuntada = _aliado
			_healer.mana = 100.0
			_componente._restante.clear()
			_avisos.clear()
			_ok("curar no se usa sobre una derribada",
				not _componente.intentar(_componente.habilidad_por_nombre("Curar")))
			_ok("y avisa que hay que reanimar", _tiene_aviso("reanimar"))

			_ok("hay 6 habilidades", _componente.habilidades.size() == 6)
			var reanimar := _componente.habilidad_por_nombre("Reanimar")
			_ok("Reanimar esta equipada", reanimar != null)

			_avisos.clear()
			_ok("reanimar se usa", _componente.intentar(reanimar))
			_ok("vuelve a estar en pie", not _aliado.esta_derribada() and _aliado.esta_viva())
			_igual("vuelve con parte de la vida",
				_aliado.vida, _aliado.vida_maxima * _aliado.vida_al_reanimar)
			_igual("cobra 40", _healer.mana, 60.0)

			_componente._restante.clear()
			_avisos.clear()
			_ok("no se reanima a quien esta en pie", not _componente.intentar(reanimar))
			_ok("y lo dice", _tiene_aviso("No esta derribado"))
			_fase = 3
		3:
			_ok("la colision vuelve", not _aliado._colision.disabled)
			print("--- si nadie llega, muere ---")
			_aliado.recibir_dano(500.0)
			_aliado.derribada_restante = 0.2
			_ticks = 0
			_fase = 4
		4:
			if _ticks < 30:
				return
			_ok("pasado el tiempo muere de verdad", not _aliado.esta_viva())
			_fase = 5
		5:
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit(1 if _fallos > 0 else 0)
			_fase = 6

	if _ticks > 2000:
		print("FALLA: el test no termino")
		quit(1)


func _crear(bando: Unidad3D.Bando, pos: Vector3) -> Unidad3D:
	var u: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	u.configurar(bando)
	u.position = pos
	_contenedor.add_child(u)
	return u


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
