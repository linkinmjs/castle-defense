extends PruebaBase
## Reglas de curacion y sangrado vistas desde los botones: lo que cobra cada
## movimiento, lo que avisa y lo que pasa cuando no hay a quien curar.
## test_combos.gd recorre la tabla entera; esta se queda con lo que el jugador
## tiene que entender primero.

const ORIGEN := Vector3(15, 0, 5)
## Un paso de recuperacion de la ligera (0.3 s) y bastante menos que la ventana
## del combo (0.7 s): lo que tarda un jugador en apretar dos veces.
const ENTRE_LIGERAS := 24

var _healer: Healer3D
var _combos: ComponenteCombos
var _aliado: Unidad3D
var _avisos: Array[String] = []


func preparar() -> void:
	var contenedor := Node3D.new()
	root.add_child(contenedor)

	_healer = load("res://scenes/3d/healer3d.tscn").instantiate()
	_healer.position = ORIGEN
	contenedor.add_child(_healer)
	# Sin regeneracion: cada comprobacion de mana mide solo lo que se cobro.
	_healer.regeneracion_mana = 0.0

	# Sin tipo: 80 de vida maxima. A 1.2 m al frente, dentro de la caja de la
	# ligera, y quieto: la prueba mide al healer, no el combate.
	_aliado = load("res://scenes/3d/unidad3d.tscn").instantiate()
	_aliado.configurar(Unidad3D.Bando.ALIADO)
	_aliado.position = ORIGEN + Vector3(1.2, 0, 0)
	contenedor.add_child(_aliado)
	_aliado.probabilidad_sangrado = 0.0


func fase(numero: int) -> void:
	match numero:
		0:
			if _ticks < 2:
				return
			# Recien aca: antes de su _ready el motor le volveria a prender la
			# fisica.
			_aliado.set_physics_process(false)
			_combos = _healer.get_node("Combos")
			_combos.aviso.connect(func(t: String) -> void: _avisos.append(t))
			_combos.movimiento_fallo.connect(
				func(_m: Movimiento, motivo: String) -> void: _avisos.append(motivo))

			print("--- overhealing: lo que sobra se pierde ---")
			_preparar(70.0)  # de 80: de los 18 solo entran 10
			_ok("la ligera sale", _healer.pulsar(&"ligera"))
			_igual("tope en vida maxima", _aliado.vida, 80.0)
			_igual("cobra el costo completo igual", _healer.mana, 90.0)
			_ok("avisa el desperdicio (%s)" % _todos(), _tiene_aviso("desperdiciado"))
			siguiente()
		1:
			print("--- Toque no corta el sangrado; Vendaje si ---")
			_preparar(40.0)
			_aliado.sangrado_restante = 8.0
			_healer.pulsar(&"ligera")
			_ok("la primera ligera es Toque", _tiene_aviso("+18"))
			_ok("y sigue sangrando", _aliado.esta_sangrando())
			_igual("Toque cobra 10", _healer.mana, 90.0)
			siguiente()
		2:
			if _ticks < ENTRE_LIGERAS:
				return
			var vida := _aliado.vida
			_avisos.clear()
			_ok("la segunda ligera sale", _healer.pulsar(&"ligera"))
			_ok("es Vendaje y lo avisa", _tiene_aviso("Vendaje: sangrado cortado"))
			_igual("corta el sangrado", _aliado.sangrado_restante, 0.0)
			_igual("cura 18 ademas", _aliado.vida - vida, 18.0)
			_igual("cobra 10 (20 con el Toque)", _healer.mana, 80.0)
			siguiente()
		3:
			print("--- limites ---")
			_preparar(10.0)
			_healer.mana = 5.0
			_ok("sin mana no sale", not _healer.pulsar(&"ligera"))
			_igual("sin mana no cura", _aliado.vida, 10.0)
			_ok("avisa falta de mana", _tiene_aviso("Sin mana"))

			# 4 m adelante: fuera de los 2.4 de la caja de la ligera.
			_preparar(10.0)
			_aliado.global_position = ORIGEN + Vector3(4.0, 0, 0)
			_ok("fuera de la caja no sale", not _healer.pulsar(&"ligera"))
			_igual("no cura", _aliado.vida, 10.0)
			_igual("y no gasta: fue al aire", _healer.mana, 100.0)
			_ok("avisa que fue en vacio", _tiene_aviso(ComponenteCombos.EN_VACIO))
			_aliado.global_position = ORIGEN + Vector3(1.2, 0, 0)

			# De espaldas el mismo aliado queda atras, fuera del margen.
			_preparar(10.0)
			_healer._sprite.flip_h = true
			_ok("de espaldas tampoco sale", not _healer.pulsar(&"ligera"))
			_igual("ni cobra", _healer.mana, 100.0)
			_healer._sprite.flip_h = false
			siguiente()
		4:
			print("--- sangrado que mata ---")
			_preparar(6.0)
			_aliado.sangrado_restante = 8.0
			_aliado._actualizar_sangrado(2.0)  # 3.5/s * 2s = 7 de dano
			_ok("el sangrado puede derribar", _aliado.esta_derribada())
			terminar()


## Deja al aliado y al healer en un estado conocido, sin combo ni
## enfriamientos, para que cada caso se pueda leer solo.
func _preparar(vida: float) -> void:
	_healer.reiniciar(ORIGEN)
	_healer._sprite.flip_h = false
	_aliado.estado = Unidad3D.Estado.AVANZANDO
	_aliado.vida = vida
	_aliado.sangrado_restante = 0.0
	_avisos.clear()


func _tiene_aviso(fragmento: String) -> bool:
	for a in _avisos:
		if a.to_lower().contains(fragmento.to_lower()):
			return true
	return false


func _todos() -> String:
	return ", ".join(PackedStringArray(_avisos))
