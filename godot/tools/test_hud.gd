extends PruebaBase
## El HUD de a dos: cada jugador con su ficha (barras, combo, avisos y
## tarjeta) sin que lo de uno se filtre en la del otro, la leyenda y la
## invitacion del segundo, la marca de cada uno en el campo, y lo que ya hacia
## el HUD de uno solo con los combos: el renglon "x2 VENDAJE", el festejo del
## remate y el aviso bajo del golpe al aire.
##
## Y lo de beat-em-up: la vida con fantasma, el mana que se desliza, el golpe
## del combo, la raya de la ventana, la barra de carga de la plegaria, los
## iconos y las teclas de la tarjeta, la barra del nivel con sus sectores, el
## cartel de avanzar, el encabezado del sector, la barra del jefe y el
## resumen con el combo maximo.
##
## Instancia el HUD a proposito, pero solo para mirar el HUD: el modelo de
## combate se sigue probando sin interfaz en las demas suites. La batalla es
## de mentira: tiene lo que el HUD escucha y nada mas, incluidas las senales
## de sectores y jefes que la batalla de verdad todavia no tiene.

const ORIGEN_1 := Vector3(8, 0, 3)
const ORIGEN_2 := Vector3(20, 0, 7)
## Mas que la recuperacion de la ligera (0.3 s) y menos que la ventana del
## combo (0.7 s).
const ENTRE_BOTONES := 24
## Un cuarto de segundo de fisica: la plegaria (0.5 s de carga) va por la
## mitad.
const MEDIA_CARGA := 15
const LEYENDA_P1 := "Mover WASD / Stick · Ligera J / X · Pesada K / Y · Saltar Espacio / A"
const LEYENDA_P2 := "Mover Flechas / Stick · Ligera Coma / X · Pesada Punto / Y · Saltar Barra / A"

var _hud: CanvasLayer
var _h1: Healer3D
var _h2: Healer3D
var _a1: Unidad3D
var _a2: Unidad3D
var _batalla: BatallaConSectores
var _jefe: JefeFalso
## Cuadros de _process desde que empezo la fase. Lo que anima el HUD corre en
## _process, y con cuadros lentos Godot mete varios pasos de fisica en uno:
## contar solo ticks no alcanza para saber si el HUD ya se actualizo.
var _cuadros := 0
## Si la revision a mitad de fase ya se hizo.
var _revisado := false


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


## La del nivel partido en sectores y con jefe: el contrato del paquete de la
## batalla, tal como lo espera el HUD.
class BatallaConSectores extends BatallaDeDos:
	signal sector_iniciado(indice: int, sector: Resource)
	signal sector_liberado(indice: int)
	signal unidad_creada(unidad: Node)

	var progreso := 0.0
	var sectores: Array[Resource] = []

	func progreso_nivel() -> float:
		return progreso

	func cantidad_sectores() -> int:
		return sectores.size()


## Lo unico que el HUD le lee a un sector.
class SectorFalso extends Resource:
	var titulo := ""
	var x_fin := 0.0

	func _init(nuevo_titulo: String = "", nueva_x_fin: float = 0.0) -> void:
		titulo = nuevo_titulo
		x_fin = nueva_x_fin


