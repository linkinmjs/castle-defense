extends PruebaBase
## El feedback enganchado al juego: la pose de cada movimiento, las posturas
## del cuerpo (caer, levantarse, aterrizar) y los efectos que salen de curar,
## de pegar y de recibir un golpe.
##
## test_feedback prueba cada pieza suelta (particulas, numeros, vineta); esta
## prueba que el healer y las unidades las llamen donde tienen que llamarlas, y
## lo primero es que en headless no aparezca ni una: las demas suites corren sin
## pantalla, y un nodo de mas en el campo les cambiaria lo que miden.

const ORIGEN := Vector3(15, 0, 5)
const ESCUDERO := preload("res://resources/soldados/escudero.tres")
const ZOMBIE := preload("res://resources/soldados/zombie.tres")
const BRUTO := preload("res://resources/soldados/bruto.tres")
const ESCENA_UNIDAD := preload("res://scenes/3d/unidad3d.tscn")
const FRAMES_HEALER: Array[SpriteFrames] = [
	preload("res://assets/sprites/healer/healer_frames.tres"),
	preload("res://assets/sprites/healer2/healer2_frames.tres"),
]
const DIR := "res://resources/movimientos"
## Por archivo: animacion al soltarlo, pose de carga (vacia si no tiene),
## efecto y cuadro en que arranca la pose. Es la tabla de gen_movimientos.gd
## vista desde lo que se guardo.
const ESPERADO := {
	"toque": ["healing", "", "toque", 0],
	"vendaje": ["healing", "", "toque", 0],
	"plegaria": ["energy_wave", "power_boost", "plegaria", 0],
	"bendicion": ["magic_shield", "", "bendicion", 0],
	"oleada": ["energy_wave", "", "oleada", 0],
	"reanimar": ["resurrection", "", "reanimar", 5],
	"impulso": ["aerial_strike", "", "impulso", 0],
	"caida": ["energy_wave", "aerial_strike", "caida", 0],
}
## Lo que tarda un jugador en apretar dos veces: mas que la recuperacion de la
## ligera (0.3 s) y menos que la ventana del combo (0.7 s).
const ENTRE_BOTONES := 24

var _raiz: Node3D
var _healer: Healer3D
## Al frente del healer, dentro de las dos cajas: a quien le llegan las curas.
var _aliado: Unidad3D
## Lejos del healer: el que recibe los golpes de las unidades.
var _blanco: Unidad3D
var _zombi: Unidad3D
var _bruto: Unidad3D
var _vineta: Vineta
var _movs: Dictionary[String, Movimiento] = {}
## Lo mas que se vio a la vez, en cualquier tick, de lo que en headless no
## tiene que existir.
var _max_particulas := 0
var _max_textos := 0
var _curadas: Array[Vector2] = []
## Lo que se mira en cada tick de una espera y ya se anoto (ver _ok_una_vez).
var _anotados: Dictionary[String, bool] = {}


func preparar() -> void:
	_raiz = Node3D.new()
	_raiz.name = "Unidades"
	root.add_child(_raiz)
	_healer = load("res://scenes/3d/healer3d.tscn").instantiate()
	_healer.position = ORIGEN
	_raiz.add_child(_healer)
	_aliado = _unidad(Unidad3D.Bando.ALIADO, ESCUDERO, ORIGEN + Vector3(1.2, 0, 0))
	_blanco = _unidad(Unidad3D.Bando.ALIADO, ESCUDERO, ORIGEN + Vector3(-8.0, 0, 0))
	_zombi = _unidad(Unidad3D.Bando.ENEMIGO, ZOMBIE, ORIGEN + Vector3(-7.0, 0, 0))
	_bruto = _unidad(Unidad3D.Bando.ENEMIGO, BRUTO, ORIGEN + Vector3(-6.8, 0, 1.0))
	# La crea la batalla (otro paquete); aca se la cuelga a mano para ver que
	# el golpe al healer la hace latir.
	_vineta = Vineta.new()
	root.add_child(_vineta)
	for archivo: String in ESPERADO:
		_movs[archivo] = load("%s/%s.tres" % [DIR, archivo])


