extends SceneTree
## Capturas de los tres niveles largos: el camino al arrancar, el puente con el
## oso a la vista (cargando su golpe) y las puertas frente al demonio. En cada
## foto imprime lo que muestra la camara, cuantas unidades entran en cuadro y
## si algun soldado le tapa el healer al jugador. Correr SIN --headless:
##   godot --path godot --script res://tools/captura_niveles.gd
##
## Para no jugar diez minutos, en el puente el healer camina hasta quedar
## detras de la tropa y espera a que el oso llegue y anuncie un golpe, y las
## puertas saltan al ultimo sector con la tropa ya enfrente del demonio.

const NIVELES := "res://resources/encuentros/niveles.tres"
## Medio ancho del cuerpo y altura del pecho, como en captura_sectores.
const MEDIO_CUERPO := 0.4
const ALTURA_PECHO := 1.0
## Cuanto se pisan dos cuerpos en pantalla, en fraccion del ancho del healer,
## para contar que uno tapa al otro.
const TAPA := 0.4
## Tope de cada espera, por si lo que se espera no pasa.
const ESPERA_MAXIMA := 25.0
## Hasta donde camina el healer en el puente: detras de donde la tropa se
## cruza con los zombis y el oso.
const X_HEALER_PUENTE := 12.0
## Donde se paran la tropa y el healer en las puertas: el demonio arranca en
## 62-64 y camina hacia ellos.
const X_TROPA_PUERTAS := 57.0
const X_HEALER_PUERTAS := 54.5

var _niveles: Campana
var _battle: Node
var _camara: CamaraBatalla
var _healer: Healer3D
var _paso := 0
var _desde := 0.0
var _golpe_anunciado := false


func _initialize() -> void:
	_niveles = load(NIVELES)
	_armar(0)


func _process(delta: float) -> bool:
	_desde += delta
	if _camara == null:
		_camara = _battle.get_node_or_null("%Camara")
		_healer = _battle.get_node_or_null("%Healer")
		return false

	match _paso:
		0:
			# El camino: el arranque, con la tropa y el healer en su lugar.
			if _desde >= 1.0:
				_foto("niveles_1_camino.png")
				_armar(1)
		1:
			# El puente: el healer camina hasta quedar detras de la tropa.
			if _desde >= 0.5:
				Input.action_press(&"p1_derecha")
				_siguiente()
		2:
			if _healer.global_position.x >= X_HEALER_PUENTE or _desde >= ESPERA_MAXIMA:
				Input.action_release(&"p1_derecha")
				_golpe_anunciado = false
				_siguiente()
		3:
			# Espera a que el oso llegue y anuncie un golpe: la foto va con la
			# marca en el suelo, a mitad del aviso.
			var oso := _primero(func(u: Unidad3D) -> bool: return u.telegrafiado > 0.0)
			if oso != null and not oso.golpe_anunciado.is_connected(_on_golpe):
				oso.golpe_anunciado.connect(_on_golpe)
			if _golpe_anunciado or _desde >= ESPERA_MAXIMA:
				_golpe_anunciado = false
				_desde = 0.0
				_paso = 30
		30:
			if _desde >= 0.6:
				_foto("niveles_2_puente_oso.png")
				_armar(2)
				_paso = 4
		4:
			if _desde >= 0.5:
				_saltar_a_las_puertas()
				_siguiente()
		5:
			# Que el demonio llegue a la tropa y anuncie un golpe.
			var demonio := _primero(func(u: Unidad3D) -> bool: return u.es_jefe)
			if demonio != null and not demonio.golpe_anunciado.is_connected(_on_golpe):
				demonio.golpe_anunciado.connect(_on_golpe)
			if _golpe_anunciado or _desde >= ESPERA_MAXIMA:
				_desde = 0.0
				_siguiente()
		6:
			if _desde >= 0.7:
				_foto("niveles_3_puertas_demonio.png")
				return true
	return false


func _on_golpe(_punto: Vector3, _radio: float, _segundos: float) -> void:
	_golpe_anunciado = true


func _siguiente() -> void:
	_paso += 1
	_desde = 0.0


## Saca la batalla anterior y arma la del nivel i.
func _armar(i: int) -> void:
	if _battle != null:
		_battle.queue_free()
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	_battle.encuentro = _niveles.encuentro_en(i)
	root.add_child(_battle)
	_camara = null
	_healer = null
	_desde = 0.0
	_paso = [0, 1, 4][i]


