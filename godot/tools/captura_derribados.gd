extends SceneTree
## Capturas de derribado, reanimacion, indicador de frente y victoria.
## Correr SIN --headless: sin ventana no hay textura que guardar.

var _inicio_ms := 0
var _paso := 0
var _battle: Node
var _healer: Healer3D
var _aliado: Unidad3D


func _initialize() -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	root.add_child(_battle)
	_inicio_ms = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if _healer == null:
		_healer = _battle.get_node_or_null("%Healer")
		if _healer == null:
			return false

	var t := (Time.get_ticks_msec() - _inicio_ms) / 1000.0
	match _paso:
		0:
			if t >= 2.0:
				# La campania arranca con Toque solo: sin Reanimar equipado la
				# pesada no levantaria a nadie.
				var combos: ComponenteCombos = _healer.get_node("Combos")
				combos.equipar([load("res://resources/movimientos/toque.tres"),
					load("res://resources/movimientos/reanimar.tres")] as Array[Movimiento])
				_aliado = _mas_cercano()
				_aliado.probabilidad_sangrado = 0.0
				_aliado.recibir_dano(500.0)
				_frente_al_aliado()
				_paso += 1
		1:
			if t >= 2.6:
				_foto("de_01_derribado.png")
		2:
			if t >= 3.2:
				# Con un derribado al frente, la pesada es Reanimar.
				_frente_al_aliado()
				_healer.pulsar(&"pesada")
				_paso += 1
		3:
			if t >= 3.5:
				_foto("de_02_reanimado.png")
		4:
			if t >= 4.2:
				var vivo := _mas_cercano()
				vivo.global_position.x = _battle.base_enemiga_x - 0.5
				_paso += 1
		5:
			if t >= 4.9:
				_foto("de_03_victoria.png")
				return true
	return false


## 1.6 m detras del caido, mirando hacia el: dentro de la caja de la pesada.
func _frente_al_aliado() -> void:
	_healer.global_position = _aliado.global_position + Vector3(-1.6, 0, 0.3)
	_healer._sprite.flip_h = false


func _mas_cercano() -> Unidad3D:
	var mejor: Unidad3D = null
	var mejor_d := INF
	for u: Unidad3D in root.get_tree().get_nodes_in_group("aliados"):
		if not u.esta_viva() or u.esta_derribada():
			continue
		var d := _healer.global_position.distance_to(u.global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = u
	return mejor


func _foto(nombre: String) -> void:
	root.get_texture().get_image().save_png("user://" + nombre)
	print("-> %s   vida aliado=%.0f  derribado=%s  terminada=%s" % [
		nombre, _aliado.vida, _aliado.esta_derribada(), _battle._terminada])
	_paso += 1
