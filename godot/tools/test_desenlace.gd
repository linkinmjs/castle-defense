extends SceneTree
## Frente y desenlace de la batalla, sobre la escena real.

var _battle: Node
var _resultado: Variant = null
var _fallos := 0
var _fase := 0
var _ticks := 0


func _initialize() -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	root.add_child(_battle)
	_battle.batalla_terminada.connect(func(v: bool) -> void: _resultado = v)
	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	match _fase:
		0:
			if _ticks < 3:
				return
			print("--- frente ---")
			_ok("arranca sin terminar", not _battle._terminada)
			var frente: float = _battle.frente_x()
			_ok("el frente arranca cerca del centro (%.1f)" % frente, absf(frente - 15.0) < 4.0)

			# Un aliado tirado al lado de la base enemiga no cuenta.
			var aliados := get_nodes_in_group("aliados")
			var tirado: Unidad3D = aliados[0]
			tirado.probabilidad_sangrado = 0.0
			tirado.global_position.x = _battle.base_enemiga_x - 0.5
			tirado.recibir_dano(500.0)
			_ticks = 0
			_fase = 1
		1:
			if _ticks < 3:
				return
			_ok("un derribado en la base enemiga no gana", not _battle._terminada)

			print("--- victoria ---")
			var aliados := get_nodes_in_group("aliados")
			var vivo: Unidad3D = null
			for u in aliados:
				if u.esta_viva() and not u.esta_derribada():
					vivo = u
					break
			vivo.global_position.x = _battle.base_enemiga_x - 0.5
			_ticks = 0
			_fase = 2
		2:
			if _ticks < 4:
				return
			_ok("llegar a la base enemiga termina la batalla", _battle._terminada)
			_ok("y es victoria", _resultado == true)
			_ok("los relojes se detienen", _battle._relojes.all(func(r: Timer) -> bool: return r.is_stopped()))
			_fase = 3
		3:
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit(1 if _fallos > 0 else 0)
			_fase = 4

	if _ticks > 600:
		print("FALLA: el test no termino")
		quit(1)


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])
