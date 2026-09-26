extends PruebaBase
## La camara de la batalla sin la batalla: una Camera3D con el script, nodos
## sueltos haciendo de jugadores y actualizar() llamado a mano.
##
## Lo primero es que repita paso a paso la camara que vivia en battle3d.gd: es
## lo que permite borrar aquella sin que el juego se vea distinto. Despues va lo
## nuevo: el punto medio de dos jugadores, el limite del sector, el rango para
## recortar a los jugadores, el empuje contra el borde y los efectos, que en
## headless no pueden cambiar nada.

const DT := 1.0 / 60.0
const FOV := 42.0
const PROFUNDIDAD := 10.0
const ANCHO := 30.0


## La camara de battle3d.gd tal como estaba, para comparar frame a frame.
class CamaraVieja:
	var distancia_camara := 11.0
	var angulo_camara := 15.0
	var altura_objetivo := 1.05
	var suavizado_camara := 4.0
	var zona_muerta_camara := 1.8
	var ancho_campo := ANCHO
	var profundidad_campo := PROFUNDIDAD
	var fov := FOV
	var aspecto := 16.0 / 9.0
	var camara_x := 0.0
	var posicion := Vector3.ZERO

	## Lo que hacia iniciar_encuentro.
	func iniciar(healer_x: float) -> void:
		camara_x = healer_x
		posicion = _posicion_deseada()

	## Lo que hacia _actualizar_camara.
	func actualizar(healer_x: float, delta: float) -> void:
		camara_x = clampf(camara_x, healer_x - zona_muerta_camara,
				healer_x + zona_muerta_camara)
		var mitad := _mitad_visible()
		camara_x = clampf(camara_x, mitad, ancho_campo - mitad)
		posicion = posicion.lerp(_posicion_deseada(),
				1.0 - exp(-suavizado_camara * delta))

	func _mitad_visible() -> float:
		return tan(deg_to_rad(fov * 0.5)) * distancia_camara * aspecto

	func _posicion_deseada() -> Vector3:
		var objetivo := Vector3(camara_x, altura_objetivo, profundidad_campo * 0.5)
		var radianes := deg_to_rad(angulo_camara)
		return objetivo + Vector3(
			0.0,
			sin(radianes) * distancia_camara,
			cos(radianes) * distancia_camara)


## Un seguido que responde como un healer caido.
class ObjetivoCaido extends Node3D:
	func esta_viva() -> bool:
		return false


var _raiz: Node3D
var _cam: CamaraBatalla


func preparar() -> void:
	_raiz = Node3D.new()
	_raiz.name = "Raiz"
	root.add_child(_raiz)
	_cam = CamaraBatalla.new()
	_cam.name = "Camara"
	_cam.fov = FOV
	_raiz.add_child(_cam)


func fase(numero: int) -> void:
	if numero != 0:
		return
	# Que todo lo agregado en preparar() ya este en el arbol.
	if _ticks < 2:
		return
	_probar_matematica_vieja()
	_probar_punto_medio()
	_probar_zona_muerta()
	_probar_bordes_del_campo()
	_probar_sector()
	_probar_mitad_y_rango()
	_probar_saltar_a()
	_probar_quien_cuenta()
	_probar_empuje_borde()
	_probar_efectos_en_headless()
	_probar_efectos_por_dentro()
	terminar()


# --- Pruebas ------------------------------------------------------------------

func _probar_matematica_vieja() -> void:
	print("--- repite la camara de battle3d.gd ---")
	var objetivo := _objetivo(15.0)
	_preparar_camara([objetivo], 15.0)
	_correr(1.0)
	var radianes := deg_to_rad(15.0)
	_ok("rotacion fija en (-15, 0, 0)",
		_cam.rotation_degrees.is_equal_approx(Vector3(-15.0, 0.0, 0.0)))
	_igual("x sobre el objetivo", _cam.global_position.x, 15.0, 0.0001)
	_igual("y = altura_objetivo + sin(15)*11", _cam.global_position.y,
		1.05 + sin(radianes) * 11.0, 0.0001)
	_igual("z = profundidad/2 + cos(15)*11", _cam.global_position.z,
		PROFUNDIDAD * 0.5 + cos(radianes) * 11.0, 0.0001)

	# Frame a frame contra la vieja, con un recorrido que pasa por todo:
	# caminar dentro y fuera de la zona muerta, ida y vuelta, saltos largos y
	# los dos bordes del campo.
	var vieja := CamaraVieja.new()
	vieja.iniciar(15.0)
	var peor := 0.0
	for i in 480:
		objetivo.global_position.x = _recorrido(i)
		_cam.actualizar(DT)
		vieja.actualizar(objetivo.global_position.x, DT)
		peor = maxf(peor, _cam.global_position.distance_to(vieja.posicion))
	_ok("8 s de recorrido sin separarse de la vieja (peor %.7f m)" % peor, peor < 0.0001)
	objetivo.free()


