extends PruebaBase
## El feedback visual sin pantalla: particulas, numeros flotantes y la vineta.
##
## En headless Presentacion corta todo lo que no cambia el juego, asi que lo
## primero es que sin forzar no se cree nada: si algo se colara, las suites de
## combate correrian con nodos de mas. Despues, con forzar, que cada pieza arme
## lo que dice y se limpie sola. Un efecto que no se libera es una fuga lenta:
## en una partida larga llena el arbol de nodos muertos.
##
## Las particulas avanzan con el frame (no hay otra: es CPUParticles3D), asi que
## sus plazos se miden con margen. Los numeros y los respaldos van con la
## fisica, y esos se miden al tick.

## Ticks de la fase que sigue a los que se liberan solos: 1.67 s, mas que
## cualquier respaldo de los que se prueban.
const TICKS_SEGUIMIENTO := 100

var _raiz: Node3D
## Aparte de _raiz, para contar solo numeros.
var _capa: Node3D
## Emisor al que se le emite finished a mano.
var _a_mano: CPUParticles3D
## Emisor congelado: sus motas no se apagan nunca y finished no llega. Lo tiene
## que liberar el respaldo.
var _congelado: CPUParticles3D
## Emisor que termina solo.
var _natural: CPUParticles3D
var _numero: NumeroFlotante
var _y_inicial := 0.0
## Tick de la fase de seguimiento en el que se vio liberado cada uno.
var _liberado: Dictionary[String, int] = {}


func preparar() -> void:
	_raiz = Node3D.new()
	_raiz.name = "Raiz"
	root.add_child(_raiz)
	_capa = Node3D.new()
	_capa.name = "Numeros"
	_raiz.add_child(_capa)


func fase(numero: int) -> void:
	match numero:
		0:
			# Que todo lo agregado en preparar() ya este en el arbol.
			if _ticks < 2:
				return
			_probar_sin_pantalla()
			_probar_particulas()
			_probar_numero()
			_probar_vineta()
			_arrancar_finales()
			siguiente()
		1:
			_seguir_finales()
		2:
			_probar_tope()
		3:
			_esperar_tope()


# --- Pruebas ------------------------------------------------------------------

func _probar_sin_pantalla() -> void:
	print("--- en headless no se crea nada sin forzar ---")
	_ok("Presentacion.activa() da false", not Presentacion.activa())
	var antes := _raiz.get_child_count()
	var pos := Vector3(3.0, 0.0, 2.0)
	_ok("polvo devuelve null", Particulas.polvo(_raiz, pos) == null)
	_ok("pasos devuelve null", Particulas.pasos(_raiz, pos) == null)
	_ok("chispas devuelve null", Particulas.chispas(_raiz, pos) == null)
	_ok("brillo devuelve null", Particulas.brillo(_raiz, pos, Color.GREEN) == null)
	_ok("estela devuelve null", Particulas.estela(_raiz, pos, Color.CYAN) == null)
	_ok("NumeroFlotante.mostrar devuelve null", NumeroFlotante.mostrar(
			_capa, pos, "+18", NumeroFlotante.COLOR_CURA) == null)
	_ok("y nadie agrega hijos", _raiz.get_child_count() == antes and _capa.get_child_count() == 0)
	_ok("sin padre no hay efecto ni forzando",
		Particulas.polvo(null, pos, 8, true) == null
		and NumeroFlotante.mostrar(null, pos, "+1", Color.WHITE, 1.0, true) == null)


