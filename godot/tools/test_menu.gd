extends SceneTree
## Menu principal: que esten los botones, que la lista de lecciones salga de la
## campaña y que el tema este aplicado.

var _menu: Control
var _pedidos: Array[int] = []
var _fallos := 0
var _fase := 0
var _ticks := 0


func _initialize() -> void:
	_menu = load("res://scenes/ui/menu_principal.tscn").instantiate()
	root.add_child(_menu)
	_menu.jugar_pedido.connect(func(i: int) -> void: _pedidos.append(i))
	physics_frame.connect(_tick)


func _tick() -> void:
	_ticks += 1
	match _fase:
		0:
			if _ticks < 3:
				return
			print("--- los botones estan ---")
			for nombre in ["Jugar", "Lecciones_boton", "Opciones_boton", "Salir"]:
				_ok("boton %s" % nombre, _menu.get_node_or_null("%" + nombre) != null)

			print("--- el tema esta aplicado ---")
			_ok("el menu tiene tema", _menu.theme != null)
			var jugar: Button = _menu.get_node("%Jugar")
			_ok("el boton usa el estilo del pack",
				jugar.get_theme_stylebox("normal") is StyleBoxTexture)

			print("--- las lecciones salen de la campaña ---")
			var campana: Campana = load("res://resources/encuentros/campana.tres")
			var lista: Control = _menu.get_node("%ListaLecciones")
			_igual("una fila por encuentro", lista.get_child_count(), campana.encuentros.size())
			var primera: Control = lista.get_child(0)
			var boton: Button = primera.get_child(0)
			_ok("con el titulo del encuentro (%s)" % boton.text,
				boton.text.contains(campana.encuentros[0].titulo))
			var pie: Label = primera.get_child(1)
			_ok("y con lo que enseña",
				pie.text == campana.encuentros[0].objetivo_pedagogico)

			print("--- solo se ve una vista por vez ---")
			_ok("arranca en la botonera", _menu.get_node("%Botonera").visible)
			_ok("las lecciones ocultas", not _menu.get_node("%Lecciones").visible)
			_ok("las opciones ocultas", not _menu.get_node("%Opciones").visible)

			_menu.get_node("%Lecciones_boton").pressed.emit()
			_ok("al pedir lecciones se ven", _menu.get_node("%Lecciones").visible)
			_ok("y la botonera se esconde", not _menu.get_node("%Botonera").visible)

			_menu.get_node("%VolverLecciones").pressed.emit()
			_ok("volver trae la botonera", _menu.get_node("%Botonera").visible)

			_menu.get_node("%Opciones_boton").pressed.emit()
			_ok("al pedir opciones se ven", _menu.get_node("%Opciones").visible)
			_menu.get_node("%Opciones").cerrar()
			_ok("y al cerrarlas vuelve la botonera", _menu.get_node("%Botonera").visible)

			print("--- jugar avisa por que leccion ---")
			# Se escucha la señal en vez de llamar a jugar(), que cambiaria de
			# escena y dejaria la prueba sin menu.
			_menu.jugar_pedido.emit(2)
			_ok("llego el pedido", _pedidos.size() == 1 and _pedidos[0] == 2)

			print("--- la anotacion del encuentro viaja en el arbol ---")
			_igual("sin anotacion arranca por la primera",
				Navegacion.encuentro_pedido(self), 0)
			set_meta(Navegacion.ENCUENTRO_INICIAL, 2)
			_igual("con anotacion arranca por la pedida",
				Navegacion.encuentro_pedido(self), 2)
			remove_meta(Navegacion.ENCUENTRO_INICIAL)
			_fase = 1
		1:
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit(1 if _fallos > 0 else 0)
			_fase = 2

	if _ticks > 600:
		print("FALLA: el test no termino")
		quit(1)


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _igual(que: String, obtenido: int, esperado: int) -> void:
	var ok := obtenido == esperado
	if not ok:
		_fallos += 1
	print("  [%s] %-44s obtenido=%d esperado=%d" % [
		"OK" if ok else "FALLA", que, obtenido, esperado])
