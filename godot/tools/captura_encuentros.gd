extends SceneTree
## Capturas de la vertical de aprendizaje: como se ve cada encuentro, la
## tarjeta al apuntar y el resumen del final.
##
## Sirve para mirar lo que el jugador mira. Las pruebas dicen que los numeros
## estan bien, pero no si la pantalla se entiende.

var _battle: Node
var _healer: Healer3D
var _componente: ComponenteHabilidades
var _inicio_ms := 0
var _paso := 0


func _initialize() -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	root.add_child(_battle)
	_inicio_ms = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if _healer == null:
		_healer = _battle.get_node_or_null("%Healer")
		if _healer == null:
			return false
		_componente = _healer.get_node("Habilidades")

	var t := (Time.get_ticks_msec() - _inicio_ms) / 1000.0

	match _paso:
		0:
			if t >= 2.0:
				_avanzar(t, "enc_1_arranque.png")
		1:
			# Apuntar a un herido: es cuando aparece la tarjeta.
			if t >= 4.0:
				var herido := _mas_herido()
				if herido != null:
					herido.vida = herido.vida_maxima * 0.45
					_healer.global_position = herido.global_position + Vector3(1.2, 0, 0.3)
					_apuntar(herido)
				_avanzar(t, "enc_2_tarjeta.png")
		2:
			if t >= 5.0:
				# Terminar el encuentro para ver el resumen.
				_battle.tiempo_encuentro = _battle._actual.duracion
				_paso += 1
		3:
			if t >= 6.0:
				_avanzar(t, "enc_3_resumen.png")
		4:
			if t >= 6.5:
				_battle.avanzar_encuentro()
				_paso += 1
		5:
			if t >= 8.0:
				_avanzar(t, "enc_4_segundo.png")
		6:
			if t >= 8.5:
				_battle.avanzar_encuentro()
				_paso += 1
		7:
			# El tercero arranca con dos lanceros sangrando: se apunta a uno
			# para ver la tarjeta con el reloj del sangrado y dos herramientas.
			if t >= 10.0:
				var sangrando := _primer_sangrando()
				if sangrando != null:
					_healer.global_position = sangrando.global_position + Vector3(1.2, 0, 0.3)
					_apuntar(sangrando)
				_avanzar(t, "enc_5_sangrado.png")
		8:
			print("listo")
			return true
	return false


func _avanzar(t: float, nombre: String) -> void:
	var titulo: String = _battle._actual.titulo if _battle._actual != null else "-"
	root.get_texture().get_image().save_png("user://" + nombre)
	print("%4.1fs  %-22s -> %s" % [t, titulo, nombre])
	_paso += 1


func _apuntar(unidad: Unidad3D) -> void:
	if _healer._apuntada != null and is_instance_valid(_healer._apuntada):
		_healer._apuntada.resaltada = false
	_healer._apuntada = unidad
	unidad.resaltada = true
	unidad.resaltada_alcanzable = _healer.en_rango(unidad)
	_healer.apuntada_cambio.emit(unidad)


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
