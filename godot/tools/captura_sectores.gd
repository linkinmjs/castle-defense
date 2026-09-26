extends SceneTree
## Capturas de un nivel por sectores, con el encuentro de test_sectores: el
## arranque, el primer sector recien liberado con la tropa esperando en el
## limite, y ya adentro del segundo. En cada foto imprime el limite, la camara
## y donde cae en pantalla cada soldado y el healer. Correr SIN --headless:
##   godot --path godot --script res://tools/captura_sectores.gd
##
## Para no esperar la pelea entera, los zombis del primer sector quedan tirados
## al arrancar (siguen en juego, asi que el sector no se libera) y se mueren
## recien cuando la tropa llego al limite. El healer camina con sus acciones,
## como un teclado.

const PRUEBA := "res://tools/test_sectores.gd"
## Medio ancho del cuerpo en el mundo, a la altura del pecho: con el centro
## adentro y un hombro afuera, el sprite se ve cortado.
const MEDIO_CUERPO := 0.4
const ALTURA_PECHO := 1.0
## Lo que se espera despues de que el primero llega al limite, para que lleguen
## los demas; y el tope de la espera, por si la tropa no se frena.
const LLEGAN_LOS_DEMAS := 3.0
const ESPERA_MAXIMA := 30.0
## Lo que se camina dentro del segundo sector antes de la ultima foto.
const ADENTRO := 2.0

var _inicio_ms := 0
var _paso := 0
var _t_limite := -1.0
var _t_entrada := 0.0
var _battle: Node
var _camara: CamaraBatalla
var _healer: Healer3D
var _zombis: Array[Unidad3D] = []


func _initialize() -> void:
	var prueba: GDScript = load(PRUEBA)
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	_battle.encuentro = prueba.encuentro_por_sectores()
	root.add_child(_battle)
	_inicio_ms = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if _camara == null:
		_camara = _battle.get_node_or_null("%Camara")
		_healer = _battle.get_node_or_null("%Healer")
		if _camara == null:
			return false

	var t := (Time.get_ticks_msec() - _inicio_ms) / 1000.0
	match _paso:
		0:
			if t >= 1.0:
				_foto(t, "sectores_1_inicio.png")
				for zombi in _en_juego("enemigos"):
					zombi.recibir_dano(9999.0)
					zombi.derribada_restante = 60.0
					_zombis.append(zombi)
				Input.action_press(&"p1_derecha")
		1:
			if _t_limite < 0.0 and _alguno_en_su_tope():
				_t_limite = t
				print("%4.1f s  el primer escudero llega a su tope" % t)
			if (_t_limite >= 0.0 and t >= _t_limite + LLEGAN_LOS_DEMAS) or t >= ESPERA_MAXIMA:
				Input.action_release(&"p1_derecha")
				for zombi in _zombis:
					if is_instance_valid(zombi):
						zombi.derribada_restante = 0.05
				_paso += 1
		2:
			if _battle.sector_esta_liberado():
				_foto(t, "sectores_2_liberado.png")
				Input.action_press(&"p1_derecha")
		3:
			if _battle.indice_sector() == 1:
				_t_entrada = t
				print("%4.1f s  entra el sector 1" % t)
				_paso += 1
			elif t >= ESPERA_MAXIMA + 15.0:
				print("FALLA: el healer no llego a la puerta del sector 1")
				return true
		4:
			if t >= _t_entrada + ADENTRO:
				Input.action_release(&"p1_derecha")
				_foto(t, "sectores_3_adentro.png")
				return true
	return false


func _foto(t: float, nombre: String) -> void:
	root.get_texture().get_image().save_png("user://" + nombre)
	var sector: Sector = _battle.sector_activo()
	print("%4.1f s  %s -> %s" % [t, nombre, ProjectSettings.globalize_path("user://" + nombre)])
	print("  sector %d (%s)%s  limite x %.2f  camara x %.2f, ve hasta %.2f  progreso %.2f" % [
		_battle.indice_sector(), sector.titulo if sector != null else "-",
		"  LIBERADO" if _battle.sector_esta_liberado() else "",
		_battle.limite_x_actual(), _camara.x_actual(),
		_camara.x_actual() + _camara.mitad_visible(), _battle.progreso_nivel()])
	print("  healer    %s" % _en_pantalla(_healer))
	for aliado in _en_juego("aliados"):
		print("  escudero  %s  tope %.2f" % [_en_pantalla(aliado), _tope(aliado)])
	for enemigo in _en_juego("enemigos"):
		print("  zombi     %s%s" % [_en_pantalla(enemigo),
			"  (tirado)" if enemigo.esta_derribada() else ""])
	_paso += 1


## Donde esta en el mundo y como cae su cuerpo en pantalla.
func _en_pantalla(nodo: Node3D) -> String:
	var ancho := root.get_visible_rect().size.x
	var pos := nodo.global_position
	var centro := _camara.unproject_position(pos + Vector3(0.0, ALTURA_PECHO, 0.0)).x
	var izquierda := _camara.unproject_position(pos + Vector3(-MEDIO_CUERPO, ALTURA_PECHO, 0.0)).x
	var derecha := _camara.unproject_position(pos + Vector3(MEDIO_CUERPO, ALTURA_PECHO, 0.0)).x
	var estado := "en cuadro"
	if centro < 0.0 or centro > ancho:
		estado = "FUERA DE CUADRO"
	elif izquierda < 0.0 or derecha > ancho:
		estado = "CORTADO POR EL BORDE"
	return "x=%5.2f z=%4.2f  de %4.0f a %4.0f px  %s" % [pos.x, pos.z, izquierda, derecha, estado]


func _en_juego(grupo: String) -> Array[Unidad3D]:
	var lista: Array[Unidad3D] = []
	for nodo in get_nodes_in_group(grupo):
		var unidad := nodo as Unidad3D
		if unidad != null and unidad.esta_viva() and not unidad.is_queued_for_deletion():
			lista.append(unidad)
	return lista


func _alguno_en_su_tope() -> bool:
	for aliado in _en_juego("aliados"):
		if aliado.global_position.x >= _tope(aliado) - 0.05:
			return true
	return false


## Hasta donde avanza sola, o INF si Unidad3D no tiene tope: por nombre, como
## lo fija la batalla.
func _tope(aliado: Unidad3D) -> float:
	var tope: Variant = aliado.get(&"limite_avance_x")
	return tope if tope != null else INF
