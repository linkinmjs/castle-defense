extends PruebaBase
## El HUD de a dos: cada jugador con su ficha (barras, combo, avisos y
## tarjeta) sin que lo de uno se filtre en la del otro, la leyenda y la
## invitacion del segundo, la marca de cada uno en el campo, y lo que ya hacia
## el HUD de uno solo con los combos: el renglon "x2 VENDAJE", el festejo del
## remate y el aviso bajo del golpe al aire.
##
## Instancia el HUD a proposito, pero solo para mirar el HUD: el modelo de
## combate se sigue probando sin interfaz en las demas suites. La batalla es
## de mentira: tiene lo que el HUD escucha y nada mas.

const ORIGEN_1 := Vector3(8, 0, 3)
const ORIGEN_2 := Vector3(20, 0, 7)
## Mas que la recuperacion de la ligera (0.3 s) y menos que la ventana del
## combo (0.7 s).
const ENTRE_BOTONES := 24
const LEYENDA_P1 := "Mover WASD / Stick · Ligera J / X · Pesada K / Y · Saltar Espacio / A"
const LEYENDA_P2 := "Mover Flechas / Stick · Ligera Coma / X · Pesada Punto / Y · Saltar Barra / A"

var _hud: CanvasLayer
var _h1: Healer3D
var _h2: Healer3D
var _a1: Unidad3D
var _a2: Unidad3D
var _batalla: BatallaDeDos


## Lo que el HUD escucha de Battle3D. En la de verdad encuentro_cerrado es de
## la telemetria; aca la telemetria es la misma batalla.
class BatallaDeUno extends Node:
	signal batalla_terminada(victoria: bool)
	signal encuentro_iniciado(encuentro: Encuentro, semilla: int, indice: int)
	signal encuentro_cerrado(resumen: Dictionary)

	var base_aliada_x := 1.5
	var base_enemiga_x := 28.5

	func telemetria() -> Node:
		return self

	func observacion_causal() -> String:
		return ""

	func frente_x() -> float:
		return 15.0


## La que deja entrar a un segundo jugador con el encuentro andando.
class BatallaDeDos extends BatallaDeUno:
	signal jugador_agregado(healer: Healer3D)


func preparar() -> void:
	var campo := Node3D.new()
	root.add_child(campo)
	_h1 = _healer(campo, 1, ORIGEN_1)
	_h2 = _healer(campo, 2, ORIGEN_2)
	# Uno a un metro al frente de cada healer: en la caja de la ligera del suyo
	# y lejos de la del otro.
	_a1 = _aliado(campo, "Mara", ORIGEN_1 + Vector3(1.0, 0, 0))
	_a2 = _aliado(campo, "Tino", ORIGEN_2 + Vector3(1.0, 0, 0))
	_hud = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(_hud)
	_batalla = BatallaDeDos.new()
	root.add_child(_batalla)


