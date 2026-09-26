extends PruebaBase
## Los relojes del juego corren al paso de la fisica, y lo que cuelga de ellos
## se comporta igual sin importar cuanto tarde cada frame.
##
## test_campania fallaba de a ratos por esto: el desenlace se evaluaba en
## _process, y justo despues de cambiar de encuentro el frame es lento y Godot
## corre varios pasos de fisica seguidos sin ningun _process en el medio.

const ESCUDERO := "res://resources/soldados/escudero.tres"
const ZOMBIE := "res://resources/soldados/zombie.tres"

var _battle: Node
var _healer: Healer3D
var _oleada: OleadaEncuentro
var _unidad: Unidad3D
## Ticks que entran en 0.3 s, lo que se espera a que termine un golpe (0.25 s).
var _ticks_golpe := ceili(0.3 * Engine.physics_ticks_per_second)


func preparar() -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	# Sin campania: se juega solo este, como en test_encuentro.
	_battle.encuentro = load("res://resources/encuentros/e1_mantener_linea.tres")
	root.add_child(_battle)


func fase(numero: int) -> void:
	match numero:
		0:
			if _ticks < 3:
				return
			_healer = _battle.get_node("%Healer")
			print("--- el reloj del encuentro va con la fisica ---")
			_ok("el encuentro esta en juego", not _battle.esta_terminada())
			var antes: float = _battle.tiempo_encuentro
			_battle._process(1.0)
			_igual("un frame no lo mueve", _battle.tiempo_encuentro - antes, 0.0)
			_battle._physics_process(1.0)
			_igual("un paso de fisica de 1 s lo mueve 1 s", _battle.tiempo_encuentro - antes, 1.0)

			print("--- una oleada por flanco entra una vez por cruce ---")
			_battle.iniciar_encuentro(_encuentro_con_oleada())
			siguiente()
		1:
			if _ticks < 30:
				return
			_ok("el frente sigue del lado que dispara (%.1f)" % _battle.frente_x(),
				_battle.frente_x() <= _oleada.valor)
			_igual("medio segundo cumplida y entro una sola tanda", float(_enemigos()), 2.0)
			# Con la X del otro lado la condicion deja de cumplirse y se rearma.
			_oleada.valor = 10.0
			siguiente()
		2:
			if _ticks < 3:
				return
			_igual("sin la condicion no entra nada", float(_enemigos()), 2.0)
			_oleada.valor = 25.0
			siguiente()
		3:
			if _ticks < 10:
				return
			_igual("al volver a cumplirse entra otra, y una sola", float(_enemigos()), 3.0)
			# Sin repetir no vuelve a entrar aunque la condicion caiga y vuelva.
			_oleada.repetir = false
			_oleada.valor = 10.0
			siguiente()
		4:
			if _ticks < 3:
				return
			_oleada.valor = 25.0
			siguiente()
		5:
			if _ticks < 10:
				return
			_igual("sin repetir, lo lanzado no se repite", float(_enemigos()), 3.0)

			print("--- caido no junta mana ---")
			# Sin enemigos: nadie le pega al healer mientras se mide su mana.
			_battle.iniciar_encuentro(_encuentro_solo())
			siguiente()
		6:
			if _ticks < 3:
				return
			_healer.recibir_dano(999.0)
			_ok("el healer quedo en el suelo", not _healer.esta_viva())
			_healer.mana = 10.0
			siguiente()
		7:
			if _ticks < 30:
				return
			_igual("medio segundo en el suelo y el mana no se movio", _healer.mana, 10.0)
			# Se acorta la espera: lo que importa es que al levantarse vuelva.
			_healer._caido_restante = 0.05
			siguiente()
		8:
			if _ticks < 15:
				return
			_ok("se levanto", _healer.esta_viva())
			_ok("y vuelve a juntar mana (%.2f)" % _healer.mana, _healer.mana > 10.0)

			print("--- el golpe se ve en la unidad ---")
			_unidad = _primer_aliado()
			_ok("hay un soldado a quien golpear", _unidad != null)
			_unidad.recibir_dano(5.0)
			siguiente()
		9:
			if _ticks == 1:
				# Ya corrio un tick de fisica de la unidad, que es donde la pisaba.
				_ok("al tick siguiente sigue en hurt", _unidad._sprite.animation == &"hurt")
				return
			if _ticks < _ticks_golpe:
				return
			_ok("a los 0.3 s paso a otra (%s)" % _unidad._sprite.animation,
				_unidad._sprite.animation != &"hurt")
			_ok("y el golpe no la freno: sigue avanzando",
				_unidad.estado == Unidad3D.Estado.AVANZANDO and _unidad.velocity.x > 0.0)

			print("--- el golpe se ve en el healer ---")
			_healer.recibir_dano(5.0)
			_ok("en el suelo reproduce hurt", _healer._sprite.animation == &"hurt")
			siguiente()
		10:
			if _ticks == 1:
				_ok("y quieto no lo pisa idle", _healer._sprite.animation == &"hurt")
				return
			if _ticks < _ticks_golpe:
				return
			_ok("a los 0.3 s vuelve a otra (%s)" % _healer._sprite.animation,
				_healer._sprite.animation != &"hurt")
			_healer.saltar()
			siguiente()
		11:
			if _ticks < 3:
				return
			_ok("salto", _healer.esta_en_el_aire())
			_healer.recibir_dano(5.0)
			_ok("en el aire el golpe no pisa el salto", _healer._sprite.animation == &"jump")
			siguiente()
		12:
			if _ticks < 2:
				return
			_ok("ni en los ticks que siguen", _healer._sprite.animation == &"jump")
			terminar()


