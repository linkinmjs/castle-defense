extends PruebaBase
## Dos jugadores en la misma batalla: cada uno lee lo suyo, los enemigos los
## tratan como a dos objetivos, los dos quedan siempre en cuadro, y el segundo
## se puede sumar apretando un boton.
##
## Arma tres batallas seguidas sobre la escena real, con el encuentro 1: una
## con los dos pedidos desde el menu, otra con uno solo donde el 2 entra a
## mitad del encuentro, y otra donde entra con el encuentro ya terminado.

const E1 := "res://resources/encuentros/e1_mantener_linea.tres"
const FRAMES_1 := "res://assets/sprites/healer/healer_frames.tres"
const FRAMES_2 := "res://assets/sprites/healer2/healer2_frames.tres"
## Donde arranca el 2 respecto del 1.
const LADO_DEL_1 := Vector3(-1.2, 0.0, 0.8)

var _battle: Node
var _camara: CamaraBatalla
## Lo que fue avisando la batalla, en orden. Enganchado antes de su _ready,
## que es donde entra el 2 si el menu pidio dos.
var _avisos: Array[String] = []
var _agregados: Array[Healer3D] = []
var _inicio_1: Vector3
var _inicio_2: Vector3
var _x1: float = 0.0
var _x2: float = 0.0
var _camara_antes: float = 0.0
var _enemigo: Unidad3D


func preparar() -> void:
	Jugadores.pedir_cantidad(self, 2)
	_armar_batalla()


func fase(numero: int) -> void:
	match numero:
		0:
			if _ticks < 3:
				return
			_camara = _battle.get_node("%Camara")
			_probar_dos_desde_el_menu()
			print("--- cada uno camina con lo suyo ---")
			_x1 = _h(1).global_position.x
			_x2 = _h(2).global_position.x
			_mantener(&"p2_derecha", true)
			siguiente()
		1:
			if _ticks < 20:
				return
			_ok("p2_derecha mantenida mueve al 2 (%.2f -> %.2f)" % [_x2, _h(2).global_position.x],
				_h(2).global_position.x > _x2 + 0.5)
			_igual("y el 1 no se mueve", _h(1).global_position.x, _x1, 0.0001)
			_mantener(&"p2_derecha", false)
			siguiente()
		2:
			# Que el 2 frene del todo antes de moverlos a mano.
			if _ticks < 15:
				return
			print("--- el enemigo va por el healer mas cercano ---")
			_h(1).global_position = Vector3(10.0, 0.0, 2.0)
			_h(2).global_position = Vector3(10.0, 0.0, 7.0)
			# Lejos de los soldados, que estan de x 13 en adelante: los unicos
			# candidatos cerca son los dos healers.
			_enemigo = load("res://scenes/3d/unidad3d.tscn").instantiate()
			_enemigo.configurar(Unidad3D.Bando.ENEMIGO)
			_enemigo.position = Vector3(10.0, 0.0, 8.0)
			_battle.get_node("%Unidades").add_child(_enemigo)
			siguiente()
		3:
			if _ticks < 3:
				return
			_ok("a 1 m del 2 y a 6 m del 1, elige al 2", _enemigo._objetivo == _h(2))
			_h(2).saltar()
			siguiente()
		4:
			if _ticks < 3:
				return
			_ok("el 2 salto", _h(2).esta_en_el_aire() and _h(2).global_position.y > 0.0)
			print("--- reiniciar reubica a los dos ---")
			_battle.reiniciar_encuentro()
			_ok("el 1 vuelve a donde arranco", _h(1).global_position.is_equal_approx(_inicio_1))
			_ok("y el 2 tambien, en el suelo (%s)" % _h(2).global_position,
				_h(2).global_position.is_equal_approx(_inicio_2) and not _h(2).esta_en_el_aire())
			_igual("la camara vuelve al medio de los dos", _camara.x_actual(),
				(_inicio_1.x + _inicio_2.x) * 0.5, 0.0001)
			_ok("siguen siendo dos", get_nodes_in_group("healer").size() == 2)
			_ok("y reiniciar no vuelve a avisar", _agregados.size() == 1)
			siguiente()
		5:
			if _ticks < 3:
				return
			print("--- los dos quedan en cuadro ---")
			_camara_antes = _camara.x_actual()
			# Mucho mas alla de lo que se ve: el recorte de pantalla lo trae de
			# vuelta en el primer tick.
			_h(2).global_position.x = 28.0
			siguiente()
		6:
			if _ticks < 5:
				return
			var rango := _camara.rango_x_jugadores()
			var x2 := _h(2).global_position.x
			_ok("el 2, puesto en x 28, vuelve a lo que se ve (%.2f en [%.2f, %.2f])" % [
					x2, rango.x, rango.y],
				x2 < 27.0 and _en_rango(x2, rango))
			_ok("y el 1 sigue en cuadro", _en_rango(_h(1).global_position.x, rango))
			_ok("los dos se recortan contra lo que ve la camara",
				_h(1).limites_pantalla == _h(2).limites_pantalla and _h(2).limites_pantalla.y < 27.0)
			siguiente()
		7:
			# Tiempo para que la camara se acomode.
			if _ticks < 90:
				return
			var medio := (_h(1).global_position.x + _h(2).global_position.x) * 0.5
			var x := _camara.x_actual()
			_ok("la camara mira el medio de los dos (%.2f contra %.2f, dentro de la zona muerta)" % [
					x, medio],
				absf(x - medio) <= _camara.zona_muerta + 0.05)
			_ok("se movio por el 2 aunque el 1 siguio quieto (%.2f -> %.2f)" % [_camara_antes, x],
				x > _camara_antes + 0.5)
			_probar_emergentes()
			siguiente()
		8:
			print("--- con uno solo, el 2 entra apretando un boton suyo ---")
			Jugadores.pedir_cantidad(self, 1)
			_armar_batalla()
			siguiente()
		9:
			if _ticks < 3:
				return
			_probar_drop_in()
			_probar_usos_del_2()
			siguiente()
		10:
			print("--- con el encuentro terminado tambien entra ---")
			_armar_batalla()
			siguiente()
		11:
			if _ticks < 3:
				return
			# Se fuerza el final en vez de esperar los 75 segundos.
			_battle.tiempo_encuentro = _battle._actual.duracion
			siguiente()
		12:
			if not _battle.esta_terminada():
				return
			_probar_drop_in_terminada()
			terminar()