## Lo que el HUD le lee a una unidad jefe.
class JefeFalso extends Node:
	signal murio(unidad: Node)

	var es_jefe := true
	var nombre_unidad := "Ogro"
	var vida := 300.0
	var vida_maxima := 400.0


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
	_batalla = BatallaConSectores.new()
	root.add_child(_batalla)
	process_frame.connect(func() -> void: _cuadros += 1)


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
			_avanzar()
		1:
			# Los renglones de la tarjeta se pintan en el _process de la ficha.
			if not _pasaron(2):
				return
			_la_tarjeta()

			print("--- L, L, P del 1: el combo se cuenta y el remate se festeja ---")
			_h1.pulsar(&"ligera")
			_ok("tras la ligera dice x1 TOQUE (%s)" % _ficha(1).texto_combo(),
				_ficha(1).combo_visible() and _ficha(1).texto_combo() == "x1 TOQUE")
			_ok("y el aviso dice lo que entro (%s)" % _ficha(1).texto_aviso(),
				_ficha(1).texto_aviso() == "+18")
			_ok("el combo pega un golpe de escala (%.2f)" % _ficha(1).escala_combo(),
				_ficha(1).escala_combo() > 1.3)
			_avanzar()
		2:
			# A un cuarto de segundo: la ventana (0.7 s) va por la mitad y el
			# golpe (0.15 s) ya termino.
			if not _revisado and _pasaron(MEDIA_CARGA):
				_revisado = true
				_ok("con ventana abierta se ve la raya del combo (%.2f)" % _ficha(1).fraccion_ventana(),
					_ficha(1).ventana_visible() and _ficha(1).fraccion_ventana() > 0.3
						and _ficha(1).fraccion_ventana() < 0.9)
				_ok("y el golpe ya volvio a su tamano (%.2f)" % _ficha(1).escala_combo(),
					is_equal_approx(_ficha(1).escala_combo(), 1.0))
			if _ticks < ENTRE_BOTONES or not _revisado:
				return
			_h1.pulsar(&"ligera")
			_ok("tras dos dice x2 VENDAJE (%s)" % _ficha(1).texto_combo(),
				_ficha(1).texto_combo() == "x2 VENDAJE")
			_avanzar()
		3:
			if not _revisado and _pasaron(3):
				_revisado = true
				# Despues de dos ligeras la ligera es otra vez el Vendaje, que
				# se acaba de usar.
				var ligera := _ficha(1).estado_lineas()[0]
				_ok("la ligera es el Vendaje, enfriandose (%s, %.2f)" % [
						ligera["movimiento"], ligera["fraccion_enfriamiento"]],
					ligera["movimiento"] == "Vendaje" and ligera["enfriando"]
						and not ligera["listo"])
			if _ticks < ENTRE_BOTONES or not _revisado:
				return
			_h1.pulsar(&"pesada")
			_ok("el remate se ve aunque el combo ya se cerro (%s)" % _ficha(1).texto_combo(),
				_hud.combo_visible() and _ficha(1).texto_combo() == "x3 OLEADA")
			_ok("y el aviso nombra la Oleada (%s)" % _ficha(1).texto_aviso(),
				_ficha(1).texto_aviso().begins_with("Oleada"))
			_avanzar()
		4:
			# El festejo dura algo mas de un segundo y se apaga solo.
			if not _pasaron(120):
				return
			_ok("un rato despues el remate se apago", not _hud.combo_visible())
			_ok("y cerrado el combo, la raya de la ventana no se ve",
				not _ficha(1).ventana_visible())
			_el_fantasma_bajo()

			print("--- los cortes que no son remate apagan el combo en el acto ---")
			_h1.pulsar(&"ligera")
			_ok("una ligera vuelve a abrir el combo", _hud.combo_visible())
			_h1.recibir_dano(1.0)
			_ok("un golpe lo apaga", not _hud.combo_visible())

			print("--- la plegaria del 2 carga a la vista ---")
			_ok("antes de rezar no hay barra de carga", not _ficha(2).carga_visible())
			_ok("la pesada del 2 sale", _h2.pulsar(&"pesada"))
			_avanzar()
		5:
			if not _pasaron(MEDIA_CARGA):
				return
			_la_carga()
			_avanzar()
		6:
			# La plegaria termina a los 0.5 s de apretar: bien pasados aca.
			if not _pasaron(30):
				return
			_ok("al salir la plegaria la carga se va", not _ficha(2).carga_visible())
			_ok("y el renglon vuelve a ser del aviso, que dice como salio (%s)" % _ficha(2).texto_aviso(),
				_ficha(2).texto_aviso().begins_with("Plegaria:"))

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
			_avanzar()
		7:
			if not _pasaron(2):
				return
			_ok("sin mana, la pesada del 1 lo dice en su renglon (%s)" % _ficha(1).estado_lineas()[1]["texto"],
				_ficha(1).estado_lineas()[1]["sin_mana"]
					and _ficha(1).estado_lineas()[1]["texto"].ends_with("sin mana"))
			_ok("con los dos encima, Mara sigue marcada (por %d)" % _a1.resaltada_por,
				_a1.resaltada and _a1.resaltada_por in [1, 2])
			_ok("y la marca que el 2 dejo atras se apago",
				not _a2.resaltada and _a2.resaltada_por == 0)
			_h2.global_position = ORIGEN_2
			_avanzar()
		8:
			if _ticks < 2:
				return
			_ok("al irse el 2, la marca queda del 1 (por %d)" % _a1.resaltada_por,
				_a1.resaltada and _a1.resaltada_por == 1)
			_ok("y el 2 vuelve a marcar al suyo", _a2.resaltada and _a2.resaltada_por == 2)
			# Fuera de la caja de la ligera: tres metros al costado.
			_h1.global_position = ORIGEN_1 + Vector3(0, 0, 3.0)
			_avanzar()
		9:
			if _ticks < 2:
				return
			_ok("al irse el 1 no es de nadie",
				not _a1.resaltada and _a1.resaltada_por == 0)
			_la_barra_del_nivel()
			_el_cartel_y_el_sector()
			_llega_el_jefe()
			_avanzar()
		10:
			if not _pasaron(3):
				return
			_ok("un golpe al jefe deja fantasma en su barra (%.0f sobre %.0f)" % [
					_hud.barra_jefe().fantasma(), _hud.barra_jefe().vida_mostrada()],
				_hud.barra_jefe().fantasma() > _hud.barra_jefe().vida_mostrada()
					and is_equal_approx(_hud.barra_jefe().vida_mostrada(), 200.0))
			_jefe.murio.emit(_jefe)
			_ok("al morir el jefe su barra deja de seguirlo",
				not _hud.barra_jefe().mostrando_jefe())
			_el_final()
			_avanzar()
		11:
			# La barra del jefe se vacia y se va; los numeros del resumen ya
			# llegaron.
			if not _pasaron(100):
				return
			_ok("y la barra del jefe se fue", not _hud.barra_jefe().visible)
			_ok("los numeros del resumen llegaron a su valor",
				_hud.resumen().avance_cuenta() >= 1.0)
			_ok("el cartel del final quedo a tamano natural",
				(_hud.get_node("%Desenlace") as Control).offset_transform_scale.is_equal_approx(Vector2.ONE))
			_el_encuentro_se_anuncia()
			_nada_toma_el_mouse()
			_sin_ingreso()
			terminar()


