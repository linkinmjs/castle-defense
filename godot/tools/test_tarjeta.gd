extends SceneTree
## Lo que la tarjeta le dice al jugador sobre el soldado que esta apuntando.
##
## Cada habilidad calcula su propia previsualizacion: la tarjeta solo las
## ordena. Muestra la consecuencia de cada herramienta, nunca cual conviene.

var _contenedor: Node3D
var _healer: Healer3D
var _componente: ComponenteHabilidades
var _fallos := 0


func _initialize() -> void:
	_contenedor = Node3D.new()
	root.add_child(_contenedor)

	var camara := Camera3D.new()
	camara.fov = 42.0
	_contenedor.add_child(camara)
	camara.look_at_from_position(Vector3(15, 3, 16), Vector3(15, 1, 5), Vector3.UP)
	camara.make_current()

	_healer = load("res://scenes/3d/healer3d.tscn").instantiate()
	_healer.position = Vector3(15, 0, 5)
	_contenedor.add_child(_healer)
	_healer.usar_camara(camara)
	_componente = _healer.get_node("Habilidades")


func _process(_delta: float) -> bool:
	var curar := _componente.habilidad_por_nombre("Curar")
	var estabilizar := _componente.habilidad_por_nombre("Estabilizar")
	var reanimar := _componente.habilidad_por_nombre("Reanimar")
	var bendicion := _componente.habilidad_por_nombre("Bendicion")

	print("--- curar dice cuanto entra y cuanto se pierde ---")
	var u := _crear()
	u.probabilidad_sangrado = 0.0
	u.vida = u.vida_maxima - 10.0
	var texto := curar.previsualizar(_healer, u)
	_contiene("avisa el desperdicio", texto, "se desperdician")
	_contiene("y cuanto entra de verdad", texto, "+10 HP")

	u.vida = u.vida_maxima * 0.3
	texto = curar.previsualizar(_healer, u)
	_ok("sobre un herido no habla de desperdicio",
		not texto.contains("desperdician"))

	print("--- estabilizar solo aparece si hay algo que cortar ---")
	_igual("sin sangrado no dice nada", estabilizar.previsualizar(_healer, u), "")
	u.aplicar_sangrado(5.0)
	_contiene("sangrando, dice que corta la causa",
		estabilizar.previsualizar(_healer, u), "corta el sangrado")

	print("--- reanimar es al reves: solo sobre un derribado ---")
	_igual("en pie no dice nada", reanimar.previsualizar(_healer, u), "")
	u.recibir_dano(500.0)
	_ok("derribado, dice con cuanta vida lo levanta",
		reanimar.previsualizar(_healer, u).contains("HP"))
	_igual("y curar deja de ofrecerse", curar.previsualizar(_healer, u), "")
	_igual("estabilizar tampoco", estabilizar.previsualizar(_healer, u), "")
	u.free()

	print("--- bendicion avisa si ya la tiene ---")
	var b := _crear()
	b.probabilidad_sangrado = 0.0
	_contiene("dice cuanto dano evita", bendicion.previsualizar(_healer, b), "dano")
	b.bendecir(8.0, 0.35, 0.3)
	_contiene("y avisa si ya esta bendecido",
		bendicion.previsualizar(_healer, b), "ya la tiene")
	b.free()

	print("--- la tarjeta solo lista lo que esta equipado ---")
	var tarjeta = load("res://scripts/tarjeta_objetivo.gd").new()
	_contenedor.add_child(tarjeta)

	var paciente := _crear()
	paciente.probabilidad_sangrado = 0.0
	paciente.nombre_unidad = "Mara"
	paciente.vida = paciente.vida_maxima * 0.5
	paciente.aplicar_sangrado(5.2)
	_healer._apuntada = paciente

	_componente.equipar([curar] as Array[Habilidad])
	tarjeta.seguir(_healer, _componente)
	tarjeta._apuntada = paciente
	var lineas := _textos(tarjeta._armar_lineas())
	_contiene("pone el nombre y el rol", lineas, "Mara")
	_contiene("la vida", lineas, "HP")
	_contiene("y el problema con su reloj", lineas, "Sangrado")
	_contiene("ofrece Curar", lineas, "Curar")
	_ok("y no menciona Estabilizar, que no esta equipada",
		not lineas.contains("Estabilizar"))

	_componente.equipar([curar, estabilizar] as Array[Habilidad])
	lineas = _textos(tarjeta._armar_lineas())
	_contiene("con Estabilizar equipada, si aparece", lineas, "Estabilizar")

	print("--- fuera de alcance se avisa, pero se sigue mostrando ---")
	paciente.global_position = Vector3(15, 0, 5)
	lineas = _textos(tarjeta._armar_lineas())
	_ok("cerca no dice nada de alcance", not lineas.contains("Fuera de alcance"))
	paciente.global_position = Vector3(28, 0, 5)
	lineas = _textos(tarjeta._armar_lineas())
	_contiene("lejos lo avisa", lineas, "Fuera de alcance")
	_contiene("pero igual dice que haria Curar", lineas, "Curar")

	print("")
	print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
	quit(1 if _fallos > 0 else 0)
	return true


func _crear() -> Unidad3D:
	var u: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	u.configurar(Unidad3D.Bando.ALIADO, load("res://resources/soldados/lancero.tres"))
	u.sembrar(1)
	u.position = Vector3(15.8, 0, 5)
	_contenedor.add_child(u)
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