func fase(numero: int) -> void:
	_vigilar()
	match numero:
		0:
			if _ticks < 2:
				return
			# Quietas: la prueba mide lo que se ve, no el combate.
			for unidad in [_aliado, _blanco, _zombi, _bruto]:
				unidad.set_physics_process(false)
			_healer._sprite.flip_h = false
			_probar_tabla()
			_probar_sin_pantalla()
			_probar_poses_en_el_suelo()
			_probar_efectos()
			_probar_renglones()
			_arrancar_plegaria()
			siguiente()
		1:
			if _healer.esta_en_wind_up():
				return
			_soltar_plegaria()
			siguiente()
		2:
			print("--- el remate pesa, y en headless no frena el tiempo ---")
			_healer.reiniciar(ORIGEN)
			_aliado.vida = 30.0
			_ok("L sale", _healer.pulsar(&"ligera"))
			_ok("el Toque se ve como healing", _healer._sprite.animation == &"healing")
			_igual("la pose dura lo que la animacion (0.57 s)", _healer._casteando,
				_healer._duracion(&"healing"), 0.02)
			siguiente()
		3:
			if _ticks < ENTRE_BOTONES:
				return
			_ok("L L sale", _healer.pulsar(&"ligera"))
			_ok("el Vendaje arranca su gesto de cero", _healer._sprite.animation == &"healing"
				and _healer._sprite.frame == 0)
			siguiente()
		4:
			if _ticks < ENTRE_BOTONES:
				return
			_ok("L L P sale", _healer.pulsar(&"pesada"))
			_ok("la Oleada se ve como energy_wave", _healer._sprite.animation == &"energy_wave")
			_ok("el hit-stop del remate no toca el tiempo en headless", Engine.time_scale == 1.0)
			siguiente()
		5:
			print("--- caer y levantarse ---")
			_healer.reiniciar(ORIGEN)
			_healer.recibir_dano(1000.0)
			_ok("el golpe que lo tira lo deja en fall", _healer._sprite.animation == &"fall")
			_healer._caido_restante = 1.2
			siguiente()
		6:
			if _ticks == 60:
				var ultimo: int = _healer._sprite.sprite_frames.get_frame_count(&"fall") - 1
				_ok("tirado queda en el ultimo cuadro de fall",
					_healer._sprite.animation == &"fall" and _healer._sprite.frame == ultimo)
			if not _healer.esta_viva():
				return
			_ok("al levantarse pasa por resurrection", _healer._sprite.animation == &"resurrection")
			_ok("y caminar no lo pisa mientras dura", _healer._postura_restante > 0.0)
			siguiente()
		7:
			if _healer._postura_restante > 0.0:
				_ok_una_vez("mientras se levanta sigue en resurrection",
					_healer._sprite.animation == &"resurrection")
				return
			if _ticks < 2:
				return
			_ok("termina de levantarse y queda quieto", _healer._sprite.animation == &"idle")
			_healer.recibir_dano(1000.0)
			_healer._caido_restante = 0.05
			siguiente()
		8:
			if not _healer.esta_viva() or _ticks < 6:
				return
			_ok("levantandose de nuevo", _healer._sprite.animation == &"resurrection")
			_healer.recibir_dano(1.0)
			_ok("un golpe mientras se levanta si se ve", _healer._sprite.animation == &"hurt")
			siguiente()
		9:
			if _ticks < 20:
				return
			print("--- aterrizar ---")
			_healer.reiniciar(ORIGEN)
			_healer.saltar()
			_ok("saltar pone jump", _healer._sprite.animation == &"jump")
			siguiente()
		10:
			if _healer.esta_en_el_aire():
				return
			_ok("quieto, aterriza agachado (land, ya doblando las rodillas)",
				_healer._sprite.animation == &"land"
				and _healer._sprite.frame >= Healer3D.CUADRO_ATERRIZAJE)
			siguiente()
		11:
			if _ticks < 12:
				return
			_ok("y a los 0.2 s vuelve a idle", _healer._sprite.animation == &"idle")
			Input.action_press(&"p1_derecha")
			siguiente()
		12:
			if _ticks < 20:
				return
			_ok("corriendo reproduce run", _healer._sprite.animation == &"run")
			_ok("y lleva el reloj de los pasos", _healer._reloj_pasos > 0.0
				and _healer._reloj_pasos <= Healer3D.INTERVALO_PASOS)
			_healer.saltar()
			siguiente()
		13:
			if _healer.esta_en_el_aire():
				return
			_ok("corriendo, al aterrizar no se agacha: sigue corriendo",
				_healer._sprite.animation == &"run")
			Input.action_release(&"p1_derecha")
			siguiente()
		14:
			if _ticks < 30:
				return
			print("--- la Caida sanadora: pose en el aire y onda al tocar el suelo ---")
			_healer.reiniciar(ORIGEN)
			_healer._sprite.flip_h = false
			_healer.saltar()
			siguiente()
		15:
			if _ticks < 4:
				return
			if _ticks == 4:
				_ok("en el aire P queda esperando el suelo", _healer.pulsar(&"pesada"))
				return
			if _ticks == 5:
				_ok("mientras espera, pose de carga: aerial_strike",
					_healer._sprite.animation == &"aerial_strike")
			if _healer.esta_en_el_aire():
				return
			_ok("al tocar el suelo suelta la onda: energy_wave",
				_healer._sprite.animation == &"energy_wave")
			siguiente()
		16:
			if _ticks < 40:
				return
			print("--- el Impulso: pose propia en el aire ---")
			_healer.reiniciar(ORIGEN)
			_healer._sprite.flip_h = false
			_healer.saltar()
			siguiente()
		17:
			if _ticks < 4:
				return
			if _ticks == 4:
				_ok("en el aire L sale", _healer.pulsar(&"ligera"))
				_ok("y es aerial_strike", _healer._sprite.animation == &"aerial_strike")
				return
			if _healer.esta_en_el_aire():
				return
			siguiente()
		18:
			if _ticks < 30:
				return
			print("--- al final, nada de lo que no se ve quedo en el arbol ---")
			_ok("ni una particula en ningun tick (%d)" % _max_particulas, _max_particulas == 0)
			_ok("ni un Label3D en ningun tick (%d)" % _max_textos, _max_textos == 0)
			_ok("NumeroFlotante no tiene ninguno vivo", NumeroFlotante.cantidad_vivos() == 0)
			_ok("y el tiempo sigue a escala 1", Engine.time_scale == 1.0)
			terminar()


