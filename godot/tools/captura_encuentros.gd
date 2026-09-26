extends SceneTree
## Capturas de la vertical de aprendizaje: como se ve cada encuentro, la
## tarjeta del que el healer tiene al frente y el resumen del final.
##
## Sirve para mirar lo que el jugador mira. Las pruebas dicen que los numeros
## estan bien, pero no si la pantalla se entiende. Correr SIN --headless.

var _battle: Node
var _healer: Healer3D
var _inicio_ms := 0
var _paso := 0
var _paciente: Unidad3D


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
				_avanzar(t, "enc_1_arranque.png")
		1:
			# Pararse frente a un herido: es cuando aparece la tarjeta.
			if t >= 3.8:
				_paciente = _mas_herido()
				if _paciente != null:
					_paciente.vida = _paciente.vida_maxima * 0.45
				_frente_al_paciente()
				_paso += 1
		2:
			# La marca y la tarjeta salen en el tick de fisica siguiente.
			if t >= 4.0:
				_frente_al_paciente()
				_avanzar(t, "enc_2_tarjeta.png")
		3:
			if t >= 5.0:
				# Terminar el encuentro para ver el resumen.
				_battle.tiempo_encuentro = _battle._actual.duracion
				_paso += 1
		4:
			if t >= 6.0:
				_avanzar(t, "enc_3_resumen.png")
		5:
			if t >= 6.5:
				_battle.avanzar_encuentro()
				_paso += 1
		6:
			if t >= 8.0:
				_avanzar(t, "enc_4_segundo.png")
		7:
			if t >= 8.5:
				_battle.avanzar_encuentro()
				_paso += 1
		8:
			# El tercero arranca con dos lanceros sangrando: frente a uno se ve
			# la tarjeta con el reloj del sangrado y los dos movimientos.
			if t >= 9.8:
				_paciente = _primer_sangrando()
				_frente_al_paciente()
				_paso += 1
		9:
			if t >= 10.0:
				_frente_al_paciente()
				_avanzar(t, "enc_5_sangrado.png")
		10:
			print("listo")
			return true
	return false


func _avanzar(t: float, nombre: String) -> void:
	var titulo: String = _battle._actual.titulo if _battle._actual != null else "-"
	root.get_texture().get_image().save_png("user://" + nombre)
	print("%4.1fs  %-22s -> %s" % [t, titulo, nombre])
	_paso += 1


## 0.8 m detras del paciente y mirando hacia el: el que recibiria la ligera.
func _frente_al_paciente() -> void:
	if _paciente == null or not is_instance_valid(_paciente):
		return
	_healer.global_position = _paciente.global_position - Vector3(0.8, 0, 0)
	_healer._sprite.flip_h = false


func _mas_herido() -> Unidad3D:
	var peor: Unidad3D = null
	for u in get_nodes_in_group("aliados"):
		if not u.esta_viva() or u.is_queued_for_deletion():
			continue
		if peor == null or u.vida < peor.vida:
			peor = u
	return peor


func _primer_sangrando() -> Unidad3D:
	for u in get_nodes_in_group("aliados"):
		if u.esta_sangrando() and not u.is_queued_for_deletion():
			return u
	return _mas_herido()
