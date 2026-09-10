extends SceneTree
## Capturas del healer vulnerable: aviso en el suelo, zombi emergiendo,
## barra de vida bajando y healer caido.

var _inicio_ms := 0
var _paso := 0
var _battle: Node
var _healer: Healer3D


func _initialize() -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	root.add_child(_battle)
	_inicio_ms = Time.get_ticks_msec()
	print("t(s)  vida   -> captura")


func _process(_delta: float) -> bool:
	if _healer == null:
		_healer = _battle.get_node_or_null("%Healer")
		if _healer == null:
			return false

	var t := (Time.get_ticks_msec() - _inicio_ms) / 1000.0
	match _paso:
		0:
			if t >= 2.0:
				# Forzamos dos emergentes ya, en vez de esperar al reloj.
				_battle.emergentes_por_tanda = 2
				_battle._lanzar_emergentes()
				_paso += 1
		1:
			if t >= 2.6:
				_foto(t, "am_01_aviso_suelo.png")
		2:
			if t >= 3.35:
				_foto(t, "am_02_emergiendo.png")
		3:
			if t >= 4.6:
				_healer.recibir_dano(25.0)
				_paso += 1
		4:
			if t >= 4.8:
				_foto(t, "am_03_herido.png")
		5:
			if t >= 5.2:
				_healer.recibir_dano(100.0)
				_paso += 1
		6:
			if t >= 5.9:
				_foto(t, "am_04_caido.png")
				return true
	return false


func _foto(t: float, nombre: String) -> void:
	root.get_texture().get_image().save_png("user://" + nombre)
	print("%4.1f  %5.0f  -> %s" % [t, _healer.vida, nombre])
	_paso += 1
