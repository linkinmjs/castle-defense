extends SceneTree
## Capturas de las pantallas de menu y del HUD.
##
## Las pruebas dicen que los botones existen; esto dice si se ven bien. Correr
## SIN --headless: sin ventana no hay textura que guardar.
##   godot --path godot --script res://tools/captura_ui.gd
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


func _initialize() -> void:
	_menu = load("res://scenes/ui/menu_principal.tscn").instantiate()
	root.add_child(_menu)
	_inicio = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	var t := (Time.get_ticks_msec() - _inicio) / 1000.0

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
				_menu.get_node("%Opciones_boton").pressed.emit()
				_paso += 1
		4:
			if t >= 2.8:
				_tomar("ui_3_opciones.png", "opciones")
		5:
			if t >= 3.2:
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
		6:
			if t >= 4.5:
				_hud = _battle.get_node("%HUD")
				_h1 = _battle.get_node("%Healer")
				_heridos = _dos_heridos()
				_curar(_h1, _heridos[0])
				_paso += 1
		7:
			if t >= 4.7:
				_tomar("ui_4_hud_un_jugador.png", "HUD con un jugador")
		8:
			if t >= 5.0:
				_sumar_segundo()
				_paso += 1
		9:
			if t >= 5.25:
				_tomar("ui_5_hud_dos_jugadores.png", "HUD con dos jugadores")
		10:
			if t >= 5.6:
				_pausa = _battle.get_node("%MenuPausa")
				_pausa.abrir()
				_paso += 1
		11:
			if t >= 6.3:
				_tomar("ui_6_pausa.png", "menu de pausa")
		12:
			if t >= 6.7:
				_pausa.get_node("%OpcionesBoton").pressed.emit()
				_paso += 1
		13:
			if t >= 7.3:
				_tomar("ui_7_pausa_opciones.png", "opciones desde la pausa")
		14:
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


func _tomar(archivo: String, que: String) -> void:
	root.get_texture().get_image().save_png("user://" + archivo)
	print("  %-28s %s" % [archivo, que])
	_paso += 1