# --- Pruebas ------------------------------------------------------------------

func _probar_dos_desde_el_menu() -> void:
	print("--- dos pedidos desde el menu ---")
	var h1 := _h(1)
	var h2 := _h(2)
	_ok("la escena trae la CamaraBatalla", _battle.get_node("%Camara") is CamaraBatalla)
	_ok("hay dos healers en el grupo", get_nodes_in_group("healer").size() == 2)
	_ok("healer_de(2) es del jugador 2", h2 != null and h2.jugador == 2)
	if h2 == null:
		return
	_ok("healer_de(1) es el de la escena", h1 == _battle.get_node("%Healer"))
	_ok("tiene_jugador(2)", _battle.tiene_jugador(2))
	_ok("el 2 se aviso antes del primer encuentro (%s)" % ", ".join(PackedStringArray(_avisos)),
		_avisos.size() >= 2 and _avisos[0] == "jugador_agregado:2" \
			and _avisos[1] == "encuentro_iniciado")
	_ok("y una sola vez, con su healer", _agregados.size() == 1 and _agregados[0] == h2)
	_ok("agregarlo de nuevo devuelve el mismo sin avisar",
		_battle.agregar_jugador(2) == h2 and _agregados.size() == 1)

	_ok("el 1 con su tinte suave", h1.tinte_jugador.is_equal_approx(Jugadores.tinte(1)))
	_ok("y ese es el que se ve", h1.get_node("Sprite").modulate.is_equal_approx(Jugadores.tinte(1)))
	_ok("el 2 con el suyo", h2.tinte_jugador.is_equal_approx(Jugadores.tinte(2))
		and h2.get_node("Sprite").modulate.is_equal_approx(Jugadores.tinte(2)))
	_ok("los tintes son distintos", not Jugadores.tinte(1).is_equal_approx(Jugadores.tinte(2)))
	_ok("el 2 con el sprite de contorno turquesa",
		h2.get_node("Sprite").sprite_frames.resource_path == FRAMES_2)
	_ok("y el 1 con el suyo", h1.get_node("Sprite").sprite_frames.resource_path == FRAMES_1)

	_inicio_1 = h1.global_position
	_inicio_2 = h2.global_position
	_ok("el 1 arranca donde dice el encuentro (%s)" % _inicio_1,
		_inicio_1.is_equal_approx(Vector3(15.0, 0.0, 5.0)))
	_ok("el 2 un paso atras y mas cerca de la camara (%s)" % _inicio_2,
		_inicio_2.is_equal_approx(_inicio_1 + LADO_DEL_1))
	_ok("los dos con los movimientos del encuentro (solo Toque)",
		_combos(h1).movimientos.size() == 1 and _combos(h2).movimientos.size() == 1)
	var campo := Rect2(1.5, 1.5, 27.0, 7.0)
	_ok("los dos con los limites del campo", h1.limites == campo and h2.limites == campo)
	_ok("y con lo que ve la camara como limite de pantalla",
		h1.limites_pantalla.is_equal_approx(_camara.rango_x_jugadores())
			and h2.limites_pantalla.is_equal_approx(_camara.rango_x_jugadores()))
	_igual("la camara arranca en el medio de los dos", _camara.x_actual(),
		(_inicio_1.x + _inicio_2.x) * 0.5, 0.0001)
	_ok("la telemetria mira a los dos", _battle.telemetria().resumen()["jugadores"] == 2)


