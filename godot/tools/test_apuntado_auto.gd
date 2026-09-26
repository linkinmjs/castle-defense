extends SceneTree
## Apuntado automatico: a quien le llega cada movimiento segun donde esta
## parado el healer y hacia donde mira. No hace falta tiempo: todo se mide en
## un solo tick, con las unidades quietas.

const ORIGEN := Vector3(15, 0, 5)
const ESPADACHIN := preload("res://resources/soldados/espadachin.tres")
const ZOMBIE := preload("res://resources/soldados/zombie.tres")
const ESCENA_UNIDAD := preload("res://scenes/3d/unidad3d.tscn")

var _contenedor: Node3D
var _healer: Healer3D
var _unidades: Array[Unidad3D] = []
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
	_probar_orientacion()
	_probar_prioridad()
	_probar_derribados_y_ligera()
	_probar_pegajoso()
	_probar_pesada()
	_probar_derribado_al_frente()
	_probar_margen_trasero()
	_probar_costados()
	_probar_alrededor()
	_probar_medidas_propias()

	print("")
	print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _probar_orientacion() -> void:
	print("--- la caja mira hacia donde mira el healer ---")
	_mirar_izquierda(false)
	_igual("mirando al frente la direccion es +1", Apuntado.direccion_frente(_healer), 1.0)
	var caja := Apuntado.caja_ligera(_healer)
	_igual("la caja arranca medio metro detras", caja.position.x, ORIGEN.x - 0.5)
	_igual("y llega 2.4 m adelante", caja.end.x, ORIGEN.x + 2.4)
	_igual("de costado cubre 1.3 m para cada lado", caja.size.y, 2.6)
	_igual("centrada en la profundidad del healer", caja.get_center().y, ORIGEN.z)

	var adelante := _aliado(1.5, 0.0, 0.5)
	var atras := _aliado(-1.5, 0.0, 0.5)
	_ok("la ligera toca al de adelante", Apuntado.objetivo_ligera(_healer) == adelante)

	# Es lo que lee mirando_izquierda(): el flip del sprite.
	_mirar_izquierda(true)
	_igual("mirando a la base la direccion es -1", Apuntado.direccion_frente(_healer), -1.0)
	caja = Apuntado.caja_ligera(_healer)
	_igual("la caja se da vuelta: llega 2.4 m hacia -X", caja.position.x, ORIGEN.x - 2.4)
	_igual("y termina medio metro detras", caja.end.x, ORIGEN.x + 0.5)
	_ok("ahora toca al que estaba atras", Apuntado.objetivo_ligera(_healer) == atras)
	_igual("la pesada tambien se da vuelta",
		Apuntado.caja_pesada(_healer).position.x, ORIGEN.x - 3.2)
	_limpiar()


func _probar_prioridad() -> void:
	print("--- prioridad de la ligera ---")
	var golpeado := _aliado(1.0, 0.0, 0.5)
	var sangrando := _aliado(2.0, 0.4, 0.9)
	sangrando.sangrado_restante = 5.0
	_ok("el que sangra va primero aunque tenga mas vida",
		Apuntado.objetivo_ligera(_healer) == sangrando)

	sangrando.sangrado_restante = 0.0
	_ok("sin sangrado, el de menor fraccion de vida",
		Apuntado.objetivo_ligera(_healer) == golpeado)

	var cercano := _aliado(0.4, -0.3, 0.5)
	_ok("a igual fraccion, el mas cercano", Apuntado.objetivo_ligera(_healer) == cercano)

	var borrandose := _aliado(0.2, 0.0, 0.1)
	borrandose.queue_free()
	_ok("uno en cola de borrado ya no cuenta", Apuntado.objetivo_ligera(_healer) == cercano)
	_limpiar()


func _probar_derribados_y_ligera() -> void:
	print("--- la ligera nunca toca a un derribado ---")
	var tirado := _aliado(0.8, 0.0)
	tirado.derribar()
	_ok("con solo un derribado al frente no hay objetivo",
		Apuntado.objetivo_ligera(_healer) == null)

	var sano := _aliado(2.0, 0.0)
	_ok("toca al sano antes que al derribado", Apuntado.objetivo_ligera(_healer) == sano)

	var caja := Apuntado.caja_ligera(_healer)
	_ok("aliados_en_caja lo cuenta si se piden derribados",
		Apuntado.aliados_en_caja(_healer, caja, true).has(tirado))
	_ok("y no si no se piden", not Apuntado.aliados_en_caja(_healer, caja).has(tirado))
	_limpiar()