## Sin jugar los dos primeros tramos: se sacan sus enemigos, entra el ultimo
## sector, y la tropa y el healer se paran en su mitad, de cara al demonio.
func _saltar_a_las_puertas() -> void:
	for u in get_nodes_in_group("enemigos"):
		u.remove_from_group("enemigos")
		u.queue_free()
	_battle._entrar_sector(2)
	var aliados := _en_juego("aliados")
	for i in aliados.size():
		aliados[i].global_position = Vector3(X_TROPA_PUERTAS + (i % 3) * 1.2, 0.0,
			2.5 + (i % 4) * 1.6)
	_healer.global_position = Vector3(X_HEALER_PUERTAS, 0.0, 5.0)
	# Antes del proximo tick de fisica: la batalla recorta a los healers
	# contra lo que muestra la camara, y sin esto lo devolveria al arranque.
	_camara.saltar_a(X_TROPA_PUERTAS)


func _foto(nombre: String) -> void:
	root.get_texture().get_image().save_png("user://" + nombre)
	var sector: Sector = _battle.sector_activo()
	print("%s -> %s" % [nombre, ProjectSettings.globalize_path("user://" + nombre)])
	print("  %s, sector %d (%s)  limite x %.1f  camara x %.1f, se ve de %.1f a %.1f" % [
		_battle._actual.id, _battle.indice_sector(), sector.titulo if sector else "-",
		_battle.limite_x_actual(), _camara.x_actual(),
		_camara.x_actual() - _camara.mitad_visible(), _camara.x_actual() + _camara.mitad_visible()])
	var aliados := _en_juego("aliados")
	var enemigos := _en_juego("enemigos")
	print("  en cuadro: %d de %d aliados, %d de %d enemigos" % [
		aliados.filter(_en_cuadro).size(), aliados.size(),
		enemigos.filter(_en_cuadro).size(), enemigos.size()])
	print("  healer    %s" % _en_pantalla(_healer))
	var tapan := aliados.filter(func(u: Unidad3D) -> bool: return _tapa_al_healer(u))
	print("  lo tapan: %s" % (", ".join(tapan.map(func(u: Unidad3D) -> String:
		return "%s %s (x %.1f z %.1f)" % [u.tipo.nombre, u.nombre_unidad, u.global_position.x,
			u.global_position.z])) if not tapan.is_empty() else "nadie"))
	for u in enemigos:
		if u.telegrafiado > 0.0:
			print("  %-9s %s  vida %.0f" % [u.tipo.nombre, _en_pantalla(u), u.vida])


func _primero(cumple: Callable) -> Unidad3D:
	for u in _en_juego("enemigos"):
		if cumple.call(u):
			return u
	return null


func _en_juego(grupo: String) -> Array[Unidad3D]:
	var lista: Array[Unidad3D] = []
	for nodo in get_nodes_in_group(grupo):
		var unidad := nodo as Unidad3D
		if unidad != null and unidad.esta_viva() and not unidad.is_queued_for_deletion():
			lista.append(unidad)
	return lista


func _en_cuadro(nodo: Node3D) -> bool:
	var x := _camara.unproject_position(nodo.global_position + Vector3(0.0, ALTURA_PECHO, 0.0)).x
	return x >= 0.0 and x <= root.get_visible_rect().size.x


## De que x a que x ocupa el cuerpo en pantalla.
func _ancho_en_pantalla(nodo: Node3D) -> Vector2:
	var pos := nodo.global_position + Vector3(0.0, ALTURA_PECHO, 0.0)
	return Vector2(_camara.unproject_position(pos + Vector3(-MEDIO_CUERPO, 0.0, 0.0)).x,
		_camara.unproject_position(pos + Vector3(MEDIO_CUERPO, 0.0, 0.0)).x)


func _en_pantalla(nodo: Node3D) -> String:
	var ancho := root.get_visible_rect().size.x
	var tramo := _ancho_en_pantalla(nodo)
	var estado := "en cuadro"
	if tramo.y < 0.0 or tramo.x > ancho:
		estado = "FUERA DE CUADRO"
	elif tramo.x < 0.0 or tramo.y > ancho:
		estado = "CORTADO POR EL BORDE"
	return "x=%5.2f z=%4.2f  de %4.0f a %4.0f px  %s" % [
		nodo.global_position.x, nodo.global_position.z, tramo.x, tramo.y, estado]


## Un soldado mas cerca de la camara (mas z) cuyo cuerpo pisa buena parte del
## del healer en pantalla.
func _tapa_al_healer(u: Unidad3D) -> bool:
	if u.global_position.z <= _healer.global_position.z:
		return false
	var h := _ancho_en_pantalla(_healer)
	var s := _ancho_en_pantalla(u)
	var pisado := minf(h.y, s.y) - maxf(h.x, s.x)
	return pisado > (h.y - h.x) * TAPA
