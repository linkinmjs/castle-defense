extends SceneTree
## Repetibilidad del despliegue: la misma semilla tiene que armar la misma
## batalla.
##
## Es lo que permite comparar dos intentos y saber que lo que cambio fue la
## conducta del jugador y no el reparto de tropas. No es un replay exacto: el
## delta de cada frame varia, asi que se compara el despliegue inicial, no el
## desarrollo del combate.

var _fallos := 0
var _fase := 0
var _ticks := 0
var _huella_a: Array[String] = []
var _huella_b: Array[String] = []
var _sangrados_a: Array[bool] = []


func _initialize() -> void:
	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	match _fase:
		0:
			if _ticks < 2:
				return
			print("--- misma semilla, mismo despliegue ---")
			_huella_a = _desplegar(1234)
			_ok("la batalla despliega unidades", _huella_a.size() > 0)
			_ticks = 0
			_fase = 1
		1:
			if _ticks < 2:
				return
			_huella_b = _desplegar(1234)
			_ok("con la misma semilla sale la misma formacion", _huella_a == _huella_b)
			if _huella_a != _huella_b:
				print("     a: %s" % ", ".join(_huella_a.slice(0, 3)))
				print("     b: %s" % ", ".join(_huella_b.slice(0, 3)))
			_ticks = 0
			_fase = 2
		2:
			if _ticks < 2:
				return
			print("--- otra semilla, otra formacion ---")
			var otra := _desplegar(99)
			_ok("con otra semilla cambia", _huella_a != otra)
			_ok("pero despliega la misma cantidad", _huella_a.size() == otra.size())
			_ticks = 0
			_fase = 3
		3:
			if _ticks < 2:
				return
			print("--- semilla 0: se sortea y queda guardada ---")
			var battle := _crear_batalla(0)
			var sorteada: int = battle.semilla_actual
			_ok("sortea una semilla distinta de cero", sorteada != 0)
			battle.free()
			_ticks = 0
			_fase = 4
		4:
			if _ticks < 2:
				return
			print("--- el sangrado de una unidad sigue su propia semilla ---")
			_sangrados_a = _sangrar_con_semilla(7)
			var repetido := _sangrar_con_semilla(7)
			_ok("misma semilla, misma secuencia de sangrados", _sangrados_a == repetido)
			var distinto := _sangrar_con_semilla(8)
			_ok("otra semilla, otra secuencia", _sangrados_a != distinto)
			# Con probabilidad 0.5 y 40 golpes, que salgan todos iguales seria
			# senal de que el azar no esta corriendo.
			_ok("la secuencia no es constante", _sangrados_a.has(true) and _sangrados_a.has(false))
			_fase = 5
		5:
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit(1 if _fallos > 0 else 0)
			_fase = 6

	if _ticks > 600:
		print("FALLA: el test no termino")
		quit(1)


func _crear_batalla(semilla: int) -> Node:
	var battle: Node = load("res://scenes/3d/battle3d.tscn").instantiate()
	battle.semilla = semilla
	root.add_child(battle)
	return battle


## Bando, tipo y posicion de cada unidad desplegada, redondeada para que no
## dependa de la precision de punto flotante.
func _desplegar(semilla: int) -> Array[String]:
	var battle := _crear_batalla(semilla)
	var huella: Array[String] = []
	# El healer tambien cuelga de %Unidades, y no es parte del despliegue.
	for unidad in battle.get_node("%Unidades").get_children():
		if not unidad is Unidad3D:
			continue
		var tipo: String = unidad.tipo.nombre if unidad.tipo != null else "-"
		huella.append("%d/%s/%.2f/%.2f" % [
			unidad.bando, tipo, unidad.position.x, unidad.position.z])
	battle.free()
	return huella


## Golpea a una unidad sembrada y anota si cada golpe le provoco sangrado.
func _sangrar_con_semilla(semilla: int) -> Array[bool]:
	var unidad: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	unidad.configurar(Unidad3D.Bando.ALIADO)
	unidad.sembrar(semilla)
	root.add_child(unidad)
	unidad.probabilidad_sangrado = 0.5
	unidad.vida_maxima = 100000.0
	unidad.vida = 100000.0

	var salidas: Array[bool] = []
	for i in 40:
		unidad.sangrado_restante = 0.0
		unidad.recibir_dano(1.0)
		salidas.append(unidad.esta_sangrando())
	unidad.free()
	return salidas


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])
