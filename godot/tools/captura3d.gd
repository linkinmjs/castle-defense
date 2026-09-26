extends SceneTree
## Capturas del prototipo 3D: batalla, el aliado marcado al frente y curacion.
## Correr SIN --headless: sin ventana no hay textura que guardar.
##   godot --path godot --script res://tools/captura3d.gd

const MOVIMIENTOS: Array[String] = [
	"toque", "vendaje", "plegaria", "bendicion", "oleada", "reanimar", "impulso", "caida",
]

var _inicio_ms := 0
var _paso := 0
var _battle: Node
var _healer: Healer3D
var _paciente: Unidad3D


func _initialize() -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	root.add_child(_battle)
	_inicio_ms = Time.get_ticks_msec()
	print("t(s)  aliados  enemigos")


func _process(_delta: float) -> bool:
	if _healer == null:
		_healer = _battle.get_node_or_null("%Healer")
		if _healer == null:
			return false

	var t := (Time.get_ticks_msec() - _inicio_ms) / 1000.0

	match _paso:
		0:
			if t >= 3.0:
				_capturar(t, "3d_a_batalla.png")
		1:
			if t >= 5.8:
				# El aliado mas atrasado: frente a el al healer no le pega nadie,
				# y un golpe le cortaria el combo antes de la ultima foto.
				_paciente = _mas_atras()
				if _paciente != null:
					_healer.reiniciar(_paciente.global_position - Vector3(0.8, 0, 0))
				# La campania arranca con Toque solo; la ultima foto es una
				# Oleada, que necesita el combo entero.
				_healer.get_node("Combos").equipar(_todos())
				if _paciente != null:
					_paciente.vida = minf(_paciente.vida, 24.0)
					_paciente.sangrado_restante = 6.0
				_frente_al_paciente()
				_paso += 1
		2:
			# Un tick despues: el healer marca al que tiene al frente en su
			# paso de fisica.
			if t >= 6.0:
				_capturar(t, "3d_b_al_frente.png")
		3:
			if t >= 6.1:
				_frente_al_paciente()
				_healer.pulsar(&"ligera")
				_paso += 1
		4:
			if t >= 6.4:
				_capturar(t, "3d_c_curando.png")
		5:
			if t >= 6.55:
				_frente_al_paciente()
				_healer.pulsar(&"ligera")
				_paso += 1
		6:
			if t >= 6.95:
				_frente_al_paciente()
				_healer.pulsar(&"pesada")
				_paso += 1
		7:
			if t >= 7.2:
				_capturar(t, "3d_d_oleada.png")
				return true
	return false


func _capturar(t: float, nombre: String) -> void:
	root.get_texture().get_image().save_png("user://" + nombre)
	print("%4.1f  %7d  %8d   -> %s" % [t, _vivos("aliados"), _vivos("enemigos"), nombre])
	_paso += 1


## 0.8 m detras del paciente y mirando hacia el: queda en la caja de la ligera
## aunque la linea lo haya corrido un poco desde la foto anterior.
func _frente_al_paciente() -> void:
	if _paciente == null or not is_instance_valid(_paciente):
		return
	_healer.global_position = _paciente.global_position - Vector3(0.8, 0, 0)
	_healer._sprite.flip_h = false


func _mas_atras() -> Unidad3D:
	var mejor: Unidad3D = null
	for u: Unidad3D in root.get_tree().get_nodes_in_group("aliados"):
		if not u.esta_viva() or u.esta_derribada():
			continue
		if mejor == null or u.global_position.x < mejor.global_position.x:
			mejor = u
	return mejor


func _todos() -> Array[Movimiento]:
	var lista: Array[Movimiento] = []
	for archivo in MOVIMIENTOS:
		lista.append(load("res://resources/movimientos/%s.tres" % archivo))
	return lista


func _vivos(grupo: String) -> int:
	var total := 0
	for u in root.get_tree().get_nodes_in_group(grupo):
		if u.esta_viva():
			total += 1
	return total
