extends SceneTree
## Las teclas disparan la habilidad que dice cada habilidad, no la que ocupa
## cierta posicion en la lista.
##
## Importa porque los encuentros entregan loadouts parciales: el primero da
## solo Curar. Con el despacho por indice, la tecla 3 de un loadout corto
## terminaba usando cualquier otra cosa.

var _healer: Healer3D
var _camara: Camera3D
var _componente: ComponenteHabilidades
var _contenedor: Node3D
var _aliado: Unidad3D
var _usadas: Array[String] = []
var _completo: Array[Habilidad] = []
var _fallos := 0


func _initialize() -> void:
	_contenedor = Node3D.new()
	root.add_child(_contenedor)

	_camara = Camera3D.new()
	_camara.fov = 42.0
	_contenedor.add_child(_camara)
	_camara.look_at_from_position(Vector3(15, 3, 16), Vector3(15, 1, 5), Vector3.UP)
	_camara.make_current()

	_healer = load("res://scenes/3d/healer3d.tscn").instantiate()
	_healer.position = Vector3(15, 0, 5)
	_contenedor.add_child(_healer)
	_healer.usar_camara(_camara)

	_componente = _healer.get_node("Habilidades")
	_componente.habilidad_usada.connect(
		func(h: Habilidad, _t: String) -> void: _usadas.append(h.nombre))
	_completo = _componente.habilidades.duplicate()

	# Un paciente herido al alcance, para que Curar y Estabilizar no se
	# bloqueen por falta de objetivo.
	_aliado = load("res://scenes/3d/unidad3d.tscn").instantiate()
	_aliado.configurar(Unidad3D.Bando.ALIADO)
	_aliado.position = Vector3(15.8, 0, 5)
	_contenedor.add_child(_aliado)
	_aliado.vida = 20.0
	_healer._apuntada = _aliado


func _process(_delta: float) -> bool:
	print("--- cada habilidad declara su accion ---")
	for habilidad: Habilidad in _completo:
		_ok("%s tiene accion" % habilidad.nombre, habilidad.accion != &"")
	var acciones := {}
	for habilidad: Habilidad in _completo:
		acciones[habilidad.accion] = true
	_ok("ninguna accion esta repetida", acciones.size() == _completo.size())

	# Cada habilidad pide un estado distinto del paciente para no bloquearse,
	# asi que hay que prepararlo antes de mandar la accion.
	print("--- con el loadout completo ---")
	_ok("select usa Curar", _disparar("select") == "Curar")

	_aliado.sangrado_restante = 5.0
	_ok("cancel usa Estabilizar", _disparar("cancel") == "Estabilizar")

	_aliado.probabilidad_sangrado = 0.0
	_aliado.recibir_dano(500.0)
	_ok("el paciente quedo derribado", _aliado.esta_derribada())
	_ok("habilidad_3 usa Reanimar", _disparar("habilidad_3") == "Reanimar")
	_ok("y lo levanto", not _aliado.esta_derribada())

	_ok("dash usa Impulso", _disparar("dash") == "Impulso")

	print("--- con un loadout de una sola habilidad ---")
	_componente.equipar([_buscar("Curar")] as Array[Habilidad])
	_ok("queda una sola equipada", _componente.habilidades.size() == 1)
	_ok("select sigue curando", _disparar("select") == "Curar")
	# Esta es la regresion: con indices fijos, habilidad_3 caia en la posicion
	# 5 de una lista de 1 y disparaba lo que hubiera ahi.
	_ok("habilidad_3 no dispara nada", _disparar("habilidad_3") == "")
	_ok("dash no dispara nada", _disparar("dash") == "")
	_ok("equipar limpia los enfriamientos",
		_componente.enfriamiento_restante(_buscar("Curar")) == 0.0)

	print("--- sumar una habilidad mas tarde ---")
	_componente.equipar([_buscar("Curar"), _buscar("Estabilizar")] as Array[Habilidad])
	_aliado.sangrado_restante = 5.0
	_ok("ahora cancel estabiliza", _disparar("cancel") == "Estabilizar")
	_ok("y habilidad_3 sigue sin hacer nada", _disparar("habilidad_3") == "")

	print("--- buscar por nombre ---")
	_componente.equipar(_completo)
	_ok("encuentra una equipada", _componente.habilidad_por_nombre("Oleada") != null)
	_ok("y devuelve null si no esta", _componente.habilidad_por_nombre("Meteorito") == null)

	print("")
	print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
	quit(1 if _fallos > 0 else 0)
	return true


func _buscar(nombre: String) -> Habilidad:
	for habilidad: Habilidad in _completo:
		if habilidad.nombre == nombre:
			return habilidad
	return null


## Manda la accion como lo haria el jugador y devuelve el nombre de la
## habilidad que se uso, o "" si no se uso ninguna.
func _disparar(accion: StringName) -> String:
	_usadas.clear()
	_healer.mana = _healer.mana_maximo
	_componente._restante.clear()

	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	_healer._unhandled_input(evento)

	return _usadas[0] if not _usadas.is_empty() else ""


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])