func _probar_pegajoso() -> void:
	print("--- el preferido es pegajoso ---")
	var paciente := _aliado(2.0, 0.0, 0.8)
	var peor := _aliado(1.0, 0.3, 0.3)
	_ok("sin preferido gana el mas golpeado", Apuntado.objetivo_ligera(_healer) == peor)
	_ok("con preferido sigue sobre el mismo",
		Apuntado.objetivo_ligera(_healer, paciente) == paciente)

	peor.sangrado_restante = 4.0
	_ok("aunque al otro le empiece a sangrar",
		Apuntado.objetivo_ligera(_healer, paciente) == paciente)

	paciente.vida = paciente.vida_maxima
	_ok("con la vida llena deja de ser pegajoso",
		Apuntado.objetivo_ligera(_healer, paciente) == peor)

	paciente.vida = paciente.vida_maxima * 0.8
	paciente.global_position = ORIGEN + Vector3(2.8, 0.0, 0.0)
	_ok("fuera de la caja deja de ser pegajoso",
		Apuntado.objetivo_ligera(_healer, paciente) == peor)

	paciente.global_position = ORIGEN + Vector3(2.0, 0.0, 0.0)
	paciente.derribar()
	_ok("derribado deja de ser pegajoso",
		Apuntado.objetivo_ligera(_healer, paciente) == peor)
	_limpiar()


func _probar_pesada() -> void:
	print("--- la pesada agrupa la caja grande ---")
	var cerca := _aliado(1.0, 0.0, 0.5)
	var lejos := _aliado(3.0, 0.0, 0.5)          # la ligera no llega por largo
	var costado := _aliado(1.5, 1.8, 0.5)        # ni por costado
	var tirado := _aliado(2.0, -1.0)
	tirado.derribar()
	var pasado := _aliado(3.5, 0.0, 0.5)         # mas alla de 3.2 m
	var muy_al_costado := _aliado(1.5, 2.2, 0.5)  # a mas de 2 m de costado

	var alcanzados := Apuntado.objetivos_pesada(_healer)
	_igual("alcanza a los tres de la caja grande", alcanzados.size(), 3)
	_ok("incluye al que la ligera no alcanza por largo", alcanzados.has(lejos))
	_ok("y al que no alcanza por costado", alcanzados.has(costado))
	_ok("excluye al derribado", not alcanzados.has(tirado))
	_ok("y a los que quedan fuera de la caja",
		not alcanzados.has(pasado) and not alcanzados.has(muy_al_costado))
	_ok("la ligera sigue tocando solo al de su caja", Apuntado.objetivo_ligera(_healer) == cerca)
	_limpiar()


func _probar_derribado_al_frente() -> void:
	print("--- el derribado al frente ---")
	_ok("sin nadie en el suelo no hay", Apuntado.derribado_al_frente(_healer) == null)

	var lejano := _aliado(2.6, 0.5)
	var cercano := _aliado(1.2, -0.4)
	# Mas cerca que los otros dos, pero un metro detras: fuera de la caja.
	var detras := _aliado(-1.0, 0.0)
	var pasado := _aliado(3.6, 0.0)
	for unidad in [lejano, cercano, detras, pasado]:
		unidad.derribar()

	_ok("elige al derribado mas cercano de la caja",
		Apuntado.derribado_al_frente(_healer) == cercano)
	cercano.reanimar()
	_ok("si ese se levanta, pasa al siguiente",
		Apuntado.derribado_al_frente(_healer) == lejano)
	lejano.reanimar()
	_ok("el de atras y el de mas alla no cuentan",
		Apuntado.derribado_al_frente(_healer) == null)
	_limpiar()


func _probar_margen_trasero() -> void:
	print("--- margen trasero ---")
	var encima := _aliado(-0.3, 0.0, 0.5)
	_ok("un aliado 0.3 m detras entra", Apuntado.objetivo_ligera(_healer) == encima)
	encima.global_position = ORIGEN + Vector3(-0.8, 0.0, 0.0)
	_ok("uno 0.8 m detras no", Apuntado.objetivo_ligera(_healer) == null)
	_limpiar()


func _probar_costados() -> void:
	print("--- los costados ---")
	var aliado := _aliado(1.0, 1.2, 0.5)
	_ok("a 1.2 m de costado entra", Apuntado.objetivo_ligera(_healer) == aliado)
	aliado.global_position = ORIGEN + Vector3(1.0, 0.0, 1.4)
	_ok("a 1.4 m de costado no", Apuntado.objetivo_ligera(_healer) == null)
	aliado.global_position = ORIGEN + Vector3(1.0, 0.0, -1.4)
	_ok("tampoco del otro lado", Apuntado.objetivo_ligera(_healer) == null)

	# Pegado al healer y mas golpeado, pero fuera de la caja: pierde contra uno
	# de adentro que esta mas lejos y casi sano. Pararse bien es la habilidad.
	aliado.global_position = ORIGEN + Vector3(0.0, 0.0, 1.45)
	var adentro := _aliado(2.2, 0.0, 0.9)
	_ok("pegado de costado no le gana a uno de adentro",
		Apuntado.objetivo_ligera(_healer) == adentro)
	_limpiar()


