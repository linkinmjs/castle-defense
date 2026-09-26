extends SceneTree
## Menu principal: que esten los botones, que la lista de lecciones salga de la
## campaña, que el tema este aplicado y que se pueda elegir cuantos juegan.
## Tambien el fondo vivo (las capas del atardecer, que se corren), el titulo
## con la fuente del tema y la tabla de controles de los dos jugadores.

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
			for nombre in ["Jugar", "Lecciones_boton", "Jugadores", "Controles_boton",
					"Opciones_boton", "Salir"]:
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

			_cuantos_juegan()
			_controles()
			_fondo()
			_fase = 1
		1:
			# El parallax corre en _process: se mira un rato despues.
			if _ticks < 90:
				return
			print("--- el fondo se mueve, cada capa a su velocidad ---")
			var montanas: float = _menu.corrimiento_capa(&"Montanas")
			var arboles: float = _menu.corrimiento_capa(&"Arboles")
			_ok("las capas se corrieron (montanas %.0f, arboles %.0f)" % [montanas, arboles],
				arboles > 0.0)
			_ok("y las de adelante mas rapido que las de atras", arboles > montanas)
			_fase = 2
		2:
			print("")
			print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
			quit(1 if _fallos > 0 else 0)
			_fase = 3

	if _ticks > 600:
		print("FALLA: el test no termino")
		quit(1)


## Uno o dos: el boton alterna y lo deja anotado en el arbol, que es de donde
## lo lee la batalla al armarse.
func _cuantos_juegan() -> void:
	print("--- cuantos juegan ---")
	var boton: Button = _menu.get_node("%Jugadores")
	_ok("esta en la botonera", boton.get_parent() == _menu.get_node("%Botonera"))
	_ok("sin anotacion dice uno (%s)" % boton.text, boton.text == "Jugadores: 1")
	boton.pressed.emit()
	_ok("un toque pasa a dos (%s)" % boton.text, boton.text == "Jugadores: 2")
	_igual("y lo anota para la batalla", Jugadores.cantidad_pedida(self), 2)
	boton.pressed.emit()
	_ok("otro toque vuelve a uno (%s)" % boton.text, boton.text == "Jugadores: 1")
	_igual("y la anotacion tambien", Jugadores.cantidad_pedida(self), 1)

	# Al volver de una partida de a dos, el menu arranca diciendo 2.
	Jugadores.pedir_cantidad(self, 2)
	var otro: Control = load("res://scenes/ui/menu_principal.tscn").instantiate()
	root.add_child(otro)
	var suyo: Button = otro.get_node("%Jugadores")
	_ok("un menu nuevo arranca con lo anotado (%s)" % suyo.text, suyo.text == "Jugadores: 2")
	otro.queue_free()
	remove_meta(Jugadores.CANTIDAD)


## La vista de controles: una tabla con las dos columnas de jugadores, que
## sale de Jugadores.etiquetas(), y su boton para volver.
func _controles() -> void:
	print("--- los controles de los dos jugadores ---")
	_ok("la vista existe y arranca oculta",
		_menu.get_node_or_null("%Controles") != null and not _menu.get_node("%Controles").visible)
	_ok("con su boton en la botonera",
		_menu.get_node("%Controles_boton").get_parent() == _menu.get_node("%Botonera"))
	_menu.get_node("%Controles_boton").pressed.emit()
	_ok("al pedirla se ve", _menu.get_node("%Controles").visible)
	_ok("y la botonera se esconde", not _menu.get_node("%Botonera").visible)
	var tabla: GridContainer = _menu.get_node("%TablaControles")
	var textos: Array[String] = []
	for celda in tabla.get_children():
		textos.append((celda as Label).text)
	_ok("tres columnas: la accion y un jugador en cada una", tabla.columns == 3)
	_ok("con los dos jugadores de cabecera", textos.has("Jugador 1") and textos.has("Jugador 2"))
	_ok("y sus teclas, de Jugadores.etiquetas() (%s)" % Jugadores.etiquetas(2)["ligera"],
		textos.has(Jugadores.etiquetas(1)["ligera"]) and textos.has(Jugadores.etiquetas(2)["ligera"]))
	_igual("una fila por accion mas la cabecera", textos.size(), 3 * 5)
	_menu.get_node("%VolverControles").pressed.emit()
	_ok("volver trae la botonera", _menu.get_node("%Botonera").visible
		and not _menu.get_node("%Controles").visible)


## El atardecer del campo detras del panel, y el titulo con la fuente del
## tema.
func _fondo() -> void:
	print("--- el fondo y el titulo ---")
	for nombre in ["Cielo", "Montanas", "Castillo", "Arboles"]:
		var capa := _menu.get_node_or_null("%" + nombre) as TextureRect
		_ok("la capa %s esta, con su textura" % nombre, capa != null and capa.texture != null)
	var arboles: TextureRect = _menu.get_node("%Arboles")
	_ok("las capas se repiten en X", arboles.stretch_mode == TextureRect.STRETCH_TILE)
	_ok("al doble, como el pixel art del juego", arboles.scale == Vector2(2, 2))
	var titulo: Label = _menu.get_node("%Titulo")
	_ok("el titulo dice CASTLE DEFENSE", titulo.text == "CASTLE DEFENSE")
	_ok("con la fuente del tema", titulo.get_theme_font(&"font") == _menu.theme.default_font
		and _menu.theme.default_font != null)
	_ok("y grande (%d)" % titulo.get_theme_font_size(&"font_size"),
		titulo.get_theme_font_size(&"font_size") >= 44)


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