# --- Pruebas ------------------------------------------------------------------

func _probar_tabla() -> void:
	print("--- cada movimiento con su pose y su efecto ---")
	for archivo: String in ESPERADO:
		var mov := _movs[archivo]
		var esperado: Array = ESPERADO[archivo]
		_ok("%s: animacion %s desde el cuadro %d, carga \"%s\", efecto %s" % [
				archivo, esperado[0], esperado[3], esperado[1], esperado[2]],
			mov != null and mov.animacion == esperado[0] and mov.animacion_carga == esperado[1]
			and mov.efecto == esperado[2] and mov.cuadro_inicial == esperado[3])
		if mov == null:
			continue
		var poses_ok := true
		for frames in FRAMES_HEALER:
			poses_ok = poses_ok and frames.has_animation(mov.animacion) \
				and frames.has_animation(mov.pose_de_carga())
		_ok("  sus poses estan en healer y healer2", poses_ok)
		_ok("  su efecto esta en fx_frames", Healer3D.FRAMES_FX.has_animation(mov.efecto)
			and Healer3D.FRAMES_FX.get_frame_count(mov.efecto) > 0)
	_ok("sin pose de carga, la de carga es la de soltarlo",
		_movs["toque"].pose_de_carga() == "healing")


func _probar_sin_pantalla() -> void:
	print("--- en headless no aparece nada ---")
	_ok("Presentacion.activa() da false", not Presentacion.activa())
	Presentacion.hit_stop(self, 0.05)
	_ok("hit_stop() no toca la escala del tiempo", Engine.time_scale == 1.0)

	_healer.recibir_dano(6.0)
	_igual("un golpe chico hace latir la vineta al piso", _vineta.dano_actual(), 0.4, 0.001)
	_healer.recibir_dano(20.0)
	_igual("uno fuerte, a pleno", _vineta.dano_actual(), 1.0, 0.001)

	_aliado.curada.connect(func(pedido: float, entro: float) -> void:
		_curadas.append(Vector2(pedido, entro)))
	_aliado.vida = _aliado.vida_maxima - 10.0
	_igual("curar() con desperdicio devuelve lo que entro", _aliado.curar(18.0), 10.0)
	_igual("y llena la vida", _aliado.vida, _aliado.vida_maxima)
	_ok("y avisa lo pedido y lo que entro",
		_curadas.size() == 1 and _curadas[0].is_equal_approx(Vector2(18.0, 10.0)))
	_aliado.vida = 40.0
	_igual("sin desperdicio, todo", _aliado.curar(18.0), 18.0)

	# Golpe comun de un zombi al blanco, y golpe telegrafiado del bruto en el
	# mismo lugar: chispas, sacudida y hit-stop.
	var vida := _blanco.vida
	_zombi._objetivo = _blanco
	_zombi._conectar_golpe()
	_ok("el zombi le pega al blanco", _blanco.vida < vida)
	vida = _blanco.vida
	_bruto._punto_golpe = _blanco.global_position
	_bruto._conectar_golpe()
	_ok("el bruto tambien", _blanco.vida < vida)
	_ok("el golpe del bruto no frena el tiempo en headless", Engine.time_scale == 1.0)

	_healer.lanzar_efecto(_aliado, "toque", Color.GREEN)
	_vigilar()
	_ok("nada de eso creo particulas (%d)" % _max_particulas, _max_particulas == 0)
	_ok("ni textos (%d)" % _max_textos, _max_textos == 0)
	_ok("NumeroFlotante sigue en 0 tras curar y recibir dano", NumeroFlotante.cantidad_vivos() == 0)


