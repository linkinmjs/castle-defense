class_name Particulas
extends RefCounted
## Particulas de un solo disparo para lo que pasa en el campo: polvo al
## aterrizar y al correr, chispas en los golpes, brillo en las curas y la estela
## del impulso.
##
## CPUParticles3D y no GPUParticles3D: el export es web con GL Compatibility, y
## ahi las de GPU dependen de lo que soporte cada navegador. Las de CPU se ven
## igual en todos lados, y con una docena de motas por efecto el costo no se
## nota.
##
## Sin texturas: cada mota es un cuadrado liso del color del efecto. Al lado del
## pixel art, un cuadrado chico se lee como un pixel grande, que es justo lo que
## tiene que parecer.
##
## Todo estatico, como Presentacion: cada efecto es una funcion que arma el
## emisor, lo cuelga, lo arranca y se olvida. El emisor se libera solo.
##
## Convenciones de todas las funciones:
## - pos es global: el emisor queda en ese punto del mundo, cuelgue de donde
##   cuelgue. Fuera del arbol no hay global, y ahi pos queda como local.
## - Las motas viven en el mundo (local_coords en false): si padre se mueve, las
##   que ya salieron se quedan donde nacieron. Por eso conviene colgarlas de algo
##   que no se borre en medio del efecto (el nodo de la batalla, no el soldado
##   que se esta muriendo), salvo en la estela, que justamente quiere viajar.
## - Sin pantalla (Presentacion.activa() en false) no crean nada y devuelven
##   null. forzar las crea igual: es para las pruebas, que las miran por dentro.

## La tierra del campo, para el polvo y los pasos.
const COLOR_POLVO := Color("#a08a6a")
## Chispa de golpe si no se pide otra: blanco calido.
const COLOR_CHISPA := Color(1.0, 0.9, 0.6)
## Cuanto espera el respaldo despues de que ya no puede quedar ninguna mota
## viva. Holgado: el respaldo es para cuando finished no llega, no una carrera
## contra el.
const MARGEN_RESPALDO := 0.5

## Una malla por efecto, compartida por todos sus emisores. El color viene por
## vertice, asi que el mismo material sirve para cualquier color.
static var _mallas: Dictionary[StringName, QuadMesh] = {}
## Cuantas veces se llamo a pasos(). Alterna dos y tres motas.
static var _pasos_dados: int = 0


## Nubecitas de tierra que se abren a ras del suelo y suben apenas. Para
## aterrizajes y arranques de carrera. pos va a los pies.
static func polvo(padre: Node, pos: Vector3, cantidad: int = 8,
		forzar: bool = false) -> CPUParticles3D:
	if not _hay_que_crear(padre, forzar):
		return null
	var emisor := _emisor(&"polvo", cantidad, 0.5, 0.3, false, true)
	emisor.explosiveness = 0.9
	# Nacen en un disco chato alrededor de los pies y se abren en el plano,
	# para cualquier lado: flatness 1 aplasta el abanico sobre XZ.
	_disco(emisor, 0.25)
	emisor.direction = Vector3.RIGHT
	emisor.spread = 180.0
	emisor.flatness = 1.0
	emisor.initial_velocity_min = 1.0
	emisor.initial_velocity_max = 2.0
	# Frenan rapido: el polvo se abre de golpe (hasta medio metro) y se queda
	# flotando.
	emisor.damping_min = 3.5
	emisor.damping_max = 4.0
	emisor.gravity = Vector3(0.0, 0.6, 0.0)
	# 0.12 m al nacer, 0.3 m al apagarse.
	emisor.scale_amount_curve = _curva(0.4, 1.0)
	emisor.color_ramp = _rampa([0.0, 1.0], [COLOR_POLVO, Color(COLOR_POLVO, 0.0)])
	return _soltar(emisor, padre, pos)


## Dos o tres motas chicas a los pies. Para cada paso corriendo: llamarla cada
## ~0.15 s mientras corre. pos va a los pies.
static func pasos(padre: Node, pos: Vector3, forzar: bool = false) -> CPUParticles3D:
	if not _hay_que_crear(padre, forzar):
		return null
	# Dos y tres alternados: con siempre la misma cantidad, la carrera se ve
	# mecanica.
	_pasos_dados += 1
	var emisor := _emisor(&"pasos", 2 + _pasos_dados % 2, 0.3, 0.1, false, true)
	emisor.explosiveness = 1.0
	_disco(emisor, 0.12)
	emisor.direction = Vector3.UP
	emisor.spread = 50.0
	emisor.initial_velocity_min = 0.5
	emisor.initial_velocity_max = 1.0
	emisor.damping_min = 1.5
	emisor.damping_max = 2.0
	emisor.gravity = Vector3(0.0, -2.0, 0.0)
	emisor.scale_amount_curve = _curva(0.6, 1.0)
	var mota := Color(COLOR_POLVO, 0.75)
	emisor.color_ramp = _rampa([0.0, 1.0], [mota, Color(mota, 0.0)])
	return _soltar(emisor, padre, pos)


