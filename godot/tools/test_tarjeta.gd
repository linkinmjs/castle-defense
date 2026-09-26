extends SceneTree
## Lo que la tarjeta le dice al jugador sobre el soldado que tiene al frente.
##
## Cada movimiento calcula su propia previsualizacion: la tarjeta solo las
## ordena, y solo las de lo que esta equipado. Muestra la consecuencia de cada
## uno, nunca cual conviene.

const ORIGEN := Vector3(15, 0, 5)

var _contenedor: Node3D
var _healer: Healer3D
var _combos: ComponenteCombos
var _fallos := 0
var _ticks := 0


func _initialize() -> void:
	_contenedor = Node3D.new()
	root.add_child(_contenedor)
	_healer = load("res://scenes/3d/healer3d.tscn").instantiate()
	_healer.position = ORIGEN
	_contenedor.add_child(_healer)
	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	if _ticks != 2:
		return
	_combos = _healer.get_node("Combos")
	var toque := _combos.movimiento_por_nombre("Toque")
	var vendaje := _combos.movimiento_por_nombre("Vendaje")
	var reanimar := _combos.movimiento_por_nombre("Reanimar")
	var bendicion := _combos.movimiento_por_nombre("Bendicion")

	print("--- Toque dice cuanto entra y cuanto se pierde ---")
	var u := _crear()
	u.vida = u.vida_maxima - 10.0
	var texto := toque.previsualizar(_healer, u)
	_contiene("avisa el desperdicio", texto, "se desperdician")
	_contiene("y cuanto entra de verdad", texto, "+10 HP")

	u.vida = u.vida_maxima * 0.3
	texto = toque.previsualizar(_healer, u)
	_ok("sobre un herido no habla de desperdicio", not texto.contains("desperdician"))

	print("--- Vendaje habla del sangrado solo si hay algo que cortar ---")
	_ok("sin sangrado no promete cortarlo",
		not vendaje.previsualizar(_healer, u).contains("sangrado"))
	u.aplicar_sangrado(5.0)
	_contiene("sangrando, dice que corta la causa",
		vendaje.previsualizar(_healer, u), "corta el sangrado")

	print("--- Reanimar es al reves: solo sobre un derribado ---")
	_igual("en pie no dice nada", reanimar.previsualizar(_healer, u), "")
	u.recibir_dano(500.0)
	_ok("derribado, dice con cuanta vida lo levanta",
		reanimar.previsualizar(_healer, u).contains("HP"))
	_igual("y Toque deja de ofrecerse", toque.previsualizar(_healer, u), "")
	_igual("Vendaje tampoco", vendaje.previsualizar(_healer, u), "")
	u.free()

	print("--- Bendicion avisa si ya la tiene ---")
	var b := _crear()
	_contiene("dice cuanto dano evita", bendicion.previsualizar(_healer, b), "dano")
	b.bendecir(8.0, 0.35, 0.3)
	_contiene("y avisa si ya esta bendecido", bendicion.previsualizar(_healer, b), "ya la tiene")
	b.free()

	print("--- la tarjeta solo lista lo que esta equipado ---")
	var tarjeta = load("res://scripts/tarjeta_objetivo.gd").new()
	_contenedor.add_child(tarjeta)

	var paciente := _crear()
	paciente.nombre_unidad = "Mara"
	paciente.vida = paciente.vida_maxima * 0.5
	paciente.aplicar_sangrado(5.2)

	_combos.equipar([toque] as Array[Movimiento])
	tarjeta.seguir(_healer, _combos)
	tarjeta._apuntada = paciente
	var lineas := _textos(tarjeta._armar_lineas())
	_contiene("pone el nombre y el rol", lineas, "Mara · Lancero")
	_contiene("la vida", lineas, "HP")
	_contiene("y el problema con su reloj", lineas, "Sangrado")
	_contiene("ofrece Toque", lineas, "Toque: +18 HP")
	_ok("y no menciona Vendaje, que no esta equipado", not lineas.contains("Vendaje"))
	_ok("ni habla de alcance: si esta en la ficha, esta al frente",
		not lineas.contains("alcance"))

	_combos.equipar([toque, vendaje] as Array[Movimiento])
	lineas = _textos(tarjeta._armar_lineas())
	_contiene("con Vendaje equipado, aparece", lineas, "Vendaje: corta el sangrado")

	_combos.equipar([toque, vendaje, reanimar] as Array[Movimiento])
	lineas = _textos(tarjeta._armar_lineas())
	_ok("lo que no le haria nada no ocupa un renglon", not lineas.contains("Reanimar"))

	print("--- la ficha es la del que recibiria la ligera ---")
	# A 0.8 m al frente del healer, que mira hacia +X: esta en la caja. El
	# healer lo marca en su tick, y la tarjeta lo toma de ahi.
	await physics_frame
	await physics_frame
	_ok("el healer lo tiene al frente", _healer.unidad_apuntada() == paciente)
	tarjeta._process(0.0)
	_ok("y la tarjeta se muestra", tarjeta.visible)
	paciente.global_position = ORIGEN + Vector3(6.0, 0, 0)
	await physics_frame
	await physics_frame
	_ok("fuera de la caja ya no es el de la ficha", _healer.unidad_apuntada() == null)
	tarjeta._process(0.0)
	_ok("y la tarjeta se oculta", not tarjeta.visible)

	print("")
	print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Lancero sin azar ni fisica, a 0.8 m al frente del healer.
func _crear() -> Unidad3D:
	var u: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	u.configurar(Unidad3D.Bando.ALIADO, load("res://resources/soldados/lancero.tres"))
	u.sembrar(1)
	u.position = ORIGEN + Vector3(0.8, 0, 0)
	_contenedor.add_child(u)
	u.set_physics_process(false)
	u.probabilidad_sangrado = 0.0
	return u


func _textos(lineas: Array[Dictionary]) -> String:
	var partes: Array[String] = []
	for linea in lineas:
		partes.append(linea["texto"])
	return "\n".join(partes)


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _contiene(que: String, texto: String, fragmento: String) -> void:
	_ok("%s (%s)" % [que, fragmento], texto.contains(fragmento))


func _igual(que: String, obtenido: String, esperado: String) -> void:
	_ok("%s [%s]" % [que, obtenido], obtenido == esperado)
