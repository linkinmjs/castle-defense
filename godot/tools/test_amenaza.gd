extends SceneTree
## Vida del healer, caida y levantada, cobertura por objetivo y emergentes.
## Corre sobre ticks de fisica reales.

const DT := 1.0 / 60.0

var _contenedor: Node3D
var _healer: Healer3D
var _enemigo: Unidad3D
var _aliado: Unidad3D
var _emergente: Emergente3D
var _emergente_aviso: Vector3 = Vector3.INF
var _fallos := 0
var _fase := 0
var _ticks := 0


func _initialize() -> void:
	_contenedor = Node3D.new()
	root.add_child(_contenedor)
	_healer = load("res://scenes/3d/healer3d.tscn").instantiate()
	_healer.position = Vector3(15, 0, 5)
	_contenedor.add_child(_healer)
	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	match _fase:
		0:
			print("--- vida del healer ---")
			_igual("arranca con la vida al maximo", _healer.vida, _healer.vida_maxima)
			_healer.recibir_dano(20.0)
			_igual("el dano se descuenta", _healer.vida, _healer.vida_maxima - 20.0)
			_ok("sigue en pie", _healer.esta_viva())

			_healer.recibir_dano(500.0)
			_ok("a cero cae", not _healer.esta_viva())
			_igual("no queda vida negativa", _healer.vida, 0.0)
			_healer.recibir_dano(20.0)
			_ok("caido no recibe mas dano", _healer.vida == 0.0)
			_ok("caido no puede saltar", not _saltar_funciona())
			_ticks = 0
			_fase = 1
		1:
			if _healer.esta_viva():
				var segundos := _ticks * DT
				_ok("se levanta pasado el tiempo (%.1f s)" % segundos,
					absf(segundos - _healer.tiempo_caido) < 0.1)
				_igual("se levanta con parte de la vida",
					_healer.vida, _healer.vida_maxima * _healer.vida_al_levantarse)
				_fase = 2
			elif _ticks > 600:
				_ok("se levanta pasado el tiempo", false)
				_fase = 2
		2:
			print("--- cobertura por objetivo ---")
			# Enemigo solo frente al healer: lo elige a el.
			_enemigo = _crear(Unidad3D.Bando.ENEMIGO, Vector3(12.0, 0, 5))
			_fase = 3
		3:
			if _ticks < 3:
				return
			_ok("sin soldados cerca, el enemigo va por el healer",
				_enemigo._objetivo == _healer)
			# Aparece un soldado mas cerca del enemigo que el healer.
			_aliado = _crear(Unidad3D.Bando.ALIADO, Vector3(13.0, 0, 5))
			_enemigo._objetivo = null  # que vuelva a elegir
			_ticks = 0
			_fase = 4
		4:
			if _ticks < 3:
				return
			_ok("con un soldado en el medio, el enemigo lo elige a el",
				_enemigo._objetivo == _aliado)
			_aliado.free()
			_enemigo.free()
			_fase = 5
		5:
			print("--- emergente ---")
			_emergente = load("res://scenes/3d/emergente3d.tscn").instantiate()
			_emergente.duracion = 0.25
			_emergente.position = Vector3(17, 0, 5)
			_emergente.termino.connect(func(p: Vector3) -> void: _emergente_aviso = p)
			_contenedor.add_child(_emergente)
			_ticks = 0
			_fase = 6
		6:
			if _emergente_aviso == Vector3.INF:
				if _ticks > 120:
					_ok("el aviso termina y avisa donde", false)
					_fase = 7
				return
			_ok("el aviso termina y avisa donde", true)
			_igual("avisa en su propia posicion", _emergente_aviso.x, 17.0)
			_ok("el aviso se elimina solo", not is_instance_valid(_emergente)
				or _emergente.is_queued_for_deletion())
			_fase = 7
		7:
			print("--- salir del suelo ---")
			_enemigo = _crear(Unidad3D.Bando.ENEMIGO, Vector3(17, 0, 5))
			_enemigo.emerger(0.25)
			_ok("arranca enterrado", _enemigo.global_position.y < -1.5)
			_ok("sin fisica mientras sale", not _enemigo.is_physics_processing())
			_ticks = 0
			_fase = 8
		8:
			if _ticks < 30:
				return
			_igual("termina a ras del suelo", _enemigo.global_position.y, 0.0, 0.05)
			_ok("recupera la fisica al salir", _enemigo.is_physics_processing())
			_fase = 9
		9:
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit()
			_fase = 10

	if _ticks > 2000:
		print("FALLA: el test no termino")
		quit()


func _saltar_funciona() -> bool:
	var antes := _healer.velocity.y
	_healer.saltar()
	return _healer.velocity.y != antes


func _crear(bando: Unidad3D.Bando, pos: Vector3) -> Unidad3D:
	var u: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	u.configurar(bando)
	u.position = pos
	_contenedor.add_child(u)
	return u


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
