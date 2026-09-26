extends SceneTree
## Capturas de un combo entero: despues de L, de L, L y de L, L, P (la
## Oleada). Sirven para ver el aviso de cada movimiento y el renglon del combo
## sobre las barras, que el remate deja un momento en pantalla.
##
## Correr SIN --headless: sin ventana no hay textura que guardar.
##   godot --path godot --script res://tools/captura_combos.gd

const MOVIMIENTOS: Array[String] = [
	"toque", "vendaje", "plegaria", "bendicion", "oleada", "reanimar", "impulso", "caida",
]
## Entre boton y boton: mas que la recuperacion de la ligera (0.3 s) y menos
## que la ventana del combo (0.7 s).
const PAUSA := 0.4
## Lo que se deja pasar entre apretar y sacar la foto: que el efecto arranque.
const REVELADO := 0.15

var _battle: Node
var _healer: Healer3D
var _hud: CanvasLayer
var _paciente: Unidad3D
var _inicio_ms := 0
var _paso := 0
var _proximo := 2.0


func _initialize() -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	root.add_child(_battle)
	_inicio_ms = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if _healer == null:
		_healer = _battle.get_node_or_null("%Healer")
		_hud = _battle.get_node_or_null("%HUD")
		if _healer == null:
			return false

	var t := (Time.get_ticks_msec() - _inicio_ms) / 1000.0
	if t < _proximo:
		return false

	match _paso:
		0:
			# La campania arranca con Toque solo: el remate necesita todo.
			_healer.get_node("Combos").equipar(_todos())
			_paciente = _mas_atras()
			_paciente.vida = _paciente.vida_maxima * 0.35
			_apretar(&"ligera")
		1:
			_foto("combo_1_ligera.png")
		2:
			_apretar(&"ligera")
		3:
			_foto("combo_2_ligera_ligera.png")
		4:
			_apretar(&"pesada")
		5:
			_foto("combo_3_remate.png")
		6:
			print("listo")
			return true
	return false


## Se para 0.8 m detras del paciente, mirando hacia el, y aprieta. Se vuelve a
## parar antes de cada boton: la linea lo corre un poco entre uno y otro.
func _apretar(entrada: StringName) -> void:
	_healer.global_position = _paciente.global_position - Vector3(0.8, 0, 0)
	_healer._sprite.flip_h = false
	var salio := _healer.pulsar(entrada)
	print("%-7s -> %s" % [entrada, "sale" if salio else "no sale"])
	_paso += 1
	_proximo += REVELADO


func _foto(nombre: String) -> void:
	root.get_texture().get_image().save_png("user://" + nombre)
	var combo := _hud.get_node("%Combo") as Label
	var aviso := _hud.get_node("%Aviso") as Label
	print("  %-26s combo=\"%s\" (%s)  aviso=\"%s\"" % [
		nombre, combo.text, "se ve" if _hud.combo_visible() else "oculto", aviso.text])
	_paso += 1
	_proximo += PAUSA - REVELADO


## El aliado mas lejos del frente: ahi al healer no le pega nadie, y un golpe
## le cortaria el combo a mitad de la foto.
func _mas_atras() -> Unidad3D:
	var mejor: Unidad3D = null
	for u: Unidad3D in root.get_tree().get_nodes_in_group("aliados"):
		if not u.esta_viva() or u.esta_derribada():
			continue
		if mejor == null or u.global_position.x < mejor.global_position.x:
			mejor = u
	return mejor


func _todos() -> Array[Movimiento]:
	var lista: Array[Movimiento] = []
	for archivo in MOVIMIENTOS:
		lista.append(load("res://resources/movimientos/%s.tres" % archivo))
	return lista
