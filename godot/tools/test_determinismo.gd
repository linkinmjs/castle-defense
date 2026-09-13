extends SceneTree
## Azar propio de cada unidad.
##
## Que un soldado sangre o no sale de su semilla y no del generador global. Sin
## eso, un golpe de diferencia en cualquier otro punto del campo cambiaria quien
## sangra, y dos intentos del mismo encuentro dejarian de ser comparables.
##
## La repetibilidad del despliegue completo la cubre test_encuentro.

var _fallos := 0


func _initialize() -> void:
	print("--- la semilla decide la secuencia de sangrados ---")
	var a := _sangrados_con_semilla(7)
	var repetido := _sangrados_con_semilla(7)
	_ok("misma semilla, misma secuencia", a == repetido)

	var distinto := _sangrados_con_semilla(8)
	_ok("otra semilla, otra secuencia", a != distinto)

	# Con probabilidad 0.5 y 40 golpes, que salgan todos iguales seria senal de
	# que el azar no esta corriendo.
	_ok("la secuencia no es constante", a.has(true) and a.has(false))
	_ok("y esta cerca de la mitad (%d de 40)" % _cuantos(a),
		_cuantos(a) > 8 and _cuantos(a) < 32)

	print("--- sin sembrar, cada unidad arranca distinta ---")
	var libre_a := _sangrados_sin_sembrar()
	var libre_b := _sangrados_sin_sembrar()
	_ok("dos unidades sin sembrar no coinciden", libre_a != libre_b)

	print("")
	print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Golpea a una unidad muchas veces y anota si cada golpe le provoco sangrado.
## La vida se pone altisima para que no caiga a mitad de la tanda.
func _golpear(unidad: Unidad3D) -> Array[bool]:
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


func _sangrados_con_semilla(semilla: int) -> Array[bool]:
	var unidad := _crear()
	unidad.sembrar(semilla)
	return _golpear(unidad)


func _sangrados_sin_sembrar() -> Array[bool]:
	return _golpear(_crear())


func _crear() -> Unidad3D:
	var unidad: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	unidad.configurar(Unidad3D.Bando.ALIADO)
	return unidad


func _cuantos(salidas: Array[bool]) -> int:
	var total := 0
	for s in salidas:
		if s:
			total += 1
	return total


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])