## Chispas rapidas que salen en cono hacia arriba y caen: un golpe que conecto.
## pos es el punto del golpe (el pecho del golpeado, no sus pies).
static func chispas(padre: Node, pos: Vector3, color: Color = COLOR_CHISPA,
		cantidad: int = 10, forzar: bool = false) -> CPUParticles3D:
	if not _hay_que_crear(padre, forzar):
		return null
	var emisor := _emisor(&"chispas", cantidad, 0.35, 0.08, true)
	emisor.explosiveness = 1.0
	emisor.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emisor.emission_sphere_radius = 0.08
	emisor.direction = Vector3.UP
	emisor.spread = 60.0
	emisor.initial_velocity_min = 2.5
	emisor.initial_velocity_max = 4.5
	emisor.damping_min = 1.0
	emisor.damping_max = 2.0
	emisor.gravity = Vector3(0.0, -14.0, 0.0)
	emisor.scale_amount_curve = _curva(1.0, 0.4)
	# Nace casi blanca: el instante del impacto es el mas brillante.
	emisor.color_ramp = _rampa([0.0, 0.3, 1.0],
			[color.lerp(Color.WHITE, 0.6), color, Color(color, 0.0)])
	return _soltar(emisor, padre, pos)


## Destellos suaves que suben y se apagan sobre quien recibio una cura. pos va
## al centro del cuerpo (los pies + 1 m); color, el del movimiento.
static func brillo(padre: Node, pos: Vector3, color: Color, cantidad: int = 12,
		forzar: bool = false) -> CPUParticles3D:
	if not _hay_que_crear(padre, forzar):
		return null
	var emisor := _emisor(&"brillo", cantidad, 0.9, 0.08, true)
	# No todos juntos: que vayan apareciendo mientras suben los primeros.
	emisor.explosiveness = 0.6
	# Una caja del tamano de un cuerpo: el brillo envuelve al curado, no sale
	# de un punto.
	emisor.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emisor.emission_box_extents = Vector3(0.35, 0.55, 0.2)
	emisor.direction = Vector3.UP
	emisor.spread = 20.0
	emisor.initial_velocity_min = 0.3
	emisor.initial_velocity_max = 0.7
	emisor.gravity = Vector3(0.0, 0.8, 0.0)
	# 0.08 m al nacer, nada al final.
	emisor.scale_amount_curve = _curva(1.0, 0.0)
	var claro := color.lerp(Color.WHITE, 0.35)
	emisor.color_ramp = _rampa([0.0, 0.15, 0.6, 1.0],
			[Color(claro, 0.0), claro, Color(color, 0.9), Color(color, 0.0)])
	return _soltar(emisor, padre, pos)


## Rafaga corta que queda atras del impulso.
##
## Pensada para colgar del healer, a la altura del pecho: el emisor viaja con el
## y las motas se quedan en el mundo donde nacieron, asi que quedan atras solas,
## sin que haga falta saber para que lado va. Suelta motas durante una vida
## entera, 0.25 s: apenas mas de lo que dura el impulso. Colgada de algo quieto
## es un soplido en el lugar.
static func estela(padre: Node, pos: Vector3, color: Color,
		forzar: bool = false) -> CPUParticles3D:
	if not _hay_que_crear(padre, forzar):
		return null
	var emisor := _emisor(&"estela", 16, 0.25, 0.16, true)
	# Repartidas a lo largo del recorrido, no todas en la salida.
	emisor.explosiveness = 0.0
	emisor.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emisor.emission_sphere_radius = 0.3
	emisor.direction = Vector3.UP
	emisor.spread = 180.0
	emisor.initial_velocity_min = 0.1
	emisor.initial_velocity_max = 0.4
	emisor.damping_min = 1.0
	emisor.damping_max = 1.0
	emisor.scale_amount_curve = _curva(1.0, 0.25)
	emisor.color_ramp = _rampa([0.0, 1.0], [Color(color, 0.85), Color(color, 0.0)])
	return _soltar(emisor, padre, pos)


# --- Internos -----------------------------------------------------------------

static func _hay_que_crear(padre: Node, forzar: bool) -> bool:
	if not is_instance_valid(padre):
		return false
	return forzar or Presentacion.activa()


## Lo comun a todos: un disparo, las motas en el mundo, sin sombras y con la
## malla del efecto. vida en segundos; lado, cuanto mide la mota mas grande. Las
## del suelo se apoyan en el en vez de nacer enterradas a medias.
static func _emisor(efecto: StringName, cantidad: int, vida: float, lado: float,
		aditivo: bool, del_suelo: bool = false) -> CPUParticles3D:
	var emisor := CPUParticles3D.new()
	# CPUParticles3D nace emitiendo, y al entrar al arbol suelta la primera
	# tanda en el acto: saldria donde lo cuelgan, antes de ponerlo en pos. Con
	# explosividad 1 salen todas ahi. Se arranca en _soltar, ya en su lugar.
	emisor.emitting = false
	emisor.name = String(efecto).capitalize()
	emisor.amount = maxi(cantidad, 1)
	emisor.lifetime = vida
	emisor.one_shot = true
	emisor.local_coords = false
	emisor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emisor.mesh = _malla(efecto, lado, aditivo, del_suelo)
	return emisor


