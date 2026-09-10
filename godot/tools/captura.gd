extends SceneTree
## Corre la batalla y saca capturas en momentos reales de reloj, forzando el
## apuntado y alguna habilidad para revisar el feedback visual sin mouse.

var _inicio_ms := 0
var _paso := 0
var _battle: Node
var _healer: Healer
var _componente: ComponenteHabilidades


func _initialize() -> void:
	_battle = load("res://scenes/battle.tscn").instantiate()
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
				_capturar(t, "cap_01_batalla.png")
		1:
			if t >= 6.0:
				# Lo acerco al frente y le hago apuntar: asi se ve el resaltado.
				_healer.global_position = _posicion_del_frente()
				_apuntar_al_mas_cercano()
				_capturar(t, "cap_02_apuntando.png")
		2:
			if t >= 6.5:
				_apuntar_al_mas_cercano()
				_componente.intentar(_componente.habilidad_en(0))  # curar
				_paso += 1
		3:
			# get_texture() devuelve el frame ya renderizado: si capturara en el
			# mismo frame de la accion, veria el estado anterior.
			if t >= 6.75:
				_capturar(t, "cap_03_curando.png")
		4:
			if t >= 7.4:
				_componente.intentar(_componente.habilidad_en(2))  # oleada
				_paso += 1
		5:
			if t >= 7.7:
				_capturar(t, "cap_04_oleada.png")
		6:
			if t >= 14.0:
				_capturar(t, "cap_05_avanzada.png")
				return true
	return false


func _capturar(t: float, nombre: String) -> void:
	root.get_texture().get_image().save_png("user://" + nombre)
	print("%4.1f  %7d  %8d   -> %s" % [t, _vivos("aliados"), _vivos("enemigos"), nombre])
	_paso += 1


func _posicion_del_frente() -> Vector2:
	var suma := 0.0
	var cuenta := 0
	for u in root.get_tree().get_nodes_in_group("aliados"):
		if u.esta_viva():
			suma += u.global_position.x
			cuenta += 1
	if cuenta == 0:
		return _healer.global_position
	return Vector2(suma / cuenta - 60.0, 235.0)


func _apuntar_al_mas_cercano() -> void:
	var mejor: Unidad = null
	var mejor_d := INF
	for u: Unidad in root.get_tree().get_nodes_in_group("aliados"):
		if not u.esta_viva():
			continue
		var d := _healer.global_position.distance_to(u.global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = u
	if mejor == null:
		return
	if _healer._apuntada != null and is_instance_valid(_healer._apuntada):
		_healer._apuntada.resaltada = false
	_healer._apuntada = mejor
	mejor.resaltada = true
	mejor.resaltada_alcanzable = _healer.en_rango(mejor)
	# Le bajo la vida para que la barra muestre un herido de verdad.
	mejor.vida = minf(mejor.vida, 26.0)
	mejor.sangrado_restante = 6.0
	mejor.queue_redraw()


func _vivos(grupo: String) -> int:
	var total := 0
	for u in root.get_tree().get_nodes_in_group(grupo):
		if u.esta_viva():
			total += 1
	return total