func _probar_particulas() -> void:
	print("--- particulas con forzar ---")
	var pos := Vector3(4.0, 0.0, 3.0)
	var antes := _raiz.get_child_count()
	var polvo := Particulas.polvo(_raiz, pos, 8, true)
	if polvo == null:
		_ok("polvo con forzar devuelve un emisor", false)
		return
	_ok("polvo con forzar devuelve un CPUParticles3D", polvo is CPUParticles3D)
	_ok("de un disparo y emitiendo", polvo.one_shot and polvo.emitting)
	_ok("colgado del padre", polvo.get_parent() == _raiz and _raiz.get_child_count() == antes + 1)
	_ok("en la posicion pedida", polvo.global_position.is_equal_approx(pos))
	_ok("8 motas de 0.5 s", polvo.amount == 8 and is_equal_approx(polvo.lifetime, 0.5))
	_ok("las motas quedan en el mundo", not polvo.local_coords)
	_ok("color tierra que termina transparente",
		_rampa_usa(polvo, Particulas.COLOR_POLVO) and _termina_transparente(polvo))
	_igual("nace de 0.12 m", _tamano(polvo, 0.0), 0.12, 0.005)
	_igual("y termina de 0.3 m", _tamano(polvo, 1.0), 0.3, 0.005)
	_ok("se abre en el plano y sube apenas",
		is_equal_approx(polvo.flatness, 1.0) and polvo.gravity.y > 0.0 and polvo.gravity.y < 2.0)
	_ok("las motas se apoyan en el suelo en vez de nacer enterradas", _apoyada(polvo))
	_probar_dibujo("polvo", polvo)
	_ok("otra cantidad, otras motas", Particulas.polvo(_raiz, pos, 5, true).amount == 5)

	# pos es global: con el padre corrido tiene que quedar en el mismo punto.
	# Y tiene que entrar al arbol sin emitir: CPUParticles3D nace emitiendo y,
	# si entra asi, suelta la primera tanda en el acto, donde lo cuelgan y no en
	# pos (en pantalla, las chispas salian del piso y los pasos corridos). Las
	# motas no se pueden mirar en headless; lo que se mira es que no pueda pasar.
	var corrido := Node3D.new()
	corrido.name = "Corrido"
	_raiz.add_child(corrido)
	corrido.position = Vector3(10.0, 0.0, -2.0)
	var al_entrar: Array[bool] = []
	var anotar := func(nodo: Node) -> void:
		if nodo is CPUParticles3D:
			al_entrar.append((nodo as CPUParticles3D).emitting)
	corrido.child_entered_tree.connect(anotar)
	var lejos := Particulas.chispas(corrido, pos, Particulas.COLOR_CHISPA, 10, true)
	corrido.child_entered_tree.disconnect(anotar)
	_ok("con el padre corrido tambien queda en pos", lejos.global_position.is_equal_approx(pos))
	_ok("entra al arbol sin emitir y arranca ya en su lugar",
		al_entrar.size() == 1 and not al_entrar[0] and lejos.emitting)

	var paso := Particulas.pasos(_raiz, pos, true)
	var otro := Particulas.pasos(_raiz, pos, true)
	_ok("pasos: motas de 0.3 s", paso != null and is_equal_approx(paso.lifetime, 0.3))
	_ok("pasos: dos o tres por paso, alternando (%d y %d)" % [paso.amount, otro.amount],
		paso.amount + otro.amount == 5 and absi(paso.amount - otro.amount) == 1)
	_ok("pasos: chicas", _tamano(paso, 1.0) <= 0.15)
	_ok("pasos: apoyadas en el suelo", _apoyada(paso))
	_probar_dibujo("pasos", paso)

	var chispas := Particulas.chispas(_raiz, pos + Vector3.UP, Particulas.COLOR_CHISPA, 10, true)
	_ok("chispas: 10 de 0.35 s", chispas != null and chispas.amount == 10
		and is_equal_approx(chispas.lifetime, 0.35))
	_ok("chispas: salen en cono hacia arriba y caen",
		chispas.direction.y > 0.9 and chispas.spread > 0.0 and chispas.spread < 90.0
		and chispas.gravity.y < 0.0)
	_ok("chispas: del color pedido", _rampa_usa(chispas, Particulas.COLOR_CHISPA)
		and _termina_transparente(chispas))
	var rojas := Particulas.chispas(_raiz, pos, Color.RED, 4, true)
	_ok("chispas: otro color y otra cantidad", rojas.amount == 4 and _rampa_usa(rojas, Color.RED))
	_ok("chispas: centradas en el golpe, no apoyadas", not _apoyada(chispas))
	_probar_dibujo("chispas", chispas)

	var verde := Color("#7ddc7d")
	var brillo := Particulas.brillo(_raiz, pos + Vector3.UP, verde, 12, true)
	_ok("brillo: 12 de 0.9 s", brillo != null and brillo.amount == 12
		and is_equal_approx(brillo.lifetime, 0.9))
	_ok("brillo: suben", brillo.direction.y > 0.9 and brillo.gravity.y >= 0.0)
	_ok("brillo: del color del movimiento y se apagan",
		_rampa_usa(brillo, verde) and _termina_transparente(brillo))
	_igual("brillo: nace de 0.08 m", _tamano(brillo, 0.0), 0.08, 0.005)
	_igual("brillo: y se achica a nada", _tamano(brillo, 1.0), 0.0, 0.005)
	_probar_dibujo("brillo", brillo)

	var estela := Particulas.estela(_raiz, pos + Vector3.UP, Color.CYAN, true)
	_ok("estela: un disparo corto emitiendo", estela != null and estela.one_shot
		and estela.emitting and estela.lifetime <= 0.4)
	_ok("estela: del color pedido", _rampa_usa(estela, Color.CYAN) and _termina_transparente(estela))
	_ok("estela: suelta motas a lo largo del impulso, no todas juntas",
		estela.explosiveness < 0.5)
	_probar_dibujo("estela", estela)


