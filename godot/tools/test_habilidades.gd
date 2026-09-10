extends SceneTree
## Prueba el apuntado y el sistema de habilidades sin depender del mouse.

var _healer: Healer
var _contenedor: Node2D
var _fallos := 0
var _avisos: Array[String] = []


func _initialize() -> void:
	_contenedor = Node2D.new()
	root.add_child(_contenedor)

	_healer = load("res://scenes/units/healer.tscn").instantiate()
	_healer.position = Vector2(500, 200)
	_contenedor.add_child(_healer)


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

	# Un cuerpo solo: el mouse sobre el torso lo agarra.
	var a := _crear_aliado(Vector2(560, 200))
	var punto_torso := a.global_position + Vector2(0, -70)
	_ok("apunta al cuerpo bajo el mouse", _healer.buscar_bajo_punto(punto_torso) == a)
	_ok("apunta tambien a la cabeza", _healer.buscar_bajo_punto(a.global_position + Vector2(0, -130)) == a)
	_ok("apunta tambien a los pies", _healer.buscar_bajo_punto(a.global_position + Vector2(0, -6)) == a)

	# Dos superpuestos: gana el de adelante, que es el que se dibuja encima.
	var atras := _crear_aliado(Vector2(600, 180))
	var adelante := _crear_aliado(Vector2(600, 250))
	var punto_comun := Vector2(600, 130)
	_ok("entre superpuestos elige al de adelante",
		_healer.buscar_bajo_punto(punto_comun) == adelante)

	atras.free()
	adelante.free()

	# Dos cuerpos solapados donde el de adelante esta fuera de alcance: gana el
	# alcanzable, porque apuntar a alguien que no se puede tocar no sirve.
	_healer.global_position = Vector2(600, 150)
	var cercano := _crear_aliado(Vector2(600, 200))   # a 50 px, alcanzable
	var inalcanzable := _crear_aliado(Vector2(600, 340))  # a 190 px, fuera
	_ok("el de adelante esta fuera de alcance", not _healer.en_rango(inalcanzable))
	_ok("las dos cajas contienen el punto",
		cercano.caja_global().has_point(Vector2(600, 203))
		and inalcanzable.caja_global().has_point(Vector2(600, 203)))
	_ok("prefiere al que esta en alcance",
		_healer.buscar_bajo_punto(Vector2(600, 203)) == cercano)
	cercano.free()
	inalcanzable.free()
	_healer.global_position = Vector2(500, 200)
	var cerca := _healer.buscar_bajo_punto(a.global_position + Vector2(60, -70))
	_ok("el iman engancha lo cercano", cerca == a)
	_ok("lejos no engancha nada",
		_healer.buscar_bajo_punto(a.global_position + Vector2(400, -70)) == null)

	for u in root.get_tree().get_nodes_in_group("aliados"):
		u.queue_free()


func _probar_habilidades(componente: ComponenteHabilidades) -> void:
	print("--- habilidades y enfriamiento ---")

	var objetivo := _crear_aliado(Vector2(560, 200))
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

	componente._process(1.0)  # pasa el enfriamiento de 0.6s
	_ok("tras el enfriamiento vuelve a estar lista",
		componente.fraccion_enfriamiento(curar) == 0.0)

	print("--- oleada (area) ---")
	var b := _crear_aliado(Vector2(520, 210))
	var c := _crear_aliado(Vector2(600, 230))
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
	# 35% menos dano: 20 -> 13
	_igual("la bendicion reduce el dano", objetivo.vida, 67.0)

	_ok("no se puede rebendecir", not componente.intentar(bendicion))

	print("--- impulso (movilidad) ---")
	var impulso := componente.habilidad_en(4)
	_healer.mana = 100.0
	componente.intentar(impulso)
	_ok("el impulso arranca", _healer._impulso_restante > 0.0)
	# move_and_slide() fuera del paso de fisica no mueve de forma confiable,
	# asi que se comprueba la velocidad que el impulso impone.
	_healer._physics_process(0.05)
	_ok("el impulso impone velocidad alta", _healer.velocity.length() > 500.0)
	_healer._impulso_restante = 0.0


func _crear_aliado(pos: Vector2) -> Unidad:
	var u: Unidad = load("res://scenes/units/unidad.tscn").instantiate()
	u.configurar(Unidad.Bando.ALIADO)
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
