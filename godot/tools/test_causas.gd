extends SceneTree
## De que se cayo cada uno y de que murio.
##
## El resumen puede contar cuantos se perdieron sin esto, pero no puede decir
## si habia algo que hacer al respecto. "Murio de un golpe" y "murio tirado
## esperando" son dos lecciones distintas para el jugador.

var _contenedor: Node3D
var _fallos := 0
var _fase := 0
var _ticks := 0
var _curaciones: Array[Vector2] = []
var _cortes: Array[float] = []
var _expirados := 0
var _inicios := 0
var _reanimaciones := 0
var _victima: Unidad3D


func _initialize() -> void:
	_contenedor = Node3D.new()
	root.add_child(_contenedor)
	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	match _fase:
		0:
			if _ticks < 2:
				return
			print("--- causa de un golpe ---")
			var u := _crear()
			u.probabilidad_sangrado = 0.0
			var agresor := _crear(Unidad3D.Bando.ENEMIGO)
			u.recibir_dano(500.0, agresor)
			_ok("cae de un golpe", u.causa_caida == &"golpe")
			_ok("y recuerda quien fue (%s)" % u.fuente_ultimo_dano,
				u.fuente_ultimo_dano == "Zombi")
			u.free()
			agresor.free()

			print("--- causa de un sangrado ---")
			var s := _crear()
			s.probabilidad_sangrado = 0.0
			s.dano_sangrado = 200.0
			s.aplicar_sangrado(5.0)
			s._actualizar_sangrado(1.0)
			_ok("cae por el sangrado", s.causa_caida == &"sangrado")
			s.free()
			_fase = 1
		1:
			print("--- morir tirado no es lo mismo que morir de un golpe ---")
			_victima = _crear()
			_victima.probabilidad_sangrado = 0.0
			_victima.recibir_dano(500.0)
			_ok("primero queda derribada", _victima.esta_derribada())
			_victima.derribada_restante = 0.05
			_ticks = 0
			_fase = 2
		2:
			if _ticks < 12:
				return
			_ok("si nadie llega, muere", not _victima.esta_viva())
			_ok("y la causa es haber quedado sin atencion",
				_victima.causa_muerte == &"sin_atencion")
			_victima.free()
			_fase = 3
		3:
			print("--- curar avisa cuanto entro de verdad ---")
			var u := _crear()
			u.curada.connect(func(p: float, e: float) -> void: _curaciones.append(Vector2(p, e)))
			u.vida = u.vida_maxima - 10.0
			u.curar(35.0)
			_igual("se pidieron 35", _curaciones[0].x, 35.0)
			_ok("entraron 10 y se perdieron 25", is_equal_approx(_curaciones[0].y, 10.0))

			_curaciones.clear()
			u.curar(35.0)
			_ok("sobre uno sano no entra nada", is_equal_approx(_curaciones[0].y, 0.0))
			u.free()
			_fase = 4
		4:
			print("--- el sangrado avisa cuando empieza y como termina ---")
			var u := _crear()
			u.sangrado_iniciado.connect(func() -> void: _inicios += 1)
			u.sangrado_cortado.connect(func(s: float) -> void: _cortes.append(s))
			u.sangrado_expiro.connect(func(_s: float) -> void: _expirados += 1)
			u.probabilidad_sangrado = 0.0
			u.dano_sangrado = 0.0

			u.aplicar_sangrado(8.0)
			_igual("avisa que empezo", float(_inicios), 1.0)
			u.aplicar_sangrado(8.0)
			_igual("refrescarlo no cuenta como uno nuevo", float(_inicios), 1.0)

			u._actualizar_sangrado(2.0)
			u.estabilizar()
			_ok("avisa el corte", _cortes.size() == 1)
			_igual("con los segundos que estuvo sangrando", _cortes[0], 2.0, 0.1)
			_igual("y no cuenta como sin tratar", float(_expirados), 0.0)

			# Ahora uno que nadie corta: es una crisis que quedo sin atender.
			u.aplicar_sangrado(1.0)
			u._actualizar_sangrado(1.5)
			_igual("un sangrado que se agota si cuenta", float(_expirados), 1.0)
			u.free()
			_fase = 5
		5:
			print("--- caer sangrando deja el sangrado sin tratar ---")
			var u := _crear()
			_expirados = 0
			u.sangrado_expiro.connect(func(_s: float) -> void: _expirados += 1)
			u.probabilidad_sangrado = 0.0
			u.aplicar_sangrado(8.0)
			u.recibir_dano(500.0)
			_ok("quedo derribada", u.esta_derribada())
			_igual("y el sangrado cuenta como sin tratar", float(_expirados), 1.0)

			u.reanimada.connect(func() -> void: _reanimaciones += 1)
			u.reanimar()
			_igual("reanimar avisa", float(_reanimaciones), 1.0)
			_ok("y se olvida de como habia caido", u.causa_caida == &"")
			u.free()
			_fase = 6
		6:
			print("--- un solo problema por unidad, el mas grave ---")
			var u := _crear()
			u.probabilidad_sangrado = 0.0
			_ok("sana y entera esta estable", u.estado_dominante() == &"estable")
			_ok("con urgencia estable", u.urgencia() == Unidad3D.Urgencia.ESTABLE)

			u.vida = u.vida_maxima * 0.3
			_ok("con poca vida, el problema es la vida", u.estado_dominante() == &"vida_baja")

			u.aplicar_sangrado(6.0)
			_ok("sangrando, el sangrado manda", u.estado_dominante() == &"sangrado")
			_ok("y es critico con poca vida", u.urgencia() == Unidad3D.Urgencia.CRITICO)
			_igual("el reloj del estado son los segundos que quedan",
				u.segundos_estado(), 6.0, 0.1)

			u.recibir_dano(500.0)
			_ok("derribada, el derribo tapa todo", u.estado_dominante() == &"derribada")
			_ok("y siempre es critico", u.urgencia() == Unidad3D.Urgencia.CRITICO)
			u.free()
			_fase = 7
		7:
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit(1 if _fallos > 0 else 0)
			_fase = 8

	if _ticks > 600:
		print("FALLA: el test no termino")
		quit(1)


func _crear(bando: Unidad3D.Bando = Unidad3D.Bando.ALIADO) -> Unidad3D:
	var u: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	var ruta := "res://resources/soldados/escudero.tres" if bando == Unidad3D.Bando.ALIADO \
		else "res://resources/soldados/zombie.tres"
	u.configurar(bando, load(ruta))
	u.sembrar(1)
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
	print("  [%s] %-48s obtenido=%.2f esperado=%.2f" % [
		"OK" if ok else "FALLA", que, obtenido, esperado])