func _probar_poses_en_el_suelo() -> void:
	print("--- poses en el suelo ---")
	_healer.reiniciar(ORIGEN)
	_healer.animar_movimiento(_movs["toque"])
	_ok("Toque en el suelo deja healing", _healer._sprite.animation == &"healing")
	_healer.animar_movimiento(_movs["bendicion"])
	_ok("Bendicion deja magic_shield", _healer._sprite.animation == &"magic_shield")
	_igual("una pose larga se protege hasta el tope", _healer._casteando, Healer3D.POSE_MAXIMA)
	_healer.animar_movimiento(_movs["reanimar"])
	_ok("Reanimar arranca arrodillado: resurrection desde el cuadro 5",
		_healer._sprite.animation == &"resurrection" and _healer._sprite.frame == 5)
	_igual("y protege solo lo que le queda (0.3 s)", _healer._casteando,
		_healer._duracion(&"resurrection", 5))
	var sin_pose := Movimiento.new()
	sin_pose.animacion = "no_existe"
	_healer.animar_movimiento(sin_pose)
	_ok("una pose que el sprite no tiene cae a cast", _healer._sprite.animation == &"cast")


func _probar_efectos() -> void:
	print("--- efectos sobre el objetivo ---")
	var reanimar := _lanzar("reanimar")
	if reanimar == null:
		_ok("lanzar_efecto crea un sprite", false)
		return
	_igual("reanimar mide 1.6 m con su cuadro de 128 px (pixel_size x 1000)",
		reanimar.pixel_size * 1000.0, 1.6 / 128.0 * 1000.0, 0.001)
	var alto := 128.0 * reanimar.pixel_size
	_igual("y apoya la base en el suelo", reanimar.global_position.y - alto * 0.5,
		_aliado.global_position.y, 0.001)
	var toque := _lanzar("toque")
	_igual("toque, de 72 px, mide lo mismo (pixel_size x 1000)",
		toque.pixel_size * 1000.0, 1.6 / 72.0 * 1000.0, 0.001)
	_igual("y va centrado en el pecho", toque.global_position.y - _aliado.global_position.y,
		Healer3D.ALTURA_EFECTO)
	_ok("un poco delante de el, del lado de la camara",
		toque.global_position.z > _aliado.global_position.z)
	var raro := _lanzar("inexistente")
	_ok("uno que no existe sale como heal", raro.animation == &"heal")