func _probar_punto_medio() -> void:
	print("--- sigue el punto medio ---")
	var a := _objetivo(10.0)
	var b := _objetivo(20.0)
	_preparar_camara([a, b], 15.0)
	# Sin zona muerta la X tiene que quedar justo en el medio.
	_cam.zona_muerta = 0.0
	b.global_position.x = 22.0
	_correr(3.0)
	_igual("entre 10 y 22 mira a 16", _cam.x_actual(), 16.0, 0.001)
	a.global_position.x = 14.0
	_correr(3.0)
	_igual("entre 14 y 22 mira a 18", _cam.x_actual(), 18.0, 0.001)

	var c := _objetivo(12.0)
	a.global_position.x = 10.0
	b.global_position.x = 20.0
	_cam.seguir([a, c, b])
	_correr(3.0)
	_igual("con tres, el medio de las puntas y no el promedio", _cam.x_actual(), 15.0, 0.001)
	_liberar([a, b, c])


func _probar_zona_muerta() -> void:
	print("--- zona muerta ---")
	var a := _objetivo(15.0)
	_preparar_camara([a], 15.0)
	a.global_position.x = 16.0
	_correr(2.0)
	_igual("1 m a la derecha no la mueve", _cam.x_actual(), 15.0, 0.0001)
	a.global_position.x = 14.0
	_correr(2.0)
	_igual("1 m a la izquierda tampoco", _cam.x_actual(), 15.0, 0.0001)
	a.global_position.x = 18.0
	_correr(3.0)
	_igual("3 m la mueven hasta el borde de la zona", _cam.x_actual(), 18.0 - 1.8, 0.001)
	_liberar([a])


func _probar_bordes_del_campo() -> void:
	print("--- no muestra mas alla del campo ---")
	var a := _objetivo(1.0)
	_preparar_camara([a], 15.0)
	_correr(4.0)
	_igual("objetivo en x=1: la X queda en mitad_visible()",
		_cam.x_actual(), _cam.mitad_visible(), 0.001)
	_ok("el borde izquierdo visible no pasa de 0",
		_cam.x_actual() - _cam.mitad_visible() >= -0.001)
	a.global_position.x = 29.0
	_correr(4.0)
	_igual("objetivo en x=29: queda en 30 - mitad",
		_cam.x_actual(), ANCHO - _cam.mitad_visible(), 0.001)
	_liberar([a])


func _probar_sector() -> void:
	print("--- el limite del sector ---")
	var a := _objetivo(22.0)
	_preparar_camara([a], 15.0)
	_cam.limitar_x(20.0)
	_correr(4.0)
	_igual("con limite en 20 el borde derecho visible queda en 20",
		_cam.x_actual() + _cam.mitad_visible(), 20.0, 0.001)
	# El rango de los jugadores se mide en la fila delantera, mas angosta que
	# el plano del medio con el que se recorta la camara.
	_igual("y los jugadores se frenan a margen de la fila delantera",
		_cam.rango_x_jugadores().y,
		20.0 - _cam.mitad_visible() + _cam.mitad_jugadores() - _cam.margen_jugador, 0.001)

	# El tramo [0, 12] es mas angosto que la pantalla (unos 15 m): no hay X que
	# no muestre algo de afuera, y la camara se centra en el.
	_cam.limitar_x(12.0)
	_correr(4.0)
	_ok("limitar_x(12) recorta la derecha (x=%.2f)" % _cam.x_actual(),
		_cam.x_actual() < 20.0 - _cam.mitad_visible())
	_igual("mas angosto que la pantalla: centro de [0, 12]", _cam.x_actual(), 6.0, 0.001)

	_cam.limitar_x(INF)
	_correr(4.0)
	_igual("liberado, vuelve a seguir al objetivo", _cam.x_actual(), 22.0 - 1.8, 0.001)

	_cam.limitar_x(20.0)
	_cam.configurar(PROFUNDIDAD, 0.0, ANCHO)
	_correr(4.0)
	_igual("configurar borra el limite del encuentro anterior",
		_cam.x_actual(), 22.0 - 1.8, 0.001)
	_liberar([a])


