extends CanvasLayer
## HUD de la batalla: una ficha por jugador en las esquinas de arriba, el
## encuentro entre las dos, el desenlace al centro y los controles abajo.
##
## Lo de cada jugador (barras, combo, avisos, tarjeta) lo lleva su
## FichaJugador. Aca se reparte que ficha y que leyenda le toca a cada healer,
## y se muestra lo que es de todos: el frente, el encuentro en curso, los
## conteos y el cierre.
##
## El segundo jugador puede entrar en cualquier momento: la batalla avisa con
## jugador_agregado. Hasta entonces su esquina lo invita a entrar y su leyenda
## no se muestra: con uno solo, los controles del otro serian ruido.

@onready var _fichas: Array[FichaJugador] = [%Ficha1, %Ficha2]
@onready var _leyendas: Array[Label] = [%Leyenda, %Leyenda2]
@onready var _invitacion: Label = %Invitacion
@onready var _contadores: Label = %Contadores
@onready var _frente: Control = %Frente
@onready var _encabezado: Label = %Encabezado
@onready var _desenlace: Label = %Desenlace
@onready var _resumen: Control = %Resumen

var _battle: Node
var _encuentro: Encuentro
## Si la batalla deja entrar a un jugador con el encuentro andando. Sin eso no
## se invita a nadie: el cartel prometeria algo que no pasa.
var _admite_ingreso: bool = false


func _ready() -> void:
	_desenlace.visible = false
	_resumen.visible = false
	# Del segundo en adelante arrancan afuera: entran con seguir().
	for i in range(1, _fichas.size()):
		_fichas[i].visible = false
		_leyendas[i].visible = false
	_actualizar_invitacion()


## Le da a este healer la ficha y la leyenda de su jugador. La batalla llama
## con el del jugador 1 al arrancar; los que entran despues llegan por
## jugador_agregado. Repetir el mismo healer no hace nada.
func seguir(healer: Healer3D) -> void:
	if healer == null:
		return
	var i := _indice(healer.jugador)
	_fichas[i].seguir(healer)
	_fichas[i].visible = true
	_leyendas[i].seguir(healer)
	_leyendas[i].visible = true
	_actualizar_invitacion()


func seguir_batalla(battle: Node) -> void:
	_battle = battle
	battle.batalla_terminada.connect(_on_batalla_terminada)
	battle.encuentro_iniciado.connect(_on_encuentro_iniciado)
	battle.telemetria().encuentro_cerrado.connect(_on_encuentro_cerrado)
	_frente.seguir(battle)
	# Por nombre y preguntando: una batalla de un solo jugador no la tiene, y
	# entonces no hay a quien invitar.
	_admite_ingreso = battle.has_signal(&"jugador_agregado")
	if _admite_ingreso:
		battle.connect(&"jugador_agregado", seguir)
	_actualizar_invitacion()


## La ficha de ese jugador. Un numero fuera de rango da la mas cercana.
func ficha(jugador: int) -> FichaJugador:
	return _fichas[_indice(jugador)]


func leyenda(jugador: int) -> Label:
	return _leyendas[_indice(jugador)]


## Si el combo de ese jugador se esta viendo. Sin decir cual, el del primero:
## es lo que miran las capturas del HUD de uno solo.
func combo_visible(jugador: int = 1) -> bool:
	return ficha(jugador).combo_visible()


## Si la esquina del segundo esta invitandolo a entrar.
func invitando() -> bool:
	return _invitacion.visible


func _indice(jugador: int) -> int:
	return clampi(jugador, 1, _fichas.size()) - 1


## "Jugador 2: apreta un boton para entrar", en el lugar de su ficha mientras
## no entro.
func _actualizar_invitacion() -> void:
	_invitacion.visible = _admite_ingreso and not _fichas[1].visible


func _process(_delta: float) -> void:
	var aliados := "Aliados %d" % _vivos("aliados")
	var caidos := _derribados("aliados")
	if caidos > 0:
		aliados += "  (%d en el suelo)" % caidos
	_contadores.text = "%s      Enemigos %d" % [aliados, _vivos("enemigos")]


func _on_encuentro_iniciado(encuentro: Encuentro, _semilla: int, indice: int) -> void:
	_encuentro = encuentro
	_desenlace.visible = false
	_resumen.ocultar()
	if encuentro == null:
		_encabezado.text = ""
		return
	_encabezado.text = "%d. %s\n%s" % [
		indice + 1, encuentro.titulo, encuentro.objetivo_pedagogico]


func _on_batalla_terminada(victoria: bool) -> void:
	# Sin el "R para reiniciar": ahora eso lo dice el pie del resumen, que sale
	# justo debajo y explica ademas que hace Enter.
	_desenlace.text = "VICTORIA" if victoria else "DERROTA"
	_desenlace.add_theme_color_override("font_color",
		Color("9fd88f") if victoria else Color("e07a6a"))
	_desenlace.visible = true


## El desenlace dice como termino; esto, por que. Los datos llegan como
## Dictionary y texto plano: el HUD no conoce la telemetria.
func _on_encuentro_cerrado(datos: Dictionary) -> void:
	var metas: Array[MetaEncuentro] = _encuentro.metas if _encuentro != null else []
	var titulo: String = _encuentro.titulo if _encuentro != null else "Encuentro"
	_resumen.mostrar(
		titulo, datos, _battle.telemetria().observacion_causal(), metas,
		"R / Back para repetir el mismo     Enter / Start para seguir")


func _derribados(grupo: String) -> int:
	var total := 0
	for unidad in get_tree().get_nodes_in_group(grupo):
		if unidad.esta_viva() and unidad.esta_derribada():
			total += 1
	return total


func _vivos(grupo: String) -> int:
	var total := 0
	for unidad in get_tree().get_nodes_in_group(grupo):
		if unidad.esta_viva():
			total += 1
	return total