## Pasa de fase con los cuadros y la revision a mitad de fase en cero.
func _avanzar() -> void:
	siguiente()
	_cuadros = 0
	_revisado = false


## Si ya pasaron esos ticks de fisica y al menos dos cuadros de _process.
func _pasaron(ticks: int) -> bool:
	return _ticks >= ticks and _cuadros >= 2


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
	_ok("la barra baja en el acto (%.0f)" % _ficha(1).vida_mostrada(),
		is_equal_approx(_ficha(1).vida_mostrada(), 40.0))
	_ok("y el fantasma queda arriba, donde estaba (%.0f)" % _ficha(1).fantasma_vida(),
		_ficha(1).fantasma_vida() > _ficha(1).vida_mostrada()
			and is_equal_approx(_ficha(1).fantasma_vida(), 60.0))
	_ok("la del 2 no se mueve (%s)" % _ficha(2).texto_vida(), _ficha(2).texto_vida() == "60 / 60")
	_h2.gastar_mana(30.0)
	_ok("el 2 gasta mana (%s)" % _ficha(2).texto_mana(), _ficha(2).texto_mana() == "70 / 100")
	_ok("y su barra se desliza en vez de saltar (%.0f)" % _ficha(2).mana_mostrado(),
		_ficha(2).mana_mostrado() > 90.0)
	_ok("el mana del 1 sigue lleno (%s)" % _ficha(1).texto_mana(),
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
	_ok("que hace la ligera (%s)" % lineas[1], lineas[1] == "J · Toque: +18 HP")
	_ok("y que hace la pesada (%s)" % lineas[2], lineas[2] == "K · Plegaria: +40 HP")
	_ok("es lo que dicen sus renglones", _renglones(_ficha(1)) == lineas)
	var otra := _ficha(2).lineas_tarjeta()
	_ok("la del 2 habla del suyo (%s)" % otra[0], otra[0].begins_with("Tino"))
	# El 2 acaba de conectar una ligera: la siguiente ya seria el Vendaje.
	_ok("y sabe que su ligera ya es la segunda del combo (%s)" % otra[1],
		otra[1].begins_with(", · Vendaje"))

	print("--- cada renglon con el icono y la tecla ---")
	var combos := _h1.get_node("Combos") as ComponenteCombos
	var estados := _ficha(1).estado_lineas()
	_ok("la ligera del 1 es la J, con el icono de Toque",
		estados[0]["boton"] == "J"
			and estados[0]["icono"] == combos.movimiento_por_nombre("Toque").icono
			and estados[0]["icono"] != null)
	_ok("la pesada del 1 es la K, con el de la Plegaria",
		estados[1]["boton"] == "K"
			and estados[1]["icono"] == combos.movimiento_por_nombre("Plegaria").icono)
	_ok("listas: sin enfriamiento ni falta de mana",
		estados[0]["listo"] and estados[1]["listo"])
	var del_dos := _ficha(2).estado_lineas()
	_ok("las del 2 son la coma y el punto (%s %s)" % [del_dos[0]["boton"], del_dos[1]["boton"]],
		del_dos[0]["boton"] == "," and del_dos[1]["boton"] == ".")


## La plegaria del 2 va por la mitad de su carga.
func _la_carga() -> void:
	var combos := _h2.get_node("Combos") as ComponenteCombos
	var progreso := combos.progreso_en_curso()
	_ok("el componente la tiene en curso (%s)" % combos.movimiento_en_curso(),
		combos.movimiento_en_curso() != null and combos.movimiento_en_curso().nombre == "Plegaria")
	_ok("va por la mitad de la carga (%.2f)" % progreso, progreso > 0.2 and progreso < 0.8)
	_ok("la ficha muestra la barra de carga", _ficha(2).carga_visible())
	_ok("llena como el componente (%.2f)" % _ficha(2).progreso_carga(),
		absf(_ficha(2).progreso_carga() - progreso) < 0.1)
	_ok("con el nombre de lo que carga (%s)" % _ficha(2).texto_carga(),
		_ficha(2).texto_carga() == "Plegaria")
	_ok("y la del 1 no carga nada", not _ficha(1).carga_visible())


## Un segundo despues del golpe el fantasma ya alcanzo a la vida, y el mana
## del 2 llego a su valor.
func _el_fantasma_bajo() -> void:
	_ok("el fantasma de la vida bajo hasta la vida (%.1f / %.1f)" % [
			_ficha(1).fantasma_vida(), _ficha(1).vida_mostrada()],
		absf(_ficha(1).fantasma_vida() - _ficha(1).vida_mostrada()) < 0.5)
	_ok("y el mana del 2 alcanzo al real (%.1f / %.1f)" % [_ficha(2).mana_mostrado(), _h2.mana],
		absf(_ficha(2).mana_mostrado() - _h2.mana) < 1.0)


## La barra del nivel lee el progreso y los sectores de la batalla.
func _la_barra_del_nivel() -> void:
	print("--- la barra del nivel ---")
	var barra: BarraNivel = _hud.barra_nivel()
	_igual("sin sectores anunciados no hay marcas", barra.cantidad_marcas(), 0)
	_batalla.sectores = [
		SectorFalso.new("Afueras", 10.0),
		SectorFalso.new("Puente", 19.0),
		SectorFalso.new("Porton", 28.5),
	]
	_batalla.progreso = 0.4
	_igual("una marca por sector", barra.cantidad_marcas(), 3)
	_igual("el tramo liberado es progreso_nivel()", barra.progreso(), 0.4)
	var marcas := barra.fracciones_marcas()
	_igual("la primera marca cae en su x_fin", marcas[0], (10.0 - 1.5) / 27.0)
	_igual("y la ultima en la base enemiga", marcas[2], 1.0)
	_igual("el frente cae en la mitad", barra.fraccion_frente(), 0.5)
	var marcadores := barra.marcadores_healers()
	var jugadores: Array[int] = []
	for marcador in marcadores:
		jugadores.append(marcador["jugador"])
	jugadores.sort()
	_ok("un marcador por healer (%s)" % [jugadores], jugadores == [1, 2])


## El cartel de avanzar y el encabezado del sector, con las senales de la
## batalla.
func _el_cartel_y_el_sector() -> void:
	print("--- el cartel de avanzar ---")
	var cartel: CartelAvanzar = _hud.cartel_avanzar()
	_ok("arranca oculto", not cartel.visible)
	_batalla.sector_liberado.emit(0)
	_ok("al liberar un sector aparece (%s)" % cartel.texto(),
		cartel.visible and cartel.texto() == "¡AVANZAR →!")
	_batalla.sector_iniciado.emit(1, _batalla.sectores[1])
	_ok("y al arrancar el siguiente se va", not cartel.visible)

	print("--- el encabezado anuncia el sector ---")
	var encabezado: EncabezadoSector = _hud.encabezado()
	_ok("dice \"Sector 2 · Puente\" (%s)" % encabezado.texto_cartel(),
		encabezado.cartel_visible() and encabezado.texto_cartel() == "Sector 2 · Puente")
	_batalla.sector_liberado.emit(1)
	_ok("liberado ese, el cartel de avanzar vuelve", cartel.visible)
	_batalla.batalla_terminada.emit(true)
	_ok("y el final lo saca", not cartel.visible)


## La barra del jefe aparece con la unidad que trae es_jefe y no con otra.
func _llega_el_jefe() -> void:
	print("--- la barra del jefe ---")
	var barra: BarraJefe = _hud.barra_jefe()
	var soldado := JefeFalso.new()
	soldado.es_jefe = false
	root.add_child(soldado)
	_batalla.unidad_creada.emit(soldado)
	_ok("un soldado comun no tiene barra", not barra.visible)
	_jefe = JefeFalso.new()
	root.add_child(_jefe)
	_batalla.unidad_creada.emit(_jefe)
	_ok("el jefe si (%s)" % barra.nombre(), barra.visible and barra.mostrando_jefe()
		and barra.nombre() == "Ogro")
	_igual("con su vida", barra.vida_mostrada(), 300.0)
	_jefe.vida = 200.0


## El cartel del final y el resumen, con los numeros nuevos.
func _el_final() -> void:
	print("--- el cartel del final y el resumen ---")
	_batalla.batalla_terminada.emit(true)
	var desenlace := _hud.get_node("%Desenlace") as Control
	_ok("dice VICTORIA (%s)" % _hud.desenlace(), _hud.desenlace() == "VICTORIA")
	_ok("y entra chico (%.2f)" % desenlace.offset_transform_scale.x,
		desenlace.offset_transform_scale.x < 0.7)
	_batalla.encuentro_cerrado.emit({
		"curacion_emitida": 120.0, "curacion_efectiva": 90.0,
		"curacion_desperdiciada": 30.0, "fraccion_desperdiciada": 0.25,
		"mana_gastado": 80.0, "mana_sin_usar": 20.0,
		"combo_maximo": 3, "usos_por_jugador": {1: 5, 2: 3}, "jugadores": 2,
		"duracion": 42.0, "segundos_mana_al_tope": 4.0,
	})
	var texto: String = _hud.resumen().texto()
	_contiene("el resumen trae el combo maximo", texto, "Combo maximo: 3")
	_contiene("y lo que hizo cada jugador", texto, "Movimientos: J1 5 · J2 3")
	_contiene("con el pie de las dos salidas", texto, "R / Back repetir · Enter / Start seguir")
	_ok("y los numeros arrancan contando (%.2f)" % _hud.resumen().avance_cuenta(),
		_hud.resumen().avance_cuenta() < 1.0)


## Un encuentro nuevo: el titulo grande, el objetivo, y el sector que llega
## al mismo tiempo espera su turno.
func _el_encuentro_se_anuncia() -> void:
	print("--- el encuentro se anuncia y el sector espera ---")
	var encuentro := Encuentro.new()
	encuentro.titulo = "Mantener la linea"
	encuentro.objetivo_pedagogico = "Curar a tiempo sostiene el frente."
	_batalla.encuentro_iniciado.emit(encuentro, 1, 0)
	var encabezado: EncabezadoSector = _hud.encabezado()
	_ok("el titulo entra grande (%s)" % encabezado.texto_cartel(),
		encabezado.cartel_visible() and encabezado.texto_cartel() == "1. Mantener la linea")
	_ok("con el objetivo debajo (%s)" % encabezado.subtitulo_cartel(),
		encabezado.subtitulo_cartel() == "Curar a tiempo sostiene el frente.")
	_ok("y el renglon que queda ya lo tiene (%s)" % encabezado.texto_linea(),
		encabezado.texto_linea() == "1. Mantener la linea · Curar a tiempo sostiene el frente.")
	_batalla.sector_iniciado.emit(0, _batalla.sectores[0])
	_ok("el sector que arranca con el encuentro espera (%s)" % encabezado.pendiente(),
		encabezado.anunciando() == "encuentro" and encabezado.pendiente() == "Sector 1 · Afueras")
	_ok("el encuentro nuevo se lleva el cartel del final", _hud.desenlace() == ""
		and not _hud.resumen().visible)


func _nada_toma_el_mouse() -> void:
	print("--- el HUD no se queda con el mouse ---")
	var tomadores: Array[String] = []
	for nodo in _hud.find_children("*", "Control", true, false):
		if (nodo as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			tomadores.append(String(nodo.name))
	_ok("todo con mouse_filter IGNORE %s" % [tomadores], tomadores.is_empty())


## Sin jugador_agregado (o sin batalla) no hay a quien invitar; sin sectores
## ni jefes, sus piezas no aparecen y la barra se porta como el indicador de
## siempre.
func _sin_ingreso() -> void:
	print("--- si la batalla no deja entrar a nadie, no se invita ---")
	var otro: CanvasLayer = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(otro)
	_ok("sin batalla, la esquina del 2 queda vacia", not otro.invitando())
	var de_uno := BatallaDeUno.new()
	root.add_child(de_uno)
	otro.seguir_batalla(de_uno)
	_ok("con una batalla de uno solo, tambien", not otro.invitando())
	_ok("sin sectores la barra no tiene marcas ni tramo liberado",
		otro.barra_nivel().cantidad_marcas() == 0 and otro.barra_nivel().progreso() == 0.0)
	_ok("y el cartel de avanzar y la barra del jefe no aparecen",
		not otro.cartel_avanzar().visible and not otro.barra_jefe().visible)


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


## Lo que muestran los renglones de la tarjeta de esa ficha, con la tecla
## adelante como en TarjetaObjetivo.lineas().
func _renglones(ficha: FichaJugador) -> PackedStringArray:
	var textos := PackedStringArray([ficha.texto_objetivo()])
	for estado in ficha.estado_lineas():
		textos.append("%s%s%s" % [estado["boton"], TarjetaObjetivo.SEPARADOR, estado["texto"]])
	return textos


## Cuantas veces esta conectada esa senal a algo de la ficha.
func _conexiones(senal: Signal, ficha: Node) -> int:
	var total := 0
	for conexion: Dictionary in senal.get_connections():
		var metodo: Callable = conexion["callable"]
		if metodo.get_object() == ficha:
			total += 1
	return total