## Con los dos lejos entre si, cada emergente cae cerca de uno o del otro, y
## la misma semilla repite los mismos lugares.
func _probar_emergentes() -> void:
	print("--- los emergentes salen alrededor de cualquiera de los dos ---")
	var antes_1 := _h(1).global_position
	var antes_2 := _h(2).global_position
	# Se mueven y se devuelven en el mismo tick: el recorte de pantalla no
	# llega a correr.
	_h(1).global_position = Vector3(5.0, 0.0, 5.0)
	_h(2).global_position = Vector3(25.0, 0.0, 5.0)
	var primera := _emergentes(4321)
	var segunda := _emergentes(4321)
	_ok("con la misma semilla salen en los mismos lugares", primera == segunda and primera.size() == 8)
	var cerca_1 := 0
	var cerca_2 := 0
	var todos_cerca := true
	for pos in primera:
		var d1 := pos.distance_to(_h(1).global_position)
		var d2 := pos.distance_to(_h(2).global_position)
		if d1 < d2:
			cerca_1 += 1
		else:
			cerca_2 += 1
		todos_cerca = todos_cerca and minf(d1, d2) <= _battle.radio_emergentes + 0.01
	_ok("salen alrededor de los dos (%d y %d de 8)" % [cerca_1, cerca_2], cerca_1 > 0 and cerca_2 > 0)
	_ok("y siempre a menos del radio del que les toco", todos_cerca)
	_h(1).global_position = antes_1
	_h(2).global_position = antes_2


func _probar_drop_in() -> void:
	_ok("arranca con un solo healer", get_nodes_in_group("healer").size() == 1)
	_ok("sin el 2", not _battle.tiene_jugador(2) and _battle.healer_de(2) == null)
	_ok("la telemetria mira a uno", _battle.telemetria().resumen()["jugadores"] == 1)
	_battle._unhandled_input(accion(&"p1_ligera"))
	_ok("un boton del 1 no suma a nadie", not _battle.tiene_jugador(2))
	_battle._unhandled_input(_soltada(&"p2_ligera"))
	_ok("soltar uno del 2 tampoco", not _battle.tiene_jugador(2))
	_battle._unhandled_input(accion(&"p2_ligera"))
	_ok("apretar p2_ligera suma al 2", _battle.tiene_jugador(2))
	var h2 := _h(2)
	_ok("y avisa con jugador_agregado", _agregados.size() == 1 and _agregados[0] == h2)
	if h2 == null:
		return
	_ok("ahora son dos en el grupo", get_nodes_in_group("healer").size() == 2)
	_ok("es el jugador 2, con su tinte", h2.jugador == 2
		and h2.tinte_jugador.is_equal_approx(Jugadores.tinte(2)))
	_ok("entra al lado del 1 (%s)" % h2.global_position,
		h2.global_position.is_equal_approx(_h(1).global_position + LADO_DEL_1))
	_ok("con los movimientos del encuentro", _combos(h2).movimientos.size() == 1)
	_ok("con la vida y el mana llenos", h2.vida == h2.vida_maxima and h2.mana == h2.mana_maximo)
	_battle._unhandled_input(accion(&"p2_ligera"))
	_ok("apretar de nuevo no suma otro",
		get_nodes_in_group("healer").size() == 2 and _agregados.size() == 1)
	var r: Dictionary = _battle.telemetria().resumen()
	_ok("la telemetria lo mira desde que entro",
		r["jugadores"] == 2 and r["usos_por_jugador"].get(2, -1) == 0)