func fase(numero: int) -> void:
	match numero:
		0:
			if _ticks < 2:
				return
			for aliado: Unidad3D in [_a1, _a2]:
				aliado.set_physics_process(false)
				aliado.vida = aliado.vida_maxima - 50.0
			_llegan_los_jugadores()
			_cada_uno_lo_suyo()
			siguiente()
		1:
			# Los renglones de la tarjeta se pintan en el _process de la ficha.
			if _ticks < 2:
				return
			_la_tarjeta()

			print("--- L, L, P del 1: el combo se cuenta y el remate se festeja ---")
			_h1.pulsar(&"ligera")
			_ok("tras la ligera dice x1 TOQUE (%s)" % _ficha(1).texto_combo(),
				_ficha(1).combo_visible() and _ficha(1).texto_combo() == "x1 TOQUE")
			_ok("y el aviso dice lo que entro (%s)" % _ficha(1).texto_aviso(),
				_ficha(1).texto_aviso() == "+18")
			siguiente()
		2:
			if _ticks < ENTRE_BOTONES:
				return
			_h1.pulsar(&"ligera")
			_ok("tras dos dice x2 VENDAJE (%s)" % _ficha(1).texto_combo(),
				_ficha(1).texto_combo() == "x2 VENDAJE")
			siguiente()
		3:
			if _ticks < ENTRE_BOTONES:
				return
			_h1.pulsar(&"pesada")
			_ok("el remate se ve aunque el combo ya se cerro (%s)" % _ficha(1).texto_combo(),
				_hud.combo_visible() and _ficha(1).texto_combo() == "x3 OLEADA")
			_ok("y el aviso nombra la Oleada (%s)" % _ficha(1).texto_aviso(),
				_ficha(1).texto_aviso().begins_with("Oleada"))
			siguiente()
		4:
			# El festejo dura algo mas de un segundo y se apaga solo.
			if _ticks < 120:
				return
			_ok("un rato despues el remate se apago", not _hud.combo_visible())

			print("--- los cortes que no son remate apagan el combo en el acto ---")
			_h1.pulsar(&"ligera")
			_ok("una ligera vuelve a abrir el combo", _hud.combo_visible())
			_h1.recibir_dano(1.0)
			_ok("un golpe lo apaga", not _hud.combo_visible())
			siguiente()
		5:
			if _ticks < ENTRE_BOTONES:
				return
			print("--- el golpe al aire se avisa mas bajo ---")
			_h1._sprite.flip_h = true
			_h1.pulsar(&"ligera")
			_h1._sprite.flip_h = false
			_ok("dice que fue en vacio (%s)" % _ficha(1).texto_aviso(),
				_ficha(1).texto_aviso() == ComponenteCombos.EN_VACIO)
			_ok("a media opacidad (%.2f)" % _ficha(1).opacidad_aviso(),
				_ficha(1).opacidad_aviso() < 0.6)
			_h1.mana = 0.0
			_h1.pulsar(&"pesada")
			_ok("un rechazo de verdad va a pleno (%s)" % _ficha(1).texto_aviso(),
				_ficha(1).texto_aviso() == "Sin mana" and _ficha(1).opacidad_aviso() > 0.99)
			# captura_combos.gd sigue leyendo el HUD de uno solo por nombre.
			_ok("%Combo y %Aviso siguen siendo los del jugador 1",
				_ficha(1).is_ancestor_of(_hud.get_node("%Combo"))
					and (_hud.get_node("%Aviso") as Label).text == "Sin mana")

			print("--- la marca en el campo es de cada jugador ---")
			_ok("cada uno marca al suyo",
				_a1.resaltada and _a1.resaltada_por == 1 and _a2.resaltada and _a2.resaltada_por == 2)
			_ok("dorado el 1 y turquesa el 2",
				OverlayUnidades.color_jugador(1) == Color("e8b84a")
					and OverlayUnidades.color_jugador(2) == Color("5fd3c7"))
			# El 2 se para al lado del 1: los dos tienen a Mara al frente.
			_h2.global_position = ORIGEN_1 + Vector3(0, 0, 0.6)
			siguiente()
		6:
			if _ticks < 2:
				return
			_ok("con los dos encima, Mara sigue marcada (por %d)" % _a1.resaltada_por,
				_a1.resaltada and _a1.resaltada_por in [1, 2])
			_ok("y la marca que el 2 dejo atras se apago",
				not _a2.resaltada and _a2.resaltada_por == 0)
			_h2.global_position = ORIGEN_2
			siguiente()
		7:
			if _ticks < 2:
				return
			_ok("al irse el 2, la marca queda del 1 (por %d)" % _a1.resaltada_por,
				_a1.resaltada and _a1.resaltada_por == 1)
			_ok("y el 2 vuelve a marcar al suyo", _a2.resaltada and _a2.resaltada_por == 2)
			# Fuera de la caja de la ligera: tres metros al costado.
			_h1.global_position = ORIGEN_1 + Vector3(0, 0, 3.0)
			siguiente()
		8:
			if _ticks < 2:
				return
			_ok("al irse el 1 no es de nadie",
				not _a1.resaltada and _a1.resaltada_por == 0)
			_nada_toma_el_mouse()
			_sin_ingreso()
			terminar()