func _probar_numero() -> void:
	print("--- numero flotante ---")
	var pos := Vector3(5.0, 1.8, 2.0)
	_numero = NumeroFlotante.mostrar(_capa, pos, "+18", NumeroFlotante.COLOR_CURA, 1.0, true)
	if _numero == null:
		_ok("con forzar devuelve un numero", false)
		return
	_ok("con forzar devuelve un Label3D", _numero is Label3D)
	_ok("con el texto pedido", _numero.text == "+18")
	_ok("y el color", _numero.modulate.is_equal_approx(NumeroFlotante.COLOR_CURA))
	_ok("colgado del padre en la posicion pedida",
		_numero.get_parent() == _capa and _numero.global_position.is_equal_approx(pos))
	_ok("pos es la base: el texto queda por encima",
		_numero.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM)
	_ok("billboard y encima de todo",
		_numero.billboard == BaseMaterial3D.BILLBOARD_ENABLED and _numero.no_depth_test)
	_ok("contorno negro grueso",
		_numero.outline_size >= 12 and _numero.outline_modulate.is_equal_approx(Color.BLACK))
	_ok("pixeles duros (nearest)", _numero.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	_ok("sin sombra", _numero.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_ok("fuente de 40 px", _numero.font_size == 40)
	# El alto de la fuente en el mundo; la linea entera (con acentos y colas)
	# mide un poco mas, y los digitos un poco menos.
	_igual("a tamano 1 mide ~0.5 m de alto", _numero.font_size * _numero.pixel_size, 0.48, 0.03)
	print("      (linea de la fuente: %.2f m)" % _alto_linea(_numero))
	var grande := NumeroFlotante.mostrar(_capa, pos, "VENDAJE", Color.GOLD, 1.5, true)
	_igual("a tamano 1.5 mide 1.5 veces", grande.pixel_size / _numero.pixel_size, 1.5, 0.001)
	grande.queue_free()
	_y_inicial = _numero.global_position.y


func _probar_vineta() -> void:
	print("--- vineta ---")
	var vineta := Vineta.new()
	root.add_child(vineta)
	_ok("capa 5", vineta.layer == 5)
	var rect: ColorRect = null
	for hijo in vineta.get_children():
		if hijo is ColorRect:
			rect = hijo
	if rect == null:
		_ok("tiene un ColorRect", false)
		vineta.queue_free()
		return
	var material := rect.material as ShaderMaterial
	_ok("tiene un ColorRect con ShaderMaterial", material != null)
	if material == null:
		vineta.queue_free()
		return
	_ok("con el shader cargado", material.shader != null)
	_ok("de canvas_item", material.shader != null
		and material.shader.get_mode() == Shader.MODE_CANVAS_ITEM)
	_ok("a pantalla completa",
		rect.anchor_left == 0.0 and rect.anchor_top == 0.0
		and rect.anchor_right == 1.0 and rect.anchor_bottom == 1.0
		and rect.offset_left == 0.0 and rect.offset_top == 0.0
		and rect.offset_right == 0.0 and rect.offset_bottom == 0.0)
	_ok("sin comerse el mouse", rect.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_ok("el rect es transparente: el color lo pone el shader", rect.color.a == 0.0)
	_igual("intensidad de fabrica", _parametro(material, &"intensidad"), 0.35, 0.0001)
	_igual("sin dano al empezar", vineta.dano_actual(), 0.0, 0.0001)

	vineta.pulsar_dano(1.0)
	_igual("pulsar_dano(1) deja dano_actual() en 1", vineta.dano_actual(), 1.0, 0.0001)
	_igual("y el uniform tambien", _parametro(material, &"dano"), 1.0, 0.0001)
	for i in 3:
		vineta._process(0.1)
	_igual("a los 0.3 s va por la mitad", vineta.dano_actual(), 0.5, 0.001)
	vineta.pulsar_dano(0.2)
	_igual("un golpe mas debil no lo baja", vineta.dano_actual(), 0.5, 0.001)
	for i in 7:
		vineta._process(0.1)
	_igual("tras 1 s de _process vuelve a 0", vineta.dano_actual(), 0.0, 0.0001)
	_igual("y el uniform tambien", _parametro(material, &"dano"), 0.0, 0.0001)
	vineta.pulsar_dano(0.3)
	vineta._process(0.1)
	_igual("uno de 0.3 baja al mismo ritmo", vineta.dano_actual(), 0.3 - 0.1 / 0.6, 0.001)

	vineta.set_intensidad(0.6)
	_igual("set_intensidad cambia el uniform", _parametro(material, &"intensidad"), 0.6, 0.0001)
	vineta.set_intensidad(3.0)
	_igual("sin pasarse de 1", _parametro(material, &"intensidad"), 1.0, 0.0001)

	# El healer la pulsa por grupo, sin tenerla a mano.
	vineta._process(1.0)
	call_group(Vineta.GRUPO, &"pulsar_dano", 0.7)
	_igual("se la puede pulsar por su grupo", vineta.dano_actual(), 0.7, 0.0001)
	vineta.queue_free()


## Arranca los tres emisores y el numero cuyo final sigue la fase 1.
func _arrancar_finales() -> void:
	_a_mano = Particulas.polvo(_raiz, Vector3(1.0, 0.0, 1.0), 8, true)
	_a_mano.finished.emit()
	_congelado = Particulas.polvo(_raiz, Vector3(2.0, 0.0, 1.0), 8, true)
	_congelado.speed_scale = 0.0
	_natural = Particulas.chispas(_raiz, Vector3(3.0, 1.0, 1.0), Color.WHITE, 10, true)


func _seguir_finales() -> void:
	_anotar("a_mano", _a_mano)
	_anotar("congelado", _congelado)
	_anotar("natural", _natural)
	_anotar("numero", _numero)
	if _ticks == 20:
		var subida := _numero.global_position.y - _y_inicial if is_instance_valid(_numero) else -1.0
		_ok("el numero subio en 20 ticks de fisica (%.2f m)" % subida, subida > 0.1)
	if _ticks < TICKS_SEGUIMIENTO:
		return

	print("--- se liberan solos ---")
	var a_mano: int = _liberado.get("a_mano", -1)
	_ok("con finished emitido a mano, al tick siguiente (tick %d)" % a_mano,
		a_mano >= 1 and a_mano <= 2)
	# 0.5 s de vida y 0.9 de explosividad: la ultima mota se apagaria a los
	# 0.55 s, y el respaldo espera medio segundo mas. 1.05 s son 63 ticks; el
	# que sobra es el redondeo del reloj y el tick en que se ve liberado.
	var congelado: int = _liberado.get("congelado", -1)
	_ok("congelado, lo libera el respaldo (tick %d, respaldo a los 63)" % congelado,
		congelado >= 60 and congelado <= 67)
	# Sus motas viven 0.35 s (21 ticks); el respaldo recien saltaria en el 51.
	var natural: int = _liberado.get("natural", -1)
	_ok("el que termina solo se libera con finished (tick %d, respaldo al 51)" % natural,
		natural >= 1 and natural < 51)
	var numero: int = _liberado.get("numero", -1)
	_ok("el numero se libera antes de 1.5 s (tick %d)" % numero, numero >= 1 and numero < 90)
	_ok("pero no antes de terminar de apagarse (0.8 s son 48 ticks)", numero >= 45)
	siguiente()


func _probar_tope() -> void:
	print("--- tope de numeros vivos ---")
	_ok("antes de la tanda no queda ninguno", NumeroFlotante.cantidad_vivos() == 0)
	var tanda: Array[NumeroFlotante] = []
	for i in 45:
		tanda.append(NumeroFlotante.mostrar(_capa, Vector3(float(i) * 0.1, 1.5, 2.0),
				"+%d" % i, NumeroFlotante.COLOR_CURA, 1.0, true))
	var vivos := NumeroFlotante.cantidad_vivos()
	_ok("45 seguidos dejan 40 vivos (%d)" % vivos, vivos == 40)
	var viejos_fuera := true
	for i in 5:
		viejos_fuera = viejos_fuera and tanda[i].is_queued_for_deletion()
	_ok("se van los 5 mas viejos", viejos_fuera)
	var nuevos_quedan := true
	for i in range(5, 45):
		nuevos_quedan = nuevos_quedan and not tanda[i].is_queued_for_deletion()
	_ok("y quedan los 40 mas nuevos", nuevos_quedan)
	siguiente()


func _esperar_tope() -> void:
	if _ticks == 1:
		var hijos := _capa.get_child_count()
		_ok("un tick despues, en el arbol quedan 40 (%d)" % hijos, hijos == 40)
	if _capa.get_child_count() > 0 and _ticks < 90:
		return
	_ok("todos se liberan solos antes de 1.5 s (tick %d)" % _ticks, _capa.get_child_count() == 0)
	_ok("y la lista de vivos queda vacia", NumeroFlotante.cantidad_vivos() == 0)
	terminar()


# --- Ayudas -------------------------------------------------------------------

## Lo que todos comparten: quad chico sin textura, sin luz, color por vertice,
## transparente, mirando a la camara y sin sombra.
func _probar_dibujo(nombre: String, emisor: CPUParticles3D) -> void:
	var quad := emisor.mesh as QuadMesh
	var material: StandardMaterial3D = quad.material as StandardMaterial3D if quad != null else null
	_ok("%s: quad chico (%.2f m)" % [nombre, quad.size.x if quad != null else -1.0],
		quad != null and quad.size.x > 0.0 and quad.size.x <= 0.5)
	_ok("%s: sin luz, color por vertice, alfa y billboard, sin textura" % nombre,
		material != null
		and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		and material.vertex_color_use_as_albedo
		and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
		and material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED
		and material.billboard_keep_scale
		and material.albedo_texture == null)
	_ok("%s: sin sombra" % nombre,
		emisor.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_ok("%s: se libera solo" % nombre, emisor.finished.is_connected(emisor.queue_free))


## Tamano de una mota en metros en un punto de su vida (0 al nacer, 1 al final).
func _tamano(emisor: CPUParticles3D, vida: float) -> float:
	var quad := emisor.mesh as QuadMesh
	if quad == null or emisor.scale_amount_curve == null:
		return -1.0
	return quad.size.x * emisor.scale_amount_max * emisor.scale_amount_curve.sample(vida)


## La mota cuelga del borde de abajo del quad: nace a ras del piso sin que la
## mitad quede debajo.
func _apoyada(emisor: CPUParticles3D) -> bool:
	var quad := emisor.mesh as QuadMesh
	return quad != null and is_equal_approx(quad.center_offset.y, quad.size.y * 0.5)


## Algun punto del degrade tiene ese color, sin mirar el alfa.
func _rampa_usa(emisor: CPUParticles3D, color: Color) -> bool:
	if emisor.color_ramp == null:
		return false
	for c in emisor.color_ramp.colors:
		if Color(c, 1.0).is_equal_approx(Color(color, 1.0)):
			return true
	return false


func _termina_transparente(emisor: CPUParticles3D) -> bool:
	return emisor.color_ramp != null and emisor.color_ramp.sample(1.0).a < 0.01


## Alto de una linea de la fuente que usa el numero, en metros.
func _alto_linea(numero: Label3D) -> float:
	var fuente := numero.font if numero.font != null else ThemeDB.fallback_font
	return fuente.get_height(numero.font_size) * numero.pixel_size


func _parametro(material: ShaderMaterial, nombre: StringName) -> float:
	var valor: Variant = material.get_shader_parameter(nombre)
	return float(valor) if valor != null else -1.0


## Anota el tick en el que se vio liberado por primera vez. Variant y no un tipo:
## pasar un objeto ya liberado a un parametro tipado es un error en si mismo.
func _anotar(nombre: String, nodo: Variant) -> void:
	if not _liberado.has(nombre) and not is_instance_valid(nodo):
		_liberado[nombre] = _ticks
