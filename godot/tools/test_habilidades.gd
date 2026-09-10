extends SceneTree
## Prueba el apuntado y el sistema de habilidades sin depender del mouse.

var _healer: Healer3D
var _camara: Camera3D
var _contenedor: Node3D
var _fallos := 0
var _avisos: Array[String] = []


func _initialize() -> void:
	_contenedor = Node3D.new()
	root.add_child(_contenedor)

	# El apuntado proyecta el mundo a pantalla, asi que hace falta una camara
	# aunque no se dibuje nada.
	_camara = Camera3D.new()
	_camara.fov = 42.0
	_contenedor.add_child(_camara)
	# look_at_from_position sirve aunque el nodo todavia no este en el arbol.
	_camara.look_at_from_position(Vector3(15, 3, 16), Vector3(15, 1, 5), Vector3.UP)
	_camara.make_current()

	_healer = load("res://scenes/3d/healer3d.tscn").instantiate()
	_healer.position = Vector3(15, 0, 5)
	_contenedor.add_child(_healer)
	_healer.usar_camara(_camara)


func _process(_delta: float) -> bool:
	var componente: ComponenteHabilidades = _healer.get_node("Habilidades")
	componente.habilidad_usada.connect(func(_h: Habilidad, t: String) -> void: _avisos.append(t))
	componente.habilidad_fallo.connect(func(_h: Habilidad, m: String) -> void: _avisos.append(m))

	_probar_apuntado()
	_probar_habilidades(componente)

	print("")
	print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
	return true


func _probar_apuntado() -> void:
	print("--- apuntado ---")

	var a := _crear_aliado(Vector3(16.5, 0, 5))
	_ok("apunta al torso", _healer.buscar_bajo_punto(_pantalla(a, 1.15)) == a)
	_ok("apunta a la cabeza", _healer.buscar_bajo_punto(_pantalla(a, 1.9)) == a)
	_ok("apunta a los pies", _healer.buscar_bajo_punto(_pantalla(a, 0.15)) == a)

	# Dos soldados alineados con la camara: el de adelante tapa al de atras y
	# es el que tiene que ganar el click.
	var atras := _crear_aliado(Vector3(14.0, 0, 3.0))
	var adelante := _crear_aliado(Vector3(14.0, 0, 6.5))
	var punto := _pantalla(adelante, 1.15)
	_ok("entre superpuestos elige al de adelante",
		_healer.buscar_bajo_punto(punto) == adelante)
	atras.free()
	adelante.free()

	# El iman: cerca en pantalla pero sin caer sobre el cuerpo.
	var cerca := _healer.buscar_bajo_punto(_pantalla(a, 1.15) + Vector2(28, 0))
	_ok("el iman engancha lo cercano", cerca == a)
	_ok("lejos no engancha nada",
		_healer.buscar_bajo_punto(_pantalla(a, 1.15) + Vector2(400, 0)) == null)

	a.free()


func _probar_habilidades(componente: ComponenteHabilidades) -> void:
	print("--- habilidades y enfriamiento ---")

	var objetivo := _crear_aliado(Vector3(16.0, 0, 5))
	objetivo.vida = 20.0
	_healer._apuntada = objetivo
	_healer.mana = 100.0

	var curar := componente.habilidad_en(0)
	_ok("hay 5 habilidades", componente.habilidades.size() == 5)

	_avisos.clear()
	_ok("curar se usa", componente.intentar(curar))
	_igual("cura 35", objetivo.vida, 55.0)
	_igual("cobra 25", _healer.mana, 75.0)

	_avisos.clear()
	_ok("segundo uso bloqueado por enfriamiento", not componente.intentar(curar))
	_igual("el enfriamiento no cobra mana", _healer.mana, 75.0)
	_ok("avisa el enfriamiento", _tiene_aviso("enfriamiento"))

	componente._process(1.0)
	_ok("tras el enfriamiento vuelve a estar lista",
		componente.fraccion_enfriamiento(curar) == 0.0)

	print("--- oleada (area) ---")
	var b := _crear_aliado(Vector3(14.5, 0, 4.0))
	var c := _crear_aliado(Vector3(16.5, 0, 6.0))
	b.vida = 30.0
	c.vida = 30.0
	objetivo.vida = 30.0
	_healer.mana = 100.0
	var oleada := componente.habilidad_en(2)
	_avisos.clear()
	_ok("oleada se usa", componente.intentar(oleada))
	_igual("cura al primero", b.vida, 48.0)
	_igual("cura al segundo", c.vida, 48.0)
	_igual("cobra 45", _healer.mana, 55.0)

	print("--- bendicion (buff) ---")
	var bendicion := componente.habilidad_en(3)
	_healer.mana = 100.0
	_healer._apuntada = objetivo
	_ok("bendicion se usa", componente.intentar(bendicion))
	_ok("queda bendecido", objetivo.esta_bendecida())

	objetivo.vida = 80.0
	objetivo.probabilidad_sangrado = 0.0
	objetivo.recibir_dano(20.0)
	_igual("la bendicion reduce el dano", objetivo.vida, 67.0)
	_ok("no se puede rebendecir", not componente.intentar(bendicion))

	print("--- impulso (movilidad) ---")
	var impulso := componente.habilidad_en(4)
	_healer.mana = 100.0
	componente.intentar(impulso)
	_ok("el impulso arranca", _healer._impulso_restante > 0.0)
	_healer._physics_process(0.05)
	_ok("el impulso impone velocidad alta", _healer.velocity.length() > 5.0)
	_healer._impulso_restante = 0.0


## Coordenada de pantalla de un punto del cuerpo de la unidad.
func _pantalla(unidad: Node3D, altura: float) -> Vector2:
	return _camara.unproject_position(unidad.global_position + Vector3(0, altura, 0))


func _crear_aliado(pos: Vector3) -> Unidad3D:
	var u: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	u.configurar(Unidad3D.Bando.ALIADO)
	u.position = pos
	_contenedor.add_child(u)
	return u


func _tiene_aviso(fragmento: String) -> bool:
	for a in _avisos:
		if a.to_lower().contains(fragmento.to_lower()):
			return true
	return false


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _igual(que: String, obtenido: float, esperado: float) -> void:
	var ok := absf(obtenido - esperado) < 0.01
	if not ok:
		_fallos += 1
	print("  [%s] %-38s obtenido=%.1f esperado=%.1f" % [
		"OK" if ok else "FALLA", que, obtenido, esperado])
