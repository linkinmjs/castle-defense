extends SceneTree
## Capturas del prototipo 3D: batalla, apuntado y curacion.

var _inicio_ms := 0
var _paso := 0
var _battle: Node
var _healer: Healer3D
var _componente: ComponenteHabilidades


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
		_componente = _healer.get_node("Habilidades")

	var t := (Time.get_ticks_msec() - _inicio_ms) / 1000.0

	match _paso:
		0:
			if t >= 3.0:
				_capturar(t, "3d_a_batalla.png")
		1:
			if t >= 6.0:
				_healer.global_position = _frente() - Vector3(2.0, 0, 0)
				_apuntar()
				_capturar(t, "3d_b_apuntando.png")
		2:
			if t >= 6.6:
				_apuntar()
				_componente.intentar(_componente.habilidad_en(0))
				_paso += 1
		3:
			if t >= 6.9:
				_capturar(t, "3d_c_curando.png")
		4:
			if t >= 7.6:
				_componente.intentar(_componente.habilidad_en(2))
				_paso += 1
		5:
			if t >= 7.9:
				_capturar(t, "3d_d_oleada.png")
				return true
	return false


func _capturar(t: float, nombre: String) -> void:
	root.get_texture().get_image().save_png("user://" + nombre)
	print("%4.1f  %7d  %8d   -> %s" % [t, _vivos("aliados"), _vivos("enemigos"), nombre])
	_paso += 1


func _frente() -> Vector3:
	var suma := 0.0
	var cuenta := 0
	for u in root.get_tree().get_nodes_in_group("aliados"):
		if u.esta_viva():
			suma += u.global_position.x
			cuenta += 1
	if cuenta == 0:
		return _healer.global_position
	return Vector3(suma / cuenta, 0, 5.0)


func _apuntar() -> void:
	var mejor: Unidad3D = null
	var mejor_d := INF
	for u: Unidad3D in root.get_tree().get_nodes_in_group("aliados"):
		if not u.esta_viva():
			continue
		var d := _healer.global_position.distance_to(u.global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = u
	if mejor == null:
		return
	_healer._apuntada = mejor
	mejor.resaltada = true
	mejor.resaltada_alcanzable = _healer.en_rango(mejor)
	mejor.vida = minf(mejor.vida, 24.0)
	mejor.sangrado_restante = 6.0


func _vivos(grupo: String) -> int:
	var total := 0
	for u in root.get_tree().get_nodes_in_group(grupo):
		if u.esta_viva():
			total += 1
	return total
