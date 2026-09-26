extends SceneTree
## Tipos de soldado y estilos de combate, sobre ticks de fisica reales.

var _contenedor: Node3D
var _escudero: TipoSoldado
var _lancero: TipoSoldado
var _espadachin: TipoSoldado
var _zombie: TipoSoldado
var _bruto: TipoSoldado
var _demonio: TipoSoldado
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
	_bruto = load("res://resources/soldados/bruto.tres")
	_demonio = load("res://resources/soldados/demonio.tres")
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
			_revisar_bruto_y_demonio()
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit(1 if _fallos > 0 else 0)
			_fase = 7

	if _ticks > 2000:
		print("FALLA: el test no termino")
		quit(1)


## Los dos que pegan anunciado. El comportamiento lo cubre test_bruto; aca, que
## los recursos digan lo que el diseno pide y que los viejos no cambiaron.
func _revisar_bruto_y_demonio() -> void:
	print("--- bruto y demonio ---")
	_ok("existen los dos", _bruto != null and _demonio != null)
	if _bruto == null or _demonio == null:
		return

	_igual("vida del bruto", _bruto.vida_maxima, 260.0)
	_igual("dano del bruto", _bruto.dano, 34.0)
	_igual("cadencia del bruto", _bruto.cadencia, 2.6)
	_igual("alcance del bruto", _bruto.alcance, 1.6)
	_igual("velocidad del bruto", _bruto.velocidad, 0.7)
	_igual("aviso del bruto", _bruto.telegrafiado, 1.2)
	_ok("el bruto barre a ras del suelo", _bruto.barrido)
	_igual("radio del golpe del bruto", _bruto.radio_golpe, 1.2)
	_ok("con un solo ataque", _bruto.anim_ataque_2 == "")
	_ok("y no es jefe", not _bruto.es_jefe)
	_ok("hoja de 40 px con el oso en 31",
		_bruto.lado_frame == 40 and is_equal_approx(_bruto.alto_util_px, 31.0))
	_igual("mide 2.2 m", _bruto.altura_metros, 2.2)
	_igual("ocupa 0.5 m de radio", _bruto.radio_colision, 0.5)
	_igual("barra del bruto", _bruto.altura_barra, 2.4)
	_ok("sus sprites tienen el ataque", _bruto.frames != null
		and _bruto.frames.has_animation(&"attack"))

	_igual("vida del demonio", _demonio.vida_maxima, 700.0)
	_igual("dano del demonio", _demonio.dano, 24.0)
	_igual("cadencia del demonio", _demonio.cadencia, 3.0)
	_igual("alcance del demonio", _demonio.alcance, 2.6)
	_igual("velocidad del demonio", _demonio.velocidad, 0.8)
	_igual("aviso del demonio", _demonio.telegrafiado, 1.4)
	_ok("el demonio no barre: saltar no lo esquiva", not _demonio.barrido)
	_igual("radio del golpe del demonio", _demonio.radio_golpe, 1.8)
	_ok("alterna con attack2", _demonio.anim_ataque_2 == "attack2")
	_igual("que pega 1.5 veces", _demonio.factor_ataque_2, 1.5)
	_ok("y es el jefe", _demonio.es_jefe)
	_ok("hoja de 96 px con el demonio en 52",
		_demonio.lado_frame == 96 and is_equal_approx(_demonio.alto_util_px, 52.0))
	_igual("mide 3.2 m", _demonio.altura_metros, 3.2)
	_igual("ocupa 0.7 m de radio", _demonio.radio_colision, 0.7)
	_igual("barra del demonio", _demonio.altura_barra, 3.5)
	_ok("sus sprites tienen los dos ataques", _demonio.frames != null
		and _demonio.frames.has_animation(&"attack") and _demonio.frames.has_animation(&"attack2"))

	for tipo in [_escudero, _lancero, _espadachin, _zombie]:
		_ok("%s sigue con el tamano y el golpe de siempre" % tipo.nombre,
			tipo.lado_frame == 128 and is_equal_approx(tipo.alto_util_px, 68.0)
			and is_equal_approx(tipo.altura_metros, 2.0)
			and is_equal_approx(tipo.radio_colision, 0.32)
			and is_equal_approx(tipo.altura_barra, 2.1)
			and tipo.telegrafiado == 0.0 and tipo.radio_golpe == 0.0
			and not tipo.barrido and tipo.anim_ataque_2 == "" and not tipo.es_jefe)


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
