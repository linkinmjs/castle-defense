extends SceneTree
## Tipos de soldado y estilos de combate, sobre ticks de fisica reales.

var _contenedor: Node3D
var _escudero: TipoSoldado
var _lancero: TipoSoldado
var _espadachin: TipoSoldado
var _zombie: TipoSoldado
var _e: Unidad3D
var _l: Unidad3D
var _z: Unidad3D
var _s: Unidad3D
var _sano: Unidad3D
var _herido: Unidad3D
var _vida_ref := 0.0
var _fallos := 0
var _fase := 0
var _ticks := 0


func _initialize() -> void:
	_contenedor = Node3D.new()
	root.add_child(_contenedor)
	_escudero = load("res://resources/soldados/escudero.tres")
	_lancero = load("res://resources/soldados/lancero.tres")
	_espadachin = load("res://resources/soldados/espadachin.tres")
	_zombie = load("res://resources/soldados/zombie.tres")
	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	match _fase:
		0:
			print("--- tipos ---")
			_ok("hay tres tipos de aliado y uno de enemigo",
				_escudero != null and _lancero != null and _espadachin != null and _zombie != null)
			_e = _crear(Unidad3D.Bando.ALIADO, _escudero, Vector3(10, 0, 5))
			_fase = 1
		1:
			_igual("el escudero toma la vida del tipo", _e.vida_maxima, 110.0)
			_ok("y sus sprites", _e._sprite.sprite_frames == _escudero.frames)
			_e.probabilidad_sangrado = 0.0
			_e.recibir_dano(20.0)
			_igual("el escudo descuenta un cuarto del dano", _e.vida, 95.0)

			print("--- lancero: segunda fila ---")
			# A dos metros: dentro del alcance del lancero, fuera del zombi.
			_l = _crear(Unidad3D.Bando.ALIADO, _lancero, Vector3(12, 0, 7))
			_z = _crear(Unidad3D.Bando.ENEMIGO, _zombie, Vector3(14, 0, 7))
			_ticks = 0
			_fase = 2
		2:
			if _ticks < 5:
				return
			_ok("combate a dos metros sin acercarse",
				_l.estado == Unidad3D.Estado.COMBATIENDO
				and absf(_l.global_position.x - 12.0) < 0.15)

			print("--- retirada ---")
			_l.vida = 15.0  # 15/70 < 0.3
			_ticks = 0
			_fase = 3
		3:
			if _ticks < 20:
				return
			_ok("herido se retira", _l.estado == Unidad3D.Estado.RETIRANDOSE)
			_ok("hacia su base", _l.global_position.x < 12.0 - 0.1)
			_vida_ref = _l.vida
			_ticks = 0
			_fase = 31
		31:
			if _ticks < 60:
				return
			_igual("se recupera despacio mientras esta retirado",
				_l.vida - _vida_ref, _l.regeneracion_retirada, 0.7)
			_l.regeneracion_retirada = 40.0  # acelerado para no esperar 8 s
			_ticks = 0
			_fase = 32
		32:
			if _ticks < 60:
				return
			_ok("recuperado vuelve solo al combate", _l.estado != Unidad3D.Estado.RETIRANDOSE)
			_l.vida = 15.0
			_l.regeneracion_retirada = 0.0
			_l._physics_process(1.0 / 60.0)
			_ok("vuelve a retirarse si lo hieren", _l.estado == Unidad3D.Estado.RETIRANDOSE)
			_l.curar(40.0)  # 55/70: por encima del umbral con histeresis
			_ticks = 0
			_fase = 4
		4:
			if _ticks < 5:
				return
			_ok("curado vuelve al combate", _l.estado != Unidad3D.Estado.RETIRANDOSE)
			_z.free()
			_l.free()

			print("--- espadachin oportunista ---")
			_s = _crear(Unidad3D.Bando.ALIADO, _espadachin, Vector3(20, 0, 5))
			_sano = _crear(Unidad3D.Bando.ENEMIGO, _zombie, Vector3(21.5, 0, 5))
			_herido = _crear(Unidad3D.Bando.ENEMIGO, _zombie, Vector3(23.0, 0, 5))
			_herido.vida = 10.0
			_ticks = 0
			_fase = 5
		5:
			if _ticks < 3:
				return
			_ok("el oportunista elige al mas herido aunque este mas lejos",
				_s._objetivo == _herido)
			_ok("los demas eligen al mas cercano", _sano._objetivo == _s)
			_fase = 6
		6:
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit()
			_fase = 7

	if _ticks > 2000:
		print("FALLA: el test no termino")
		quit()


func _crear(bando: Unidad3D.Bando, tipo: TipoSoldado, pos: Vector3) -> Unidad3D:
	var u: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	u.configurar(bando, tipo)
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
