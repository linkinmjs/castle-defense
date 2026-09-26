extends PruebaBase
## Lo que el HUD muestra de los combos: el renglon "x2 VENDAJE", el festejo
## del remate y los avisos, que salen del componente y no del healer.
##
## Instancia el HUD a proposito, pero solo para mirar el HUD: el modelo de
## combate se sigue probando sin interfaz en las demas suites.

const ORIGEN := Vector3(15, 0, 5)
const ENTRE_BOTONES := 24

var _hud: CanvasLayer
var _healer: Healer3D
var _aliado: Unidad3D


func preparar() -> void:
	var contenedor := Node3D.new()
	root.add_child(contenedor)
	_healer = load("res://scenes/3d/healer3d.tscn").instantiate()
	_healer.position = ORIGEN
	contenedor.add_child(_healer)
	_aliado = load("res://scenes/3d/unidad3d.tscn").instantiate()
	_aliado.configurar(Unidad3D.Bando.ALIADO)
	_aliado.position = ORIGEN + Vector3(1.0, 0, 0)
	_aliado.probabilidad_sangrado = 0.0
	contenedor.add_child(_aliado)
	_hud = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(_hud)


func fase(numero: int) -> void:
	match numero:
		0:
			if _ticks < 2:
				return
			_aliado.set_physics_process(false)
			_aliado.vida = 10.0
			_hud.seguir(_healer)
			print("--- la leyenda y el combo al arrancar ---")
			_ok("la leyenda nombra los controles del jugador 1",
				_texto(&"Leyenda") == "Mover WASD / Stick · Ligera J / X · Pesada K / Y · Saltar Espacio / A")
			_ok("sin combo no se ve nada", not _hud.combo_visible())

			print("--- L, L, P: el combo se cuenta y el remate se festeja ---")
			_healer.pulsar(&"ligera")
			_ok("tras la ligera dice x1 TOQUE (%s)" % _texto(&"Combo"),
				_hud.combo_visible() and _texto(&"Combo") == "x1 TOQUE")
			_ok("y el aviso dice lo que entro (%s)" % _texto(&"Aviso"), _texto(&"Aviso") == "+18")
			siguiente()
		1:
			if _ticks < ENTRE_BOTONES:
				return
			_healer.pulsar(&"ligera")
			_ok("tras dos dice x2 VENDAJE (%s)" % _texto(&"Combo"), _texto(&"Combo") == "x2 VENDAJE")
			siguiente()
		2:
			if _ticks < ENTRE_BOTONES:
				return
			_healer.pulsar(&"pesada")
			_ok("el remate se ve aunque el combo ya se cerro (%s)" % _texto(&"Combo"),
				_hud.combo_visible() and _texto(&"Combo") == "x3 OLEADA")
			_ok("y el aviso nombra la Oleada (%s)" % _texto(&"Aviso"),
				_texto(&"Aviso").begins_with("Oleada"))
			siguiente()
		3:
			# El festejo dura algo mas de un segundo y se apaga solo.
			if _ticks < 120:
				return
			_ok("un rato despues el remate se apago", not _hud.combo_visible())

			print("--- los cortes que no son remate apagan el combo en el acto ---")
			_healer.pulsar(&"ligera")
			_ok("una ligera vuelve a abrir el combo", _hud.combo_visible())
			_healer.recibir_dano(1.0)
			_ok("un golpe lo apaga", not _hud.combo_visible())
			siguiente()
		4:
			if _ticks < ENTRE_BOTONES:
				return
			print("--- el golpe al aire se avisa mas bajo ---")
			_healer._sprite.flip_h = true
			_healer.pulsar(&"ligera")
			_healer._sprite.flip_h = false
			var aviso := _hud.get_node("%Aviso") as Label
			_ok("dice que fue en vacio (%s)" % aviso.text, aviso.text == ComponenteCombos.EN_VACIO)
			_ok("a media opacidad (%.2f)" % aviso.modulate.a, aviso.modulate.a < 0.6)
			_healer.mana = 0.0
			_healer.pulsar(&"pesada")
			_ok("un rechazo de verdad va a pleno (%s)" % aviso.text,
				aviso.text == "Sin mana" and aviso.modulate.a > 0.99)
			terminar()


func _texto(nodo: StringName) -> String:
	return (_hud.get_node("%" + String(nodo)) as Label).text