func _probar_mitad_y_rango() -> void:
	print("--- lo que se ve y por donde pueden andar los jugadores ---")
	var a := _objetivo(15.0)
	_preparar_camara([a], 15.0)
	var mitad := _cam.mitad_visible()
	_ok("mitad_visible() entre 5 y 12 con 1280x720 (%.3f)" % mitad, mitad > 5.0 and mitad < 12.0)
	_igual("es tan(fov/2)*distancia*16/9", mitad,
		tan(deg_to_rad(FOV * 0.5)) * 11.0 * 1280.0 / 720.0, 0.0001)
	var rango := _cam.rango_x_jugadores()
	var mitad_jug := _cam.mitad_jugadores()
	_ok("la fila delantera muestra menos campo que el medio (%.3f < %.3f)" % [mitad_jug, mitad],
		mitad_jug < mitad and mitad_jug > 4.0)
	_igual("rango_x_jugadores() mide 2*(mitad_jugadores - 0.8)", rango.y - rango.x,
		2.0 * (mitad_jug - 0.8), 0.0001)
	_igual("centrado en la X de la camara", (rango.x + rango.y) * 0.5, _cam.x_actual(), 0.0001)

	# El rango sigue a la X suavizada, no a la que la camara quiere mirar.
	a.global_position.x = 25.0
	_cam.actualizar(DT)
	rango = _cam.rango_x_jugadores()
	_igual("a mitad de camino, centrado en la X que se ve",
		(rango.x + rango.y) * 0.5, _cam.x_actual(), 0.0001)
	_ok("que todavia no llego (%.2f)" % _cam.x_actual(), _cam.x_actual() < 23.0)
	_liberar([a])


func _probar_saltar_a() -> void:
	print("--- saltar_a ---")
	var a := _objetivo(20.0)
	_preparar_camara([a], 15.0)
	_cam.saltar_a(20.0)
	_igual("la X queda en 20 sin suavizado", _cam.x_actual(), 20.0, 0.0001)
	_igual("y la posicion tambien, sin esperar un frame", _cam.global_position.x, 20.0, 0.0001)
	_cam.actualizar(DT)
	_igual("un frame despues sigue ahi", _cam.global_position.x, 20.0, 0.0001)
	_cam.saltar_a(-5.0)
	_igual("respeta el borde izquierdo", _cam.x_actual(), _cam.mitad_visible(), 0.0001)
	_cam.saltar_a(100.0)
	_igual("y el derecho", _cam.x_actual(), ANCHO - _cam.mitad_visible(), 0.0001)
	_liberar([a])


func _probar_quien_cuenta() -> void:
	print("--- a quien cuenta como seguido ---")
	var a := _objetivo(10.0)
	var b := _objetivo(20.0)
	_preparar_camara([a, b], 15.0)
	_cam.zona_muerta = 0.0
	b.queue_free()
	_correr(3.0)
	_igual("uno en cola de borrado no cuenta: mira solo al otro", _cam.x_actual(), 10.0, 0.001)

	var c := _objetivo(20.0)
	_preparar_camara([a, c], 15.0)
	_cam.zona_muerta = 0.0
	c.free()
	_correr(3.0)
	_igual("uno ya liberado tampoco", _cam.x_actual(), 10.0, 0.001)

	var caido := ObjetivoCaido.new()
	_raiz.add_child(caido)
	caido.global_position = Vector3(20.0, 0.0, PROFUNDIDAD * 0.5)
	_preparar_camara([a, caido], 15.0)
	_cam.zona_muerta = 0.0
	_correr(3.0)
	_igual("uno caido (esta_viva() false) sigue contando", _cam.x_actual(), 15.0, 0.001)

	_preparar_camara([], 12.0)
	_correr(1.0)
	_igual("sin nadie a quien seguir se queda donde esta", _cam.x_actual(), 12.0, 0.0001)
	_liberar([a, caido])


