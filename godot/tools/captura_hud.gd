extends SceneTree
## Capturas del HUD sobre una batalla de dos jugadores.
##
## Las pruebas dicen que cada pieza reacciona; esto dice si se lee y si tapa
## el campo. Correr SIN --headless (sin ventana no hay textura que guardar):
##   godot --path godot --script res://tools/captura_hud.gd
##   godot --path godot --script res://tools/captura_hud.gd --resolution 1920x1080
##
## Fotos, con el ancho de la ventana al final del nombre:
##   hud_1_arranque: el encabezado del encuentro entrando.
##   hud_2_combo: el 1 tras ligera, ligera (la raya de la ventana y el
##     Vendaje enfriandose).
##   hud_3_plegaria: el 1 rezando la plegaria (la barra de carga).
##   hud_4_resumen: el final, con el resumen ya contado.
##   hud_5_sector_jefe: lo que todavia no manda la batalla de esta rama,
##     simulado desde afuera: el cartel de avanzar, el anuncio de un sector y
##     la barra de un jefe.

var _battle: Node
var _hud: CanvasLayer
var _h1: Healer3D
var _h2: Healer3D
var _heridos: Array[Unidad3D] = []
## Cuando se vio el primer cuadro de la batalla: los tiempos cuentan desde
## ahi, no desde que se cargo (el primer cuadro compila sombreadores).
var _inicio: int = -1
var _paso := 0


class SectorDeMuestra extends Resource:
	var titulo := "Puente"
	var x_fin := 19.0


func _initialize() -> void:
	Jugadores.pedir_cantidad(self, 2)
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	root.add_child(_battle)


func _process(_delta: float) -> bool:
	if _inicio < 0:
		_inicio = Time.get_ticks_msec()
		_hud = _battle.get_node("%HUD")
		_h1 = _battle.get_node("%Healer")
		_h2 = _battle.call(&"healer_de", 2)
		# Ningun encuentro de la campania entrega todavia la pesada: para ver
		# la tarjeta entera y la plegaria, los dos van con el juego completo.
		for healer in [_h1, _h2]:
			if healer != null:
				(healer.get_node("Combos") as ComponenteCombos).equipar(_juego_completo())
		return false
	var t := (Time.get_ticks_msec() - _inicio) / 1000.0

	match _paso:
		0:
			# A mitad de la entrada del titulo (0.4 s).
			if t >= 0.22:
				_tomar("hud_1_arranque", "el encabezado entrando")
		1:
			if t >= 1.0:
				_heridos = _dos_heridos()
				_ubicar(_h1, _heridos[0])
				_ubicar(_h2, _heridos[1])
				_pulsar(_h1, &"ligera")
				_pulsar(_h2, &"ligera")
				_paso += 1
		2:
			if t >= 1.4:
				_pulsar(_h1, &"ligera")
				_paso += 1
		3:
			# El Vendaje (0.35 s de enfriamiento) todavia con el velo, y la
			# ventana del combo recien abierta.
			if t >= 1.5:
				_tomar("hud_2_combo", "L, L: raya del combo y enfriamiento")
		4:
			# La ventana ya se cerro: la pesada sola es la Plegaria.
			if t >= 2.35:
				_ubicar(_h1, _heridos[0])
				_pulsar(_h1, &"pesada")
				_paso += 1
		5:
			if t >= 2.6:
				_tomar("hud_3_plegaria", "la plegaria cargando")
		6:
			# Despues del cartel del encuentro (0.4 + 3 + 0.35 s): un sector
			# anunciado antes esperaria su turno.
			if t >= 3.9:
				_simular_sector_y_jefe()
				_paso += 1
		7:
			if t >= 4.45:
				_tomar("hud_5_sector_jefe", "avanzar, sector y jefe simulados")
		8:
			if t >= 4.7:
				if _battle.has_method(&"_terminar"):
					_battle.call(&"_terminar", true)
				else:
					_battle.emit_signal(&"batalla_terminada", true)
				_paso += 1
		9:
			# El resumen cuenta sus numeros en 0.8 s.
			if t >= 6.0:
				_tomar("hud_4_resumen", "el resumen final")
		10:
			print("listo")
			return true
	return false


## Todos los movimientos, en el orden de la escena del healer.
func _juego_completo() -> Array[Movimiento]:
	var lista: Array[Movimiento] = []
	for nombre in ["toque", "vendaje", "plegaria", "bendicion", "oleada", "reanimar",
			"impulso", "caida"]:
		lista.append(load("res://resources/movimientos/%s.tres" % nombre))
	return lista


## Lo que la batalla de otras ramas va a mandar sola, mandado a mano.
func _simular_sector_y_jefe() -> void:
	_hud.cartel_avanzar().mostrar()
	_hud.encabezado().mostrar_sector(1, SectorDeMuestra.new())
	var enemigos := get_nodes_in_group("enemigos")
	if enemigos.is_empty():
		return
	var jefe := enemigos[0] as Unidad3D
	jefe.nombre_unidad = "Ogro"
	_hud.barra_jefe().seguir_jefe(jefe)
	# Un golpe grande despues de entrar: se ve el fantasma.
	await create_timer(0.3).timeout
	if is_instance_valid(jefe):
		jefe.vida = jefe.vida_maxima * 0.55


## Lo pone 0.8 m detras del herido, mirando hacia el.
func _ubicar(healer: Healer3D, herido: Unidad3D) -> void:
	if healer == null or herido == null or not is_instance_valid(herido):
		return
	herido.vida = minf(herido.vida, herido.vida_maxima * 0.4)
	healer.global_position = herido.global_position - Vector3(0.8, 0, 0)
	healer._sprite.flip_h = false


func _pulsar(healer: Healer3D, entrada: StringName) -> void:
	if healer == null:
		return
	var salio := healer.pulsar(entrada)
	print("  jugador %d %s -> %s" % [healer.jugador, entrada, "sale" if salio else "no sale"])


## Los dos aliados de mas atras, lejos del choque, y separados entre si para
## que cada healer tenga el suyo al frente y no el del otro.
func _dos_heridos() -> Array[Unidad3D]:
	var vivos: Array[Unidad3D] = []
	for u: Unidad3D in get_nodes_in_group("aliados"):
		if u.esta_viva() and not u.esta_derribada():
			vivos.append(u)
	vivos.sort_custom(func(a: Unidad3D, b: Unidad3D) -> bool:
		return a.global_position.x < b.global_position.x)
	var segundo := vivos[vivos.size() - 1]
	for u in vivos:
		if u != vivos[0] and u.global_position.distance_to(vivos[0].global_position) > 2.6:
			segundo = u
			break
	return [vivos[0], segundo]


## El ancho va en el nombre, leido de la imagen: la ventana puede no ser la
## pedida (a 1920x1080 la barra de tareas la deja en 1920x1050).
func _tomar(nombre: String, que: String) -> void:
	var imagen := root.get_texture().get_image()
	var archivo := "%s_%d.png" % [nombre, imagen.get_width()]
	imagen.save_png("user://" + archivo)
	print("  %-32s %s" % [archivo, que])
	_paso += 1
