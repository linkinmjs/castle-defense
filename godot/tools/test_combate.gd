extends SceneTree
## Enfrenta dos unidades solas y registra su vida en el tiempo.
## Sirve para verificar que el dano se aplica y a que ritmo cae un soldado.

var _frames := 0
var _a: Unidad3D
var _b: Unidad3D
var _inicio_ms := 0
var _ultimo_reporte := 0.0
var _primera_baja := -1.0


func _initialize() -> void:
	var contenedor := Node3D.new()
	root.add_child(contenedor)

	var escena: PackedScene = load("res://scenes/3d/unidad3d.tscn")

	_a = escena.instantiate()
	_a.configurar(Unidad3D.Bando.ALIADO)
	_a.position = Vector3(14.5, 0, 5)
	contenedor.add_child(_a)

	_b = escena.instantiate()
	_b.configurar(Unidad3D.Bando.ENEMIGO)
	_b.position = Vector3(15.5, 0, 5)
	contenedor.add_child(_b)

	print("vida_maxima=%.0f dano=%.0f cadencia=%.2fs alcance=%.2f m" % [
		_a.vida_maxima, _a.dano, _a.cadencia, _a.alcance])
	_inicio_ms = Time.get_ticks_msec()
	print("t(s)   aliado  enemigo  dist")


func _process(_delta: float) -> bool:
	_frames += 1
	# Tiempo real de reloj: en headless el bucle de render no corre a 60 fps,
	# asi que contar frames daria una escala de tiempo falsa.
	var t := (Time.get_ticks_msec() - _inicio_ms) / 1000.0

	if t - _ultimo_reporte >= 1.0:
		_ultimo_reporte = t
		var dist := 0.0
		if is_instance_valid(_a) and is_instance_valid(_b):
			dist = _a.global_position.distance_to(_b.global_position)
		print("%5.1f  %6.0f  %7.0f  %4.2f" % [
			t,
			_a.vida if is_instance_valid(_a) else -1,
			_b.vida if is_instance_valid(_b) else -1,
			dist])

	if _primera_baja < 0.0:
		if (is_instance_valid(_a) and not _a.esta_viva()) or (is_instance_valid(_b) and not _b.esta_viva()):
			_primera_baja = t
			print(">>> primera baja a los %.1f s" % t)
			return true

	if t > 30.0:
		print(">>> nadie murio en 30 s")
		return true
	return false