func _probar_usos_del_2() -> void:
	print("--- lo que hace el 2 queda a su nombre ---")
	var h2 := _h(2)
	if h2 == null:
		return
	var paciente := _primer_aliado()
	paciente.vida = paciente.vida_maxima * 0.5
	h2.global_position = paciente.global_position - Vector3(0.6, 0.0, 0.0)
	h2._sprite.flip_h = false
	h2.mana = h2.mana_maximo
	_ok("la ligera del 2 sale", h2.pulsar(&"ligera"))
	var r: Dictionary = _battle.telemetria().resumen()
	_ok("usos_por_jugador[2] sube a 1 (%s)" % r["usos_por_jugador"],
		r["usos_por_jugador"].get(2, 0) == 1)
	_ok("y el 1 sigue en 0", r["usos_por_jugador"].get(1, -1) == 0)
	var evento := _ultimo_evento(&"movimiento")
	_ok("el evento del movimiento dice que fue el 2", evento.get("jugador", 0) == 2)

	_battle.reiniciar_encuentro()
	r = _battle.telemetria().resumen()
	_ok("reiniciar deja a los dos en cero (%s)" % r["usos_por_jugador"],
		r["usos_por_jugador"] == {1: 0, 2: 0})
	_ok("sin olvidarse de ninguno", r["jugadores"] == 2)


func _probar_drop_in_terminada() -> void:
	_ok("el encuentro termino sin el 2", not _battle.tiene_jugador(2))
	# Por el viewport, como llega de verdad: los hijos de la batalla lo ven
	# antes que ella, asi que el healer que entra no llega a recibirlo.
	root.push_input(accion(&"p2_saltar"))
	_ok("con el cartel del final, un boton del 2 lo suma", _battle.tiene_jugador(2))
	_ok("y avisa", _agregados.size() == 1)
	var h2 := _h(2)
	if h2 == null:
		return
	_ok("el boton que lo sumo no lo hace saltar", not h2.esta_en_el_aire())
	_battle._unhandled_input(accion(&"reiniciar"))
	_ok("reiniciar arranca el encuentro con los dos",
		not _battle.esta_terminada() and get_nodes_in_group("healer").size() == 2)
	_ok("cada uno en su lugar de inicio",
		_h(1).global_position.is_equal_approx(Vector3(15.0, 0.0, 5.0))
			and h2.global_position.is_equal_approx(Vector3(15.0, 0.0, 5.0) + LADO_DEL_1))


# --- Ayudas -------------------------------------------------------------------

## Instancia la batalla con el encuentro 1 y se engancha a sus avisos antes de
## su _ready. Si habia otra, la libera: una por vez, asi el grupo "healer" solo
## tiene a los de la batalla en curso.
func _armar_batalla() -> void:
	if _battle != null:
		_battle.free()
	_camara = null
	_avisos.clear()
	_agregados.clear()
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	_battle.encuentro = load(E1)
	_battle.jugador_agregado.connect(func(h: Healer3D) -> void:
		_agregados.append(h)
		_avisos.append("jugador_agregado:%d" % h.jugador))
	_battle.encuentro_iniciado.connect(func(_e: Encuentro, _s: int, _i: int) -> void:
		_avisos.append("encuentro_iniciado"))
	root.add_child(_battle)


func _h(jugador: int) -> Healer3D:
	return _battle.healer_de(jugador)


func _combos(healer: Healer3D) -> ComponenteCombos:
	return healer.get_node("Combos")


## Aprieta o suelta una accion por Input, como un teclado: el healer la lee con
## Input.get_vector en su tick. Se vacia el buffer en el acto para que el
## estado ya valga en este mismo tick.
func _mantener(nombre: StringName, apretada: bool) -> void:
	var evento := InputEventAction.new()
	evento.action = nombre
	evento.pressed = apretada
	Input.parse_input_event(evento)
	Input.flush_buffered_events()


func _soltada(nombre: StringName) -> InputEventAction:
	var evento := accion(nombre)
	evento.pressed = false
	return evento


func _en_rango(x: float, rango: Vector2) -> bool:
	return x >= rango.x - 0.05 and x <= rango.y + 0.05


## Donde marca el suelo una tanda de emergentes sembrada con esa semilla. Las
## marcas se liberan en el acto: no llegan a sacar ningun enemigo.
func _emergentes(semilla: int) -> Array[Vector3]:
	_battle.sembrar(semilla)
	var posiciones: Array[Vector3] = []
	for i in 8:
		_battle._lanzar_emergentes()
		var marca: Node = _battle.get_child(_battle.get_child_count() - 1)
		if marca is Emergente3D:
			posiciones.append((marca as Emergente3D).position)
			marca.free()
	return posiciones


func _primer_aliado() -> Unidad3D:
	for u in get_nodes_in_group("aliados"):
		if u.esta_viva() and not u.is_queued_for_deletion():
			return u
	return null


func _ultimo_evento(nombre: StringName) -> Dictionary:
	var eventos: Array[Dictionary] = _battle.telemetria().eventos()
	for i in range(eventos.size() - 1, -1, -1):
		if eventos[i].get("evento", &"") == nombre:
			return eventos[i]
	return {}