# --- Fases largas -------------------------------------------------------------

## El 1 lo sigue la batalla al arrancar; el 2 entra despues, por la senal.
func _llegan_los_jugadores() -> void:
	print("--- arranca uno solo ---")
	_hud.seguir(_h1)
	_hud.seguir_batalla(_batalla)
	_ok("la ficha del 1 se ve (%s)" % _ficha(1).titulo(),
		_ficha(1).visible and _ficha(1).titulo() == "Jugador 1")
	_ok("la del 2 no", not _ficha(2).visible)
	_ok("la leyenda del 1 nombra sus controles",
		_hud.leyenda(1).visible and _hud.leyenda(1).text == LEYENDA_P1)
	_ok("la del 2 no se ve", not _hud.leyenda(2).visible)
	_ok("y en su esquina se lo invita a entrar",
		_hud.invitando() and (_hud.get_node("%Invitacion") as Label).text.contains("apreta un boton"))

	print("--- entra el segundo ---")
	_batalla.jugador_agregado.emit(_h2)
	_ok("aparece su ficha (%s)" % _ficha(2).titulo(),
		_ficha(2).visible and _ficha(2).titulo() == "Jugador 2")
	_ok("y su leyenda, con sus controles (%s)" % _hud.leyenda(2).text,
		_hud.leyenda(2).visible and _hud.leyenda(2).text == LEYENDA_P2)
	_ok("la invitacion se va", not _hud.invitando())
	_ok("cada titulo del color de su marca",
		_color(_ficha(1), "Columna/Cabecera/Titulo") == OverlayUnidades.color_jugador(1)
			and _color(_ficha(2), "Columna/Cabecera/Titulo") == OverlayUnidades.color_jugador(2))
	# La batalla puede avisar dos veces del mismo: al arrancar y al entrar.
	_hud.seguir(_h2)
	_hud.seguir(_h1)
	_igual("seguirlo de nuevo no duplica las senales",
		_conexiones(_h1.vida_cambio, _ficha(1)) + _conexiones(_h2.vida_cambio, _ficha(2)), 2)


func _cada_uno_lo_suyo() -> void:
	print("--- cada ficha sigue a su healer ---")
	_ok("las dos arrancan llenas (%s | %s)" % [_ficha(1).texto_vida(), _ficha(2).texto_vida()],
		_ficha(1).texto_vida() == "60 / 60" and _ficha(2).texto_vida() == "60 / 60")
	_h1.recibir_dano(20.0)
	_ok("al 1 le pegan y baja su vida (%s)" % _ficha(1).texto_vida(),
		_ficha(1).texto_vida() == "40 / 60")
	_ok("la del 2 no se mueve (%s)" % _ficha(2).texto_vida(), _ficha(2).texto_vida() == "60 / 60")
	_h2.gastar_mana(30.0)
	_ok("el 2 gasta mana (%s)" % _ficha(2).texto_mana(), _ficha(2).texto_mana() == "70 / 100")
	_ok("y el del 1 sigue lleno (%s)" % _ficha(1).texto_mana(),
		_ficha(1).texto_mana() == "100 / 100")

	print("--- el combo de uno no aparece en la ficha del otro ---")
	_h2.pulsar(&"ligera")
	_ok("la ligera del 2 dice x1 TOQUE en su ficha (%s)" % _ficha(2).texto_combo(),
		_ficha(2).combo_visible() and _ficha(2).texto_combo() == "x1 TOQUE")
	var toque := (_h2.get_node("Combos") as ComponenteCombos).movimiento_por_nombre("Toque")
	_ok("del color del movimiento",
		_color(_ficha(2), "Columna/Cabecera/Combo") == toque.color)
	_ok("y la ficha del 1 sigue sin combo", not _ficha(1).combo_visible())
	_ok("el aviso tambien es solo del 2 (%s | \"%s\")" % [
			_ficha(2).texto_aviso(), _ficha(1).texto_aviso()],
		_ficha(2).texto_aviso() == "+18" and _ficha(1).texto_aviso() == "")