func _probar_alrededor() -> void:
	print("--- alrededor del healer ---")
	var atras := _aliado(-3.5, 0.0, 0.5)
	var costado := _aliado(0.0, 3.0, 0.5)
	var lejos := _aliado(4.5, 0.0, 0.5)
	var tirado := _aliado(1.0, 0.0)
	tirado.derribar()
	var cerca := Apuntado.aliados_alrededor(_healer, 4.0)
	_ok("alcanza en cualquier direccion", cerca.has(atras) and cerca.has(costado))
	_ok("no mas alla del radio", not cerca.has(lejos))
	_ok("y sin derribados", not cerca.has(tirado))

	# En pleno salto el alcance se mide sobre el suelo.
	_healer.global_position.y = 1.0
	_ok("en el aire alcanza a los mismos",
		Apuntado.aliados_alrededor(_healer, 4.0).size() == cerca.size())
	_healer.global_position.y = 0.0

	var aliado_pegado := _aliado(0.5, 0.0, 0.5)
	var zombi := _enemigo(1.5, 0.0)
	var zombi_lejos := _enemigo(2.5, 0.0)
	var zombi_tirado := _enemigo(-1.0, 0.0)
	zombi_tirado.derribar()
	var enemigos := Apuntado.enemigos_alrededor(_healer, 2.0)
	_ok("enemigos: el que esta a 1.5 m", enemigos.has(zombi))
	_ok("no el que esta a 2.5 m", not enemigos.has(zombi_lejos))
	_ok("ni el derribado", not enemigos.has(zombi_tirado))
	_ok("ni aliados", not enemigos.has(aliado_pegado))
	_limpiar()


func _probar_medidas_propias() -> void:
	print("--- el healer puede traer sus propias medidas ---")
	var guion := GDScript.new()
	guion.source_code = "\n".join([
		"extends Node3D",
		"var alcance_frontal := 1.0",
		"var alcance_lateral := 0.5",
		"var margen_trasero := 0.2",
		"var alcance_pesada := Vector2(2.0, 1.0)",
		"func mirando_izquierda() -> bool:",
		"\treturn false",
	])
	guion.reload()
	var propio := Node3D.new()
	propio.set_script(guion)
	_contenedor.add_child(propio)
	propio.global_position = ORIGEN

	var caja := Apuntado.caja_ligera(propio)
	_igual("usa su alcance frontal", caja.end.x, ORIGEN.x + 1.0)
	_igual("su margen trasero", caja.position.x, ORIGEN.x - 0.2)
	_igual("y su alcance lateral", caja.size.y, 1.0)
	_igual("la pesada usa su caja", Apuntado.caja_pesada(propio).end.x, ORIGEN.x + 2.0)

	var sin_medidas := Node3D.new()
	_contenedor.add_child(sin_medidas)
	sin_medidas.global_position = ORIGEN
	_igual("sin medidas propias usa las constantes",
		Apuntado.caja_ligera(sin_medidas).end.x, ORIGEN.x + Apuntado.ALCANCE_FRONTAL)
	propio.free()
	sin_medidas.free()


# --- Ayudantes ----------------------------------------------------------------

## Aliado quieto en ORIGEN + (dx, 0, dz), con esa fraccion de vida.
func _aliado(dx: float, dz: float, fraccion: float = 1.0) -> Unidad3D:
	var unidad := _unidad(Unidad3D.Bando.ALIADO, ESPADACHIN, dx, dz)
	unidad.vida = unidad.vida_maxima * fraccion
	return unidad


func _enemigo(dx: float, dz: float) -> Unidad3D:
	return _unidad(Unidad3D.Bando.ENEMIGO, ZOMBIE, dx, dz)


func _unidad(bando: Unidad3D.Bando, tipo: TipoSoldado, dx: float, dz: float) -> Unidad3D:
	var unidad: Unidad3D = ESCENA_UNIDAD.instantiate()
	unidad.configurar(bando, tipo)
	unidad.position = ORIGEN + Vector3(dx, 0.0, dz)
	_contenedor.add_child(unidad)
	# Quietas: la prueba mide la geometria, no el combate.
	unidad.set_physics_process(false)
	_unidades.append(unidad)
	return unidad


func _mirar_izquierda(izquierda: bool) -> void:
	_healer._sprite.flip_h = izquierda


func _limpiar() -> void:
	for unidad in _unidades:
		if is_instance_valid(unidad):
			unidad.free()
	_unidades.clear()
	_mirar_izquierda(false)


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _igual(que: String, obtenido: float, esperado: float) -> void:
	var ok := absf(obtenido - esperado) < 0.01
	if not ok:
		_fallos += 1
	print("  [%s] %-46s obtenido=%.2f esperado=%.2f" % [
		"OK" if ok else "FALLA", que, obtenido, esperado])