## El quad del efecto, del tamano de su mota mas grande. La escala de cada mota
## a lo largo de su vida es una fraccion de este lado: si algo la ignorara, la
## mota quedaria de su tamano maximo y no de un metro.
##
## del_suelo corre el quad para que la mota cuelgue de su borde de abajo: nacida
## a ras del piso, con el centro en la mota la mitad quedaria bajo el suelo y se
## veria como una rayita chata.
static func _malla(efecto: StringName, lado: float, aditivo: bool,
		del_suelo: bool) -> QuadMesh:
	var malla: QuadMesh = _mallas.get(efecto)
	if malla != null:
		return malla
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# El color de cada mota lo pone el emisor por vertice (color_ramp). Viene en
	# sRGB, como cualquier Color: sin esto, Forward+ lo leeria como lineal y lo
	# mostraria lavado. En Compatibility no cambia nada.
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Lo que brilla (chispas, curas, estela) suma luz; el polvo tapa.
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if aditivo \
			else BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Sin esto el billboard descarta la escala de cada mota, y la curva de
	# tamano no haria nada.
	material.billboard_keep_scale = true
	malla = QuadMesh.new()
	malla.size = Vector2(lado, lado)
	if del_suelo:
		# Hacia arriba de la pantalla: el billboard lleva el eje Y del quad al
		# de la camara.
		malla.center_offset = Vector3(0.0, lado * 0.5, 0.0)
	malla.material = material
	_mallas[efecto] = malla
	return malla


## Nacen en un disco chato sobre el suelo, del radio pedido.
static func _disco(emisor: CPUParticles3D, radio: float) -> void:
	emisor.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	emisor.emission_ring_axis = Vector3.UP
	emisor.emission_ring_height = 0.0
	emisor.emission_ring_radius = radio
	emisor.emission_ring_inner_radius = 0.0


## Tamano a lo largo de la vida, de desde a hasta, como fraccion del lado.
static func _curva(desde: float, hasta: float) -> Curve:
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, desde))
	curva.add_point(Vector2(1.0, hasta))
	return curva


## Degrade de color a lo largo de la vida. Se arma con los dos arreglos de una
## vez: agregando puntos de a uno, los indices se corren al insertar.
static func _rampa(posiciones: Array[float], colores: Array[Color]) -> Gradient:
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array(posiciones)
	rampa.colors = PackedColorArray(colores)
	return rampa


## Cuelga el emisor de padre en pos, lo arranca y se asegura de que se libere.
##
## Se libera con finished, que llega cuando se apaga la ultima mota. El respaldo
## es para cuando no llega: un emisor oculto (o colgado de algo que se oculta)
## no avanza, y sin el respaldo quedaria en el arbol para siempre.
static func _soltar(emisor: CPUParticles3D, padre: Node, pos: Vector3) -> CPUParticles3D:
	emisor.finished.connect(emisor.queue_free)
	# Hijo del emisor y no un reloj del arbol: se va con el si finished llega
	# primero, y no hace falta que padre este en el arbol para armarlo.
	var respaldo := Timer.new()
	respaldo.name = "Respaldo"
	respaldo.one_shot = true
	respaldo.autostart = true
	# Con la fisica, como los relojes del juego: la pausa y el hit-stop lo
	# frenan igual que a las motas.
	respaldo.process_callback = Timer.TIMER_PROCESS_PHYSICS
	respaldo.wait_time = _duracion_maxima(emisor) + MARGEN_RESPALDO
	respaldo.timeout.connect(emisor.queue_free)
	emisor.add_child(respaldo)

	padre.add_child(emisor)
	if emisor.is_inside_tree():
		emisor.global_position = pos
		# CPUParticles3D pasa las motas a su espacio con una inversa de su
		# transform que recien renueva con el aviso de cambio de transform, y
		# Godot junta esos avisos para mas tarde. Se fuerza ya: la primera tanda
		# sale en este frame y no puede depender de que el aviso llegue antes de
		# dibujar.
		emisor.force_update_transform()
	else:
		emisor.position = pos
	# Recien ahora: la primera tanda sale en este mismo frame, y tiene que
	# salir ya en pos.
	emisor.emitting = true
	return emisor


## Lo mas que puede tardar en apagarse la ultima mota: nace hasta
## (1 - explosiveness) vidas despues de arrancar, y vive una vida entera.
static func _duracion_maxima(emisor: CPUParticles3D) -> float:
	var vidas := 2.0 - emisor.explosiveness
	return emisor.lifetime * vidas / maxf(emisor.speed_scale, 0.01)