func _probar_empuje_borde() -> void:
	print("--- empujar contra el borde de la pantalla ---")
	# El de atras deja el punto medio dentro de la zona muerta: lo unico que
	# puede mover la camara es el empuje. Queda a 2 m del centro para que el
	# rango de la fila delantera (mas angosto) todavia deje lugar a 1.5 m de empuje.
	var con := _empujar_un_segundo(15.0, 13.0, true, 3.0)
	_ok("pegado al borde derecho con velocity.x = 3 la corre a la derecha (%.2f m)" % con,
		con > 0.5)
	_ok("sin pasar de empuje_borde (%.2f <= 1.5 m en 1 s)" % con, con <= 1.5 + 0.0001)
	var quieto := _empujar_un_segundo(15.0, 13.0, true, 0.0)
	_igual("con velocity.x = 0 no la mueve", quieto, 0.0, 0.0001)
	var hacia_adentro := _empujar_un_segundo(15.0, 13.0, true, -3.0)
	_ok("caminando hacia adentro tampoco empuja (%.2f m)" % hacia_adentro, hacia_adentro <= 0.0)
	var sin_empuje := _empujar_un_segundo(15.0, 13.0, true, 3.0, 0.0)
	_igual("con empuje_borde en 0 no se mueve: era el empuje", sin_empuje, 0.0, 0.0001)
	var izquierda := _empujar_un_segundo(15.0, 17.0, false, -3.0)
	_ok("contra el borde izquierdo la corre a la izquierda (%.2f m)" % izquierda,
		izquierda < -0.5)

	# El de atras ya esta en su propio borde: correr la vista lo sacaria de
	# cuadro, asi que el que empuja se queda esperando.
	var hueco := _cam.mitad_jugadores() - _cam.margen_jugador
	var trabado := _empujar_un_segundo(15.0, 15.0 - hueco, true, 3.0)
	_igual("no saca de cuadro al que quedo atras", trabado, 0.0, 0.001)

	var tope := ANCHO - _cam.mitad_visible()
	var en_el_borde := _empujar_un_segundo(tope, tope - 3.0, true, 3.0)
	_igual("contra el borde del campo no pasa los recortes", en_el_borde, 0.0, 0.0001)


func _probar_efectos_en_headless() -> void:
	print("--- sacudida y punch no hacen nada en headless ---")
	var a := _objetivo(15.0)
	_preparar_camara([a], 15.0)
	_correr(0.1)
	var antes := _cam.global_position
	_cam.sacudir()
	_cam.sacudir(1.0, 1.0)
	_cam.punch()
	_cam.punch(-10.0, 1.0)
	_ok("punch no toca el fov (%.2f)" % _cam.fov, _cam.fov == FOV)
	var quieta := true
	for i in 30:
		_cam.actualizar(DT)
		quieta = quieta and _cam.global_position == antes and _cam.fov == FOV
	_ok("sacudir no mueve la camara en medio segundo", quieta)
	_liberar([a])


func _probar_efectos_por_dentro() -> void:
	print("--- sacudida y punch por dentro (lo que corre con pantalla) ---")
	var a := _objetivo(15.0)
	_preparar_camara([a], 15.0)
	var base := _cam.global_position
	var mitad := _cam.mitad_visible()

	_cam._iniciar_punch(-2.5, 0.18)
	_igual("el punch cierra el fov de una", _cam.fov, FOV - 2.5, 0.0001)
	_igual("sin achicar lo que ven los jugadores", _cam.mitad_visible(), mitad, 0.0001)
	_cam._iniciar_sacudida(0.12, 0.2)
	_cam.actualizar(DT)
	var desvio := _cam.global_position - base
	_ok("la sacudida mueve la posicion en X/Y (%.3f m)" % desvio.length(),
		desvio.length() > 0.001 and is_zero_approx(desvio.z))
	_ok("sin pasarse de la amplitud",
		absf(desvio.x) <= 0.12 + 0.0001 and absf(desvio.y) <= 0.12 + 0.0001)
	_igual("la X que ven los jugadores no tiembla", _cam.x_actual(), 15.0, 0.0001)
	var esperado := FOV - 2.5 * (0.18 - DT) / 0.18
	_igual("el punch vuelve lineal", _cam.fov, esperado, 0.0001)
	_cam._iniciar_punch(-1.0, 0.5)
	_igual("uno mas debil no pisa al que corre", _cam.fov, esperado, 0.0001)
	_cam._iniciar_sacudida(0.01, 1.0)
	_correr(0.3)
	_igual("terminado, el fov vuelve exacto al base", _cam.fov, FOV, 0.000001)
	_ok("y la posicion a la de siempre",
		_cam.global_position.is_equal_approx(base))

	# Dos sacudidas con la misma historia se ven igual: no hay azar.
	var primera := _dibujo_sacudida()
	var segunda := _dibujo_sacudida()
	_ok("el dibujo de la sacudida es determinista", primera == segunda)

	_cam._iniciar_punch(-2.5, 0.18)
	_cam._iniciar_sacudida(0.5, 1.0)
	_cam.configurar(PROFUNDIDAD, 0.0, ANCHO)
	_igual("configurar en medio de un punch deja el fov base", _cam.fov, FOV, 0.000001)
	_cam._iniciar_punch(-2.5, 0.18)
	_cam._iniciar_sacudida(0.5, 1.0)
	_cam.saltar_a(15.0)
	_igual("saltar_a tambien", _cam.fov, FOV, 0.000001)
	_ok("y corta la sacudida", _cam.global_position.is_equal_approx(base))
	_liberar([a])


