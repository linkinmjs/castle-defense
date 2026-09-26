extends SceneTree
## Fotos del escenario de la batalla con el encuentro 1: el cielo, las capas
## del fondo, el suelo, las murallas y la luz del atardecer junto a los
## sprites. Las pruebas miden que cada capa este donde tiene que estar; esto es
## para mirar si se lee: horizonte limpio, capas que no compiten con los
## soldados, contornos de bando legibles sobre el pasto, sombras dentro del
## cuadro, murallas en escala.
##
## Correr SIN --headless (sin ventana no hay textura que guardar):
##   godot --path godot --script res://tools/captura_mundo.gd
## Deja en user://:
##   mundo_1_inicio.png          el arranque, como lo ve el jugador
##   mundo_2_derecha.png         healer y camara 6 m a la derecha: el fondo se
##                               corre menos que el campo (parallax)
##   mundo_3_1080p.png           el arranque otra vez, en 1920x1080
##   mundo_4_porton.png          la camara en la punta enemiga del campo
##   mundo_5_muralla_aliada.png  la camara en la punta aliada
##   mundo_6_90m_inicio.png y mundo_7_90m_final.png: el mundo estirado para un
##                               campo de 90 m, en las dos puntas (sin
##                               soldados: la batalla sigue en 30 m)

const E1 := "res://resources/encuentros/e1_mantener_linea.tres"
const CORRIMIENTO := 6.0

var _battle: Node
var _healer: Healer3D
var _camara: CamaraBatalla
var _mundo: Mundo
var _inicio_ms := 0
var _paso := 0
var _x_inicio := 0.0
var _camara_inicio := 0.0


func _initialize() -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	# El encuentro suelto: sin campania, no hay un segundo que lo pise.
	_battle.set("encuentro", load(E1))
	root.add_child(_battle)
	_inicio_ms = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if _healer == null:
		_healer = _battle.get_node_or_null("%Healer")
		_camara = _battle.get_node_or_null("%Camara")
		_mundo = _battle.get_node_or_null("%Mundo")
		if _healer == null or _camara == null or _mundo == null:
			return false

	var t := (Time.get_ticks_msec() - _inicio_ms) / 1000.0
	match _paso:
		0:
			# Lo que va a hacer la batalla al iniciar cada encuentro.
			_mundo.configurar(_battle.ancho_campo, _battle.profundidad_campo,
				_battle.base_aliada_x, _battle.base_enemiga_x)
			_paso += 1
		1:
			if t >= 1.5:
				_x_inicio = _healer.global_position.x
				_camara_inicio = _camara.x_actual()
				_capturar("mundo_1_inicio.png")
		2:
			_mover(CORRIMIENTO)
			_paso += 1
		3:
			if t >= 2.0:
				_capturar("mundo_2_derecha.png")
		4:
			_mover(0.0)
			root.size = Vector2i(1920, 1080)
			_paso += 1
		5:
			if t >= 2.8:
				_capturar("mundo_3_1080p.png")
		6:
			root.size = Vector2i(1280, 720)
			# La camara deja de seguir al healer y va a cada punta del campo; la
			# batalla sigue y el healer queda recortado contra el borde.
			var nadie: Array[Node3D] = []
			_camara.seguir(nadie)
			_camara.saltar_a(_battle.ancho_campo)
			_paso += 1
		7:
			if t >= 3.4:
				_capturar("mundo_4_porton.png")
		8:
			_camara.saltar_a(0.0)
			_paso += 1
		9:
			if t >= 3.9:
				_capturar("mundo_5_muralla_aliada.png")
		10:
			# Solo el mundo y la camara: la batalla sigue creyendo que el campo
			# mide 30 m. Quieta, para que no recorte al healer contra una
			# pantalla que no es la suya, y sin barras, que quedarian donde
			# estaban los soldados.
			_battle.process_mode = Node.PROCESS_MODE_DISABLED
			(_battle.get_node("%Overlay") as Control).visible = false
			_mundo.configurar(90.0, 10.0, 1.5, 88.5)
			_camara.configurar(10.0, 0.0, 90.0)
			_camara.saltar_a(0.0)
			_paso += 1
		11:
			if t >= 4.4:
				_capturar("mundo_6_90m_inicio.png")
		12:
			_camara.saltar_a(90.0)
			_paso += 1
		13:
			if t >= 4.8:
				_capturar("mundo_7_90m_final.png")
		14:
			print("listo")
			return true
	return false


## Healer y camara juntos a CORRIMIENTO del arranque (o de vuelta con 0): el
## encuadre es el mismo corrido, y lo unico que cambia es cuanto se mueve
## cada capa en pantalla.
func _mover(corrimiento: float) -> void:
	var pos := _healer.global_position
	pos.x = _x_inicio + corrimiento
	_healer.reiniciar(pos)
	_camara.saltar_a(_camara_inicio + corrimiento)


func _capturar(nombre: String) -> void:
	var imagen := root.get_texture().get_image()
	imagen.save_png("user://" + nombre)
	print("%-28s %dx%d  camara x=%.2f  healer x=%.2f" % [nombre, imagen.get_width(),
		imagen.get_height(), _camara.x_actual(), _healer.global_position.x])
	_paso += 1