func _la_tarjeta() -> void:
	print("--- la tarjeta de cada ficha habla del que tiene al frente ---")
	var lineas := _ficha(1).lineas_tarjeta()
	_ok("quien es (%s)" % lineas[0], lineas[0] == "Mara · Lancero · 20 / 70 HP")
	_ok("que hace la ligera (%s)" % lineas[1], lineas[1] == "L · Toque: +18 HP")
	_ok("y que hace la pesada (%s)" % lineas[2], lineas[2] == "P · Plegaria: +40 HP")
	_ok("es lo que dicen sus renglones", _renglones(_ficha(1)) == lineas)
	var otra := _ficha(2).lineas_tarjeta()
	_ok("la del 2 habla del suyo (%s)" % otra[0], otra[0].begins_with("Tino"))
	# El 2 acaba de conectar una ligera: la siguiente ya seria el Vendaje.
	_ok("y sabe que su ligera ya es la segunda del combo (%s)" % otra[1],
		otra[1].begins_with("L · Vendaje"))


func _nada_toma_el_mouse() -> void:
	print("--- el HUD no se queda con el mouse ---")
	var tomadores: Array[String] = []
	for nodo in _hud.find_children("*", "Control", true, false):
		if (nodo as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			tomadores.append(String(nodo.name))
	_ok("todo con mouse_filter IGNORE %s" % [tomadores], tomadores.is_empty())


## Sin jugador_agregado (o sin batalla) no hay a quien invitar.
func _sin_ingreso() -> void:
	print("--- si la batalla no deja entrar a nadie, no se invita ---")
	var otro: CanvasLayer = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(otro)
	_ok("sin batalla, la esquina del 2 queda vacia", not otro.invitando())
	var de_uno := BatallaDeUno.new()
	root.add_child(de_uno)
	otro.seguir_batalla(de_uno)
	_ok("con una batalla de uno solo, tambien", not otro.invitando())


# --- Ayudas -------------------------------------------------------------------

func _healer(campo: Node3D, jugador: int, pos: Vector3) -> Healer3D:
	var healer: Healer3D = load("res://scenes/3d/healer3d.tscn").instantiate()
	healer.jugador = jugador
	healer.position = pos
	campo.add_child(healer)
	return healer


## Lancero sin sangrado: la vida la fija cada fase.
func _aliado(campo: Node3D, nombre: String, pos: Vector3) -> Unidad3D:
	var aliado: Unidad3D = load("res://scenes/3d/unidad3d.tscn").instantiate()
	aliado.configurar(Unidad3D.Bando.ALIADO, load("res://resources/soldados/lancero.tres"))
	aliado.nombre_unidad = nombre
	aliado.position = pos
	aliado.probabilidad_sangrado = 0.0
	campo.add_child(aliado)
	return aliado


func _ficha(jugador: int) -> FichaJugador:
	return _hud.ficha(jugador)


func _color(nodo: Node, ruta: String) -> Color:
	return (nodo.get_node(ruta) as Label).get_theme_color(&"font_color")


## Lo que muestran los tres renglones de la tarjeta de esa ficha.
func _renglones(ficha: FichaJugador) -> PackedStringArray:
	var textos := PackedStringArray()
	for nombre: String in ["Objetivo", "Ligera", "Pesada"]:
		textos.append((ficha.get_node("Columna/" + nombre) as Label).text)
	return textos


## Cuantas veces esta conectada esa senal a algo de la ficha.
func _conexiones(senal: Signal, ficha: Node) -> int:
	var total := 0
	for conexion: Dictionary in senal.get_connections():
		var metodo: Callable = conexion["callable"]
		if metodo.get_object() == ficha:
			total += 1
	return total
