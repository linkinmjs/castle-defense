extends SceneTree
## Reglas de curacion y sangrado. Complementa a test_habilidades.gd, que se
## ocupa del apuntado y de los enfriamientos.

var _healer: Healer
var _componente: ComponenteHabilidades
var _aliado: Unidad
var _avisos: Array[String] = []
var _fallos := 0


func _initialize() -> void:
	var contenedor := Node2D.new()
	root.add_child(contenedor)

	_healer = load("res://scenes/units/healer.tscn").instantiate()
	_healer.position = Vector2(400, 200)
	contenedor.add_child(_healer)

	_aliado = load("res://scenes/units/unidad.tscn").instantiate()
	_aliado.configurar(Unidad.Bando.ALIADO)
	_aliado.position = Vector2(460, 200)
	contenedor.add_child(_aliado)


func _process(_delta: float) -> bool:
	_componente = _healer.get_node("Habilidades")
	_componente.habilidad_usada.connect(func(_h: Habilidad, t: String) -> void: _avisos.append(t))
	_componente.habilidad_fallo.connect(func(_h: Habilidad, m: String) -> void: _avisos.append(m))
	_healer._apuntada = _aliado

	var curar := _componente.habilidad_en(0)
	var estabilizar := _componente.habilidad_en(1)

	print("--- overhealing: lo que sobra se pierde ---")
	_preparar(70.0)  # de 80: solo entran 10
	_componente.intentar(curar)
	_igual("tope en vida maxima", _aliado.vida, 80.0)
	_igual("cobra el costo completo igual", _healer.mana, 75.0)
	_ok("avisa el desperdicio", _tiene_aviso("desperdiciado"))

	print("--- estabilizar ---")
	_preparar(40.0)
	_componente.intentar(estabilizar)
	_igual("no cobra si no sangra", _healer.mana, 100.0)
	_ok("avisa que no sangra", _tiene_aviso("No esta sangrando"))

	_preparar(40.0)
	_aliado.sangrado_restante = 8.0
	_componente.intentar(estabilizar)
	_igual("corta el sangrado", _aliado.sangrado_restante, 0.0)
	_igual("cobra 10 de mana", _healer.mana, 90.0)
	_igual("no devuelve vida", _aliado.vida, 40.0)

	print("--- curar no corta el sangrado ---")
	_preparar(30.0)
	_aliado.sangrado_restante = 8.0
	_componente.intentar(curar)
	_ok("sigue sangrando despues de curar", _aliado.esta_sangrando())

	print("--- limites ---")
	_preparar(10.0)
	_healer.mana = 5.0
	_componente.intentar(curar)
	_igual("sin mana no cura", _aliado.vida, 10.0)
	_ok("avisa falta de mana", _tiene_aviso("Sin mana"))

	_preparar(10.0)
	_aliado.global_position = Vector2(400 + 400, 200)
	_componente.intentar(curar)
	_igual("fuera de alcance no cura", _aliado.vida, 10.0)
	_igual("fuera de alcance no gasta", _healer.mana, 100.0)
	_ok("avisa fuera de alcance", _tiene_aviso("Fuera de alcance"))
	_aliado.global_position = Vector2(460, 200)

	print("--- sangrado que mata ---")
	_preparar(6.0)
	_aliado.sangrado_restante = 8.0
	_aliado._actualizar_sangrado(2.0)  # 3.5/s * 2s = 7 de dano
	_ok("el sangrado puede matar", not _aliado.esta_viva())

	print("")
	print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
	return true


## Deja al aliado y al healer en un estado conocido y sin enfriamientos, para
## que cada caso se pueda leer solo.
func _preparar(vida: float) -> void:
	_aliado.estado = Unidad.Estado.AVANZANDO
	_aliado.vida = vida
	_aliado.sangrado_restante = 0.0
	_healer.mana = 100.0
	_componente._restante.clear()
	_avisos.clear()


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
	print("  [%s] %-34s obtenido=%.1f esperado=%.1f" % [
		"OK" if ok else "FALLA", que, obtenido, esperado])
