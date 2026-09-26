extends SceneTree
## Capturas del cooperativo: los dos healers al arrancar, el 2 empujando
## contra el borde derecho de la pantalla, el tope del empuje y el 2 en la
## fila delantera. Se tienen que ver los dos, cada uno con su tinte, y ninguno
## fuera de cuadro.
##
## El 2 camina por sus acciones, como un teclado o un joystick, y el 1 se
## queda quieto. Al tocar el borde, el 2 corre la vista despacio; cuando el 1
## queda en su propio borde, la vista no se corre mas y el 2 se frena. Despues
## baja hacia la camara: la fila delantera es el caso dificil, porque mas cerca
## de la camara entra menos ancho de campo en pantalla. En cada foto imprime
## donde cae cada healer en pantalla. Correr SIN --headless:
##   godot --path godot --script res://tools/captura_coop.gd

const E1 := "res://resources/encuentros/e1_mantener_linea.tres"
## Medio ancho del cuerpo del healer en el mundo, a la altura del pecho: con
## el centro adentro y un hombro afuera, el sprite se ve cortado.
const MEDIO_CUERPO := 0.4
const ALTURA_PECHO := 1.0
## Segundos de empuje antes de la segunda foto, y hasta la tercera.
const EMPUJANDO := 1.0
const HASTA_EL_TOPE := 5.0
## Lo que tarda el 2 en bajar hasta la fila delantera, con margen.
const BAJANDO := 1.5

var _inicio_ms := 0
var _paso := 0
var _t_borde := 0.0
var _battle: Node
var _camara: CamaraBatalla


func _initialize() -> void:
	# Lo que haria el menu al elegir dos jugadores.
	Jugadores.pedir_cantidad(self, 2)
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	_battle.encuentro = load(E1)
	root.add_child(_battle)
	_inicio_ms = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if _camara == null:
		_camara = _battle.get_node_or_null("%Camara")
		if _camara == null:
			return false

	var t := (Time.get_ticks_msec() - _inicio_ms) / 1000.0
	match _paso:
		0:
			if t >= 1.5:
				_foto(t, "coop_1_inicio.png")
		1:
			if t >= 2.0:
				Input.action_press(&"p2_derecha")
				_paso += 1
		2:
			var h2: Healer3D = _battle.healer_de(2)
			if h2.global_position.x >= _camara.rango_x_jugadores().y - 0.05:
				_t_borde = t
				print("%4.1f s  el 2 toca el borde derecho de la pantalla" % t)
				_paso += 1
			elif t >= 12.0:
				print("FALLA: el 2 no llego al borde de la pantalla")
				return true
		3:
			if t >= _t_borde + EMPUJANDO:
				_foto(t, "coop_2_empujando.png")
		4:
			if t >= _t_borde + HASTA_EL_TOPE:
				_foto(t, "coop_3_tope.png")
				Input.action_release(&"p2_derecha")
				Input.action_press(&"p2_abajo")
		5:
			if t >= _t_borde + HASTA_EL_TOPE + BAJANDO:
				_foto(t, "coop_4_fila_delantera.png")
				Input.action_release(&"p2_abajo")
				return true
	return false


func _foto(t: float, nombre: String) -> void:
	root.get_texture().get_image().save_png("user://" + nombre)
	var ancho := root.get_visible_rect().size.x
	var rango := _camara.rango_x_jugadores()
	print("%4.1f s  %s  camara x=%.2f  rango de los jugadores [%.2f, %.2f]  pantalla %.0f px" % [
		t, nombre, _camara.x_actual(), rango.x, rango.y, ancho])
	for jugador in [1, 2]:
		var healer: Healer3D = _battle.healer_de(jugador)
		if healer == null:
			print("  jugador %d: no esta" % jugador)
			continue
		var pos := healer.global_position
		var centro := _camara.unproject_position(pos + Vector3(0.0, ALTURA_PECHO, 0.0)).x
		var izquierda := _camara.unproject_position(pos + Vector3(-MEDIO_CUERPO, ALTURA_PECHO, 0.0)).x
		var derecha := _camara.unproject_position(pos + Vector3(MEDIO_CUERPO, ALTURA_PECHO, 0.0)).x
		var estado := "en cuadro"
		if centro < 0.0 or centro > ancho:
			estado = "FUERA DE CUADRO"
		elif izquierda < 0.0 or derecha > ancho:
			estado = "CORTADO POR EL BORDE"
		print("  jugador %d: x=%.2f z=%.2f  tinte=%s  cuerpo en pantalla de %.0f a %.0f px  %s" % [
			jugador, pos.x, pos.z, healer.tinte_jugador.to_html(false), izquierda, derecha, estado])
	_paso += 1
