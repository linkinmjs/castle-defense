extends SceneTree
## Capturas de las pantallas de menu y del HUD.
##
## Las pruebas dicen que los botones existen; esto dice si se ven bien. Correr
## SIN --headless: sin ventana no hay textura que guardar.
##   godot --path godot --script res://tools/captura_ui.gd
##   godot --path godot --script res://tools/captura_ui.gd --resolution 1920x1080
## Cada foto lleva el ancho de la ventana al final del nombre: las dos
## resoluciones no se pisan.
##
## El menu se mira en sus cuatro vistas (botonera, lecciones, controles y
## opciones), con el fondo corriendose detras.
##
## El HUD se mira dos veces sobre la batalla: con un jugador (la esquina del
## segundo lo invita a entrar y su leyenda no esta) y con dos, cada uno curando
## a un herido distinto, para ver las dos fichas y las dos marcas.

var _menu: Control
var _pausa: CanvasLayer
var _battle: Node
var _hud: CanvasLayer
var _h1: Healer3D
var _h2: Healer3D
## A quien cura cada uno. Se eligen una sola vez: entre una foto y la otra la
## linea se mueve, y el orden de quien esta mas atras puede cambiar.
var _heridos: Array[Unidad3D] = []
var _inicio := 0
var _paso := 0
## El tamano de ventana pedido con --resolution. El menu aplica las opciones
## guardadas al arrancar y la achica a la resolucion elegida ahi: se vuelve a
## poner la pedida, sin guardar nada.
var _ventana := Vector2i.ZERO


func _initialize() -> void:
	# --resolution no llega a OS.get_cmdline_args() (lo consume el motor), pero
	# la ventana ya arranca con ese tamano: es el que hay que conservar.
	_ventana = DisplayServer.window_get_size()
	_menu = load("res://scenes/ui/menu_principal.tscn").instantiate()
	root.add_child(_menu)
	_inicio = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	var t := (Time.get_ticks_msec() - _inicio) / 1000.0

	# El menu achica la ventana al aplicar las opciones guardadas, y el sistema
	# lo resuelve unos cuadros despues: se insiste hasta que quede la pedida.
	if _ventana != Vector2i.ZERO and DisplayServer.window_get_size() != _ventana and t < 0.6:
		DisplayServer.window_set_size(_ventana)

	match _paso:
		0:
			if t >= 0.8:
				_tomar("ui_1_menu.png", "menu principal")
		1:
			if t >= 1.2:
				_menu.get_node("%Lecciones_boton").pressed.emit()
				_paso += 1
		2:
			if t >= 1.8:
				_tomar("ui_2_lecciones.png", "lista de lecciones")
		3:
			if t >= 2.2:
				_menu.get_node("%VolverLecciones").pressed.emit()
				_menu.get_node("%Controles_boton").pressed.emit()
				_paso += 1
		4:
			if t >= 2.8:
				_tomar("ui_3_controles.png", "tabla de controles")
		5:
			if t >= 3.0:
				_menu.get_node("%VolverControles").pressed.emit()
				_menu.get_node("%Opciones_boton").pressed.emit()
				_paso += 1
		6:
			if t >= 3.6:
				_tomar("ui_3b_opciones.png", "opciones")
		7:
			if t >= 3.8:
				# El HUD y la pausa se miran sobre la batalla, que es donde viven.
				_menu.queue_free()
				_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
				# Una batalla que todavia no deja entrar a nadie con el encuentro
				# andando no tiene jugador_agregado, y sin eso el HUD no invita
				# al segundo. Se le agrega para ver donde cae la invitacion.
				if not _battle.has_signal(&"jugador_agregado"):
					_battle.add_user_signal("jugador_agregado",
						[{"name": "healer", "type": TYPE_OBJECT}])
				root.add_child(_battle)
				_paso += 1
		8:
			if t >= 5.1:
				_hud = _battle.get_node("%HUD")
				_h1 = _battle.get_node("%Healer")
				_heridos = _dos_heridos()
				_curar(_h1, _heridos[0])
				_paso += 1
		9:
			if t >= 5.3:
				_tomar("ui_4_hud_un_jugador.png", "HUD con un jugador")
		10:
			if t >= 5.6:
				_sumar_segundo()
				_paso += 1
		11:
			if t >= 5.85:
				_tomar("ui_5_hud_dos_jugadores.png", "HUD con dos jugadores")
		12:
			if t >= 6.2:
				_pausa = _battle.get_node("%MenuPausa")
				_pausa.abrir()
				_paso += 1
		13:
			if t >= 6.9:
				_tomar("ui_6_pausa.png", "menu de pausa")
		14:
			if t >= 7.3:
				_pausa.get_node("%OpcionesBoton").pressed.emit()
				_paso += 1
		15:
			if t >= 7.9:
				_tomar("ui_7_pausa_opciones.png", "opciones desde la pausa")
		16:
			# Sin esto el arbol queda pausado y el proceso no cierra bien.
			_pausa.cerrar()
			print("listo")
			return true
	return false


## El segundo healer entra como lo haria por la batalla: el HUD lo recibe con
## seguir(), igual que desde jugador_agregado.
func _sumar_segundo() -> void:
	_h2 = load("res://scenes/3d/healer3d.tscn").instantiate()
	_h2.name = "Healer2"
	_h2.jugador = 2
	_h2.tinte_jugador = OverlayUnidades.color_jugador(2).lightened(0.4)
	_h2.limites = _h1.limites
	_battle.get_node("%Unidades").add_child(_h2)
	_hud.seguir(_h2)
	_curar(_h2, _heridos[1])


## Se para 0.8 m detras del herido, mirando hacia el, y aprieta la ligera.
func _curar(healer: Healer3D, herido: Unidad3D) -> void:
	herido.vida = herido.vida_maxima * 0.4
	healer.global_position = herido.global_position - Vector3(0.8, 0, 0)
	healer._sprite.flip_h = false
	var salio := healer.pulsar(&"ligera")
	print("  jugador %d -> %s" % [healer.jugador, "cura" if salio else "no sale"])


## Los dos aliados de mas atras, lejos del choque, y separados entre si para
## que cada healer tenga el suyo al frente y no el del otro.
func _dos_heridos() -> Array[Unidad3D]:
	var vivos: Array[Unidad3D] = []
	for u: Unidad3D in root.get_tree().get_nodes_in_group("aliados"):
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
func _tomar(archivo: String, que: String) -> void:
	var imagen := root.get_texture().get_image()
	var nombre := "%s_%d.png" % [archivo.get_basename(), imagen.get_width()]
	imagen.save_png("user://" + nombre)
	print("  %-32s %s" % [nombre, que])
	_paso += 1