## Los numeros que nacen donde ya hay otro (una cura en area sobre soldados
## amontonados) se apilan en vez de encimarse. En headless no se crea ninguno,
## asi que se prueba la cuenta: en que renglon caeria cada uno, con una camara
## como la del juego y las cajas que ya ocupan otros.
func _probar_renglones() -> void:
	print("--- numeros que nacen juntos no se pisan ---")
	var camara := Camera3D.new()
	_raiz.add_child(camara)
	camara.global_position = ORIGEN + Vector3(0.0, 3.9, 10.6)
	camara.rotation_degrees = Vector3(-15.0, 0.0, 0.0)
	var cabeza := _aliado.punto_cabeza()
	var ocupadas: Array[Rect2] = []
	_ok("sin nadie, sale en su renglon",
		Unidad3D._renglon_libre(camara, cabeza, 0, "+40", 1.0, ocupadas) == 0)
	ocupadas.append(Unidad3D._caja_en_pantalla(camara, _aliado.punto_numero(0), "+40", 1.0))
	var segundo := Unidad3D._renglon_libre(camara, cabeza, 0, "+40", 1.0, ocupadas)
	_ok("con otro ahi, sube uno (%d)" % segundo, segundo == 1)
	ocupadas.append(Unidad3D._caja_en_pantalla(camara, _aliado.punto_numero(1), "+40", 1.0))
	var desperdicio := Unidad3D._renglon_libre(camara, cabeza, 1, "20 desp.", 0.8, ocupadas)
	_ok("el desperdicio, que arranca en el 1, sube al 2 (%d)" % desperdicio, desperdicio == 2)
	ocupadas.append(Unidad3D._caja_en_pantalla(camara, _aliado.punto_numero(2), "20 desp.", 0.8))
	var al_costado := Unidad3D._renglon_libre(camara, cabeza + Vector3(3.0, 0.0, 0.0), 0,
		"+40", 1.0, ocupadas)
	_ok("uno a 3 m al costado no se mueve (%d)" % al_costado, al_costado == 0)
	_ok("sin renglon libre hasta RENGLONES_EXTRA, espera (-1)",
		Unidad3D._renglon_libre(camara, cabeza, 0, "+40", 1.0, ocupadas) == -1)
	camara.queue_free()


## La carga estira la pose a lo que dura: la Plegaria reza medio segundo.
func _arrancar_plegaria() -> void:
	print("--- la Plegaria: carga y suelta ---")
	_healer.reiniciar(ORIGEN)
	_healer._sprite.flip_h = false
	_aliado.vida = 30.0
	var plegaria := _movs["plegaria"]
	_ok("P sale y queda cargando", _healer.pulsar(&"pesada") and _healer.esta_en_wind_up())
	_ok("carga con power_boost", _healer._sprite.animation == &"power_boost")
	var escala := _healer._sprite.speed_scale
	_igual("estirada a lo que dura la carga (escala)", escala,
		_healer._duracion(&"power_boost") / plegaria.wind_up, 0.001)
	_igual("asi la animacion dura 0.5 s", _healer._duracion(&"power_boost") / escala,
		plegaria.wind_up, 0.001)


func _soltar_plegaria() -> void:
	_ok("al soltar pasa a energy_wave", _healer._sprite.animation == &"energy_wave")
	_igual("y vuelve al ritmo de siempre", _healer._sprite.speed_scale, 1.0)
	_igual("curo al que estaba adelante", _aliado.vida, 70.0)


# --- Ayudantes ----------------------------------------------------------------

func _unidad(bando: Unidad3D.Bando, tipo: TipoSoldado, pos: Vector3) -> Unidad3D:
	var unidad: Unidad3D = ESCENA_UNIDAD.instantiate()
	unidad.configurar(bando, tipo)
	unidad.position = pos
	_raiz.add_child(unidad)
	unidad.probabilidad_sangrado = 0.0
	return unidad


## Lanza el efecto sobre el aliado y devuelve el sprite nuevo.
func _lanzar(animacion: String) -> AnimatedSprite3D:
	var antes := _raiz.get_children()
	_healer.lanzar_efecto(_aliado, animacion, Color.WHITE)
	for hijo in _raiz.get_children():
		if hijo is AnimatedSprite3D and not antes.has(hijo):
			return hijo
	return null


## Anota cuantas particulas y textos hay en el arbol ahora.
func _vigilar() -> void:
	_max_particulas = maxi(_max_particulas, _contar(root, "CPUParticles3D"))
	_max_textos = maxi(_max_textos, _contar(root, "Label3D"))


func _contar(nodo: Node, clase: String) -> int:
	var cuantos := 1 if nodo.is_class(clase) else 0
	for hijo in nodo.get_children():
		cuantos += _contar(hijo, clase)
	return cuantos


## Para lo que se mira en cada tick de una espera: se anota la primera vez, y
## despues solo si falla.
func _ok_una_vez(que: String, condicion: bool) -> void:
	if _anotados.has(que) and condicion:
		return
	_anotados[que] = true
	_ok(que, condicion)
