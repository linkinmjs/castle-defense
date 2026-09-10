extends SceneTree
## Prueba el salto y su interaccion con el impulso sobre ticks de fisica
## reales: move_and_slide() solo mueve el cuerpo dentro del paso de fisica,
## asi que llamar _physics_process a mano no sirve para medir posiciones.

const DT := 1.0 / 60.0

var _healer: Healer3D
var _fallos := 0
var _fase := 0
var _ticks := 0
var _maxima := 0.0
var _vy_guardada := 0.0


func _initialize() -> void:
	var contenedor := Node3D.new()
	root.add_child(contenedor)
	_healer = load("res://scenes/3d/healer3d.tscn").instantiate()
	_healer.position = Vector3(15, 0, 5)
	contenedor.add_child(_healer)
	# Se emite justo antes de que los nodos procesen fisica: lo que se lee aca
	# es el estado con el que termino el tick anterior.
	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	match _fase:
		0:
			print("--- salto ---")
			_ok("arranca en el suelo", not _healer.esta_en_el_aire())
			_healer.saltar()
			_ok("saltar lo pone en el aire", _healer.esta_en_el_aire())
			_ok("sube", _healer.velocity.y > 0.0)
			_ticks = 0
			_maxima = 0.0
			_fase = 1
		1:
			_maxima = maxf(_maxima, _healer.global_position.y)
			if _healer.esta_en_el_aire():
				return
			_ok("vuelve a caer", true)
			_igual("aterriza a ras del suelo", _healer.global_position.y, 0.0)
			# Integracion discreta: el pico queda un poco por debajo del ideal.
			_igual("la altura maxima es la configurada", _maxima, _healer.altura_salto, 0.1)
			var duracion := _ticks * DT
			_ok("el arco dura entre 0.5 y 0.9 s (%.2f)" % duracion, duracion > 0.5 and duracion < 0.9)
			_fase = 2
		2:
			print("--- limites ---")
			_healer.saltar()
			var vy := _healer.velocity.y
			_healer.saltar()  # doble salto: no deberia hacer nada
			_igual("no hay doble salto", _healer.velocity.y, vy)
			_fase = 3
		3:
			if not _healer.esta_en_el_aire():
				_fase = 4
		4:
			print("--- impulso en el aire ---")
			_healer.saltar()
			_ticks = 0
			_fase = 5
		5:
			if _ticks < 6:
				return
			_vy_guardada = _healer.velocity.y
			_healer.impulsar(Vector3.RIGHT, 9.5, 0.22)
			_fase = 6
		6:
			_ok("el impulso empuja en horizontal", _healer.velocity.x > 5.0)
			_igual("el impulso no anula la gravedad",
				_healer.velocity.y, _vy_guardada - _healer.gravedad * DT, 0.05)
			_healer._impulso_restante = 0.0
			_fase = 7
		7:
			if not _healer.esta_en_el_aire():
				_fase = 8
		8:
			print("--- cast en el aire ---")
			_healer.saltar()
			_healer.gastar_mana(10.0)
			_ok("en el aire mantiene la animacion de salto", _healer._sprite.animation == "jump")
			_fase = 9
		9:
			if not _healer.esta_en_el_aire():
				_healer.gastar_mana(10.0)
				_ok("en el suelo el cast si se ve", _healer._sprite.animation == "cast")
				_fase = 10
		10:
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit()
			_fase = 11

	if _ticks > 2000:
		print("FALLA: el test no termino")
		quit()


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _igual(que: String, obtenido: float, esperado: float, tolerancia: float = 0.01) -> void:
	var ok := absf(obtenido - esperado) < tolerancia
	if not ok:
		_fallos += 1
	print("  [%s] %-38s obtenido=%.2f esperado=%.2f" % [
		"OK" if ok else "FALLA", que, obtenido, esperado])
