extends SceneTree
## Capturas de camara y salto. En cada foto imprime la rotacion de la camara
## y la distancia entre lo que mira y el healer: si la rotacion no cambia
## mientras el healer se mueve, la camara ya no se ladea.

var _inicio_ms := 0
var _paso := 0
var _battle: Node
var _healer: Healer3D
var _camara: Camera3D


func _initialize() -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	root.add_child(_battle)
	_inicio_ms = Time.get_ticks_msec()
	print("t(s)  rot.camara            cam.x   healer.x  healer.y")


func _process(_delta: float) -> bool:
	if _healer == null:
		_healer = _battle.get_node_or_null("%Healer")
		_camara = _battle.get_node_or_null("%Camara")
		if _healer == null:
			return false

	var t := (Time.get_ticks_msec() - _inicio_ms) / 1000.0
	match _paso:
		0:
			if t >= 1.5:
				_foto(t, "mov_01_quieto.png")
		1:
			if t >= 2.0:
				Input.action_press("move_right")
				_paso += 1
		2:
			if t >= 2.6:
				# Pasito corto: deberia quedar dentro de la zona muerta.
				_foto(t, "mov_02_pasito.png")
		3:
			if t >= 4.5:
				# Ya salio de la zona muerta: la camara lo sigue, sin rotar.
				_foto(t, "mov_03_siguiendo.png")
				Input.action_release("move_right")
		4:
			if t >= 5.2:
				_healer.saltar()
				_paso += 1
		5:
			if t >= 5.5:
				_foto(t, "mov_04_saltando.png")
		6:
			if t >= 6.3:
				_foto(t, "mov_05_aterrizo.png")
				return true
	return false


func _foto(t: float, nombre: String) -> void:
	root.get_texture().get_image().save_png("user://" + nombre)
	var r := _camara.rotation_degrees
	print("%4.1f  (%6.2f, %6.2f, %6.2f)  %6.2f  %8.2f  %8.2f   -> %s" % [
		t, r.x, r.y, r.z, _camara.global_position.x,
		_healer.global_position.x, _healer.global_position.y, nombre])
	_paso += 1