# --- Ayudas -------------------------------------------------------------------

## Deja la camara como al empezar un encuentro, con los exports de fabrica.
func _preparar_camara(objetivos: Array[Node3D], x: float) -> void:
	_cam.distancia = 11.0
	_cam.angulo = 15.0
	_cam.altura_objetivo = 1.05
	_cam.suavizado = 4.0
	_cam.zona_muerta = 1.8
	_cam.margen_jugador = 0.8
	_cam.empuje_borde = 1.5
	_cam.configurar(PROFUNDIDAD, 0.0, ANCHO)
	_cam.seguir(objetivos)
	_cam.saltar_a(x)


func _correr(segundos: float) -> void:
	for i in roundi(segundos / DT):
		_cam.actualizar(DT)


func _objetivo(x: float) -> Node3D:
	var n := Node3D.new()
	_raiz.add_child(n)
	n.global_position = Vector3(x, 0.0, PROFUNDIDAD * 0.5)
	return n


func _liberar(nodos: Array) -> void:
	for n: Variant in nodos:
		if is_instance_valid(n):
			(n as Node).free()


## X del objetivo en el frame i: camina a la derecha saliendo de la zona
## muerta, vuelve, salta contra el borde derecho, despues contra el izquierdo, y
## se despega caminando.
func _recorrido(i: int) -> float:
	var t := i * DT
	if t < 2.0:
		return 15.0 + 3.0 * t
	if t < 3.0:
		return 21.0 - 5.0 * (t - 2.0)
	if t < 4.0:
		return 27.0
	if t < 5.5:
		return 2.0
	return 2.0 + 4.0 * (t - 5.5)


## Dos seguidos: uno quieto en x_otro y un CharacterBody3D pegado a un borde del
## rango con velocity.x = vx. Cada frame hace lo que va a hacer el healer:
## avanzar con su velocidad y recortarse contra rango_x_jugadores(). Devuelve
## cuanto se corrio la camara en un segundo.
func _empujar_un_segundo(x_camara: float, x_otro: float, borde_derecho: bool,
		vx: float, empuje: float = 1.5) -> float:
	var otro := _objetivo(x_otro)
	var cuerpo := CharacterBody3D.new()
	_raiz.add_child(cuerpo)
	_preparar_camara([otro, cuerpo], x_camara)
	_cam.empuje_borde = empuje
	var rango := _cam.rango_x_jugadores()
	var x_borde := rango.y - 0.01 if borde_derecho else rango.x + 0.01
	cuerpo.global_position = Vector3(x_borde, 0.0, PROFUNDIDAD * 0.5)
	cuerpo.velocity = Vector3(vx, 0.0, 0.0)
	var inicio := _cam.x_actual()
	var siempre_en_cuadro := true
	for i in 60:
		rango = _cam.rango_x_jugadores()
		cuerpo.global_position.x = clampf(
			cuerpo.global_position.x + cuerpo.velocity.x * DT, rango.x, rango.y)
		_cam.actualizar(DT)
		rango = _cam.rango_x_jugadores()
		siempre_en_cuadro = siempre_en_cuadro \
			and otro.global_position.x >= rango.x - 0.0001 \
			and otro.global_position.x <= rango.y + 0.0001
	if not siempre_en_cuadro:
		_ok("el que no empuja quedo fuera de cuadro (otro en %.2f)" % x_otro, false)
	var movida := _cam.x_actual() - inicio
	_liberar([otro, cuerpo])
	return movida


## Las posiciones de una sacudida corrida desde el mismo estado.
func _dibujo_sacudida() -> Array[Vector3]:
	_cam.saltar_a(15.0)
	_cam._sacudida_reloj = 0.0
	_cam._iniciar_sacudida(0.12, 0.2)
	var dibujo: Array[Vector3] = []
	for i in 12:
		_cam.actualizar(DT)
		dibujo.append(_cam.global_position)
	return dibujo