## Un escudero y un zombi a dos metros: el frente queda en x 21, ya del lado
## que dispara la oleada. Mirando solo si la condicion se cumple, entraria un
## zombi por tick.
func _encuentro_con_oleada() -> Encuentro:
	var enc := Encuentro.new()
	enc.id = &"prueba_relojes"
	enc.semilla = 4321
	enc.sangrado_habilitado = false
	# Lejos del choque, para que ningun zombi lo elija de objetivo.
	enc.healer_inicial = Vector2(5.0, 5.0)
	var iniciales: Array[GrupoUnidades] = [
		_grupo(ESCUDERO, Unidad3D.Bando.ALIADO, 20.0),
		_grupo(ZOMBIE, Unidad3D.Bando.ENEMIGO, 22.0),
	]
	enc.grupos_iniciales = iniciales

	_oleada = OleadaEncuentro.new()
	_oleada.disparador = OleadaEncuentro.Disparador.FRENTE_PASA_X
	_oleada.valor = 25.0
	_oleada.repetir = true
	var refuerzo: Array[GrupoUnidades] = [_grupo(ZOMBIE, Unidad3D.Bando.ENEMIGO, 27.0)]
	_oleada.grupos = refuerzo
	var oleadas: Array[OleadaEncuentro] = [_oleada]
	enc.oleadas = oleadas
	return enc


## Un solo soldado y ningun enemigo: nada le pega a nadie salvo la prueba.
func _encuentro_solo() -> Encuentro:
	var enc := Encuentro.new()
	enc.id = &"prueba_golpe"
	enc.semilla = 4322
	enc.sangrado_habilitado = false
	enc.healer_inicial = Vector2(5.0, 5.0)
	var iniciales: Array[GrupoUnidades] = [_grupo(ESCUDERO, Unidad3D.Bando.ALIADO, 10.0)]
	enc.grupos_iniciales = iniciales
	return enc


func _grupo(ruta_tipo: String, bando: Unidad3D.Bando, x: float) -> GrupoUnidades:
	var g := GrupoUnidades.new()
	g.tipo = load(ruta_tipo)
	g.bando = bando
	g.cantidad = 1
	g.x_min = x
	g.x_max = x
	g.z_min = 5.0
	g.z_max = 5.0
	return g


func _enemigos() -> int:
	var total := 0
	for u in get_nodes_in_group("enemigos"):
		if u.esta_viva() and not u.is_queued_for_deletion():
			total += 1
	return total


func _primer_aliado() -> Unidad3D:
	for u in get_nodes_in_group("aliados"):
		if u.esta_viva() and not u.is_queued_for_deletion():
			return u
	return null
