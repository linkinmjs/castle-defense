extends CanvasLayer
## HUD de la batalla, a la manera de un beat-em-up: una ficha por jugador en
## las esquinas de arriba, entre las dos la barra del nivel, el encuentro y
## los conteos; el cartel de avanzar a la derecha, la barra del jefe y los
## controles abajo, y el desenlace al centro.
##
## Arriba el campo es cielo: todo lo que queda puesto va ahi o en el borde de
## abajo, y el centro se deja libre para la linea de combate. Lo que aparece
## en el medio (el cartel de avanzar, el desenlace) aparece cuando no hay nada
## que curar.
##
## Lo de cada jugador (barras, combo, avisos, tarjeta) lo lleva su
## FichaJugador, y cada pieza de lo que es de todos escucha a la batalla por
## su cuenta (BarraNivel, EncabezadoSector, CartelAvanzar, BarraJefe). Aca se
## reparte que ficha y que leyenda le toca a cada healer, y se lleva el cierre.
##
## El segundo jugador puede entrar en cualquier momento: la batalla avisa con
## jugador_agregado. Hasta entonces su esquina lo invita a entrar y su leyenda
## no se muestra: con uno solo, los controles del otro serian ruido.

const COLOR_VICTORIA := Color("9fd88f")
const COLOR_DERROTA := Color("e07a6a")
## Lo que dice el pie del resumen: las dos salidas del final.
const PIE_RESUMEN := "R / Back repetir · Enter / Start seguir"
## El cartel del final entra chico y crece, y al llegar se sacude apenas.
const ESCALA_DESENLACE := 0.6
const ENTRADA_DESENLACE := 0.3
const SACUDON: Array[Vector2] = [
	Vector2(6, -2), Vector2(-5, 2), Vector2(4, -1), Vector2(-2, 1), Vector2.ZERO,
]
const PASO_SACUDON := 0.04
## El velo que apaga el campo detras del informe.
const ALFA_VELO := 0.5
const ENTRADA_VELO := 0.3

@onready var _fichas: Array[FichaJugador] = [%Ficha1, %Ficha2]
@onready var _leyendas: Array[Label] = [%Leyenda, %Leyenda2]
@onready var _invitacion: Label = %Invitacion
@onready var _contadores: Label = %Contadores
@onready var _barra_nivel: BarraNivel = %BarraNivel
@onready var _encabezado: EncabezadoSector = %Encabezado
@onready var _cartel: CartelAvanzar = %CartelAvanzar
@onready var _barra_jefe: BarraJefe = %BarraJefe
@onready var _velo: ColorRect = %VeloFinal
@onready var _desenlace: Label = %Desenlace
@onready var _resumen: ResumenEncuentro = %Resumen

var _battle: Node
var _encuentro: Encuentro
## Si la batalla deja entrar a un jugador con el encuentro andando. Sin eso no
## se invita a nadie: el cartel prometeria algo que no pasa.
var _admite_ingreso: bool = false
var _tween_final: Tween


func _ready() -> void:
	_desenlace.visible = false
	_resumen.visible = false
	_velo.visible = false
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


## Engancha el HUD a la batalla. Lo que es de todos escucha por su cuenta; las
## senales de sectores y jefes son de una batalla que todavia no existe en
## todas las ramas, y cada pieza pregunta si estan antes de conectarse.
func seguir_batalla(battle: Node) -> void:
	_battle = battle
	battle.batalla_terminada.connect(_on_batalla_terminada)
	battle.encuentro_iniciado.connect(_on_encuentro_iniciado)
	battle.telemetria().encuentro_cerrado.connect(_on_encuentro_cerrado)
	_barra_nivel.seguir(battle)
	_encabezado.seguir(battle)
	_cartel.seguir(battle)
	_barra_jefe.seguir(battle)
	# Por nombre y preguntando: una batalla de un solo jugador no la tiene, y
	# entonces no hay a quien invitar.
	_admite_ingreso = battle.has_signal(&"jugador_agregado")
	if _admite_ingreso:
		battle.connect(&"jugador_agregado", seguir)
	_actualizar_invitacion()


# --- Lo que leen las pruebas y las capturas -----------------------------------

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


func barra_nivel() -> BarraNivel:
	return _barra_nivel


func encabezado() -> EncabezadoSector:
	return _encabezado


func cartel_avanzar() -> CartelAvanzar:
	return _cartel


func barra_jefe() -> BarraJefe:
	return _barra_jefe


func resumen() -> ResumenEncuentro:
	return _resumen


## "VICTORIA" o "DERROTA" si el cartel del final esta puesto; "" si no.
func desenlace() -> String:
	return _desenlace.text if _desenlace.visible else ""


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
		aliados += " (%d en el suelo)" % caidos
	_contadores.text = "%s · Enemigos %d" % [aliados, _vivos("enemigos")]


# --- Encuentro y cierre -------------------------------------------------------

func _on_encuentro_iniciado(encuentro: Encuentro, _semilla: int, _indice_encuentro: int) -> void:
	_encuentro = encuentro
	_cortar_final()
	_desenlace.visible = false
	_velo.visible = false
	_resumen.ocultar()


## "VICTORIA" o "DERROTA": entra chico y crece (0.6 -> 1 en 0.3 s), se sacude
## apenas al llegar, y el campo se apaga detras. Sin el "R para reiniciar":
## eso lo dice el pie del resumen, que sale justo debajo.
func _on_batalla_terminada(victoria: bool) -> void:
	_desenlace.text = "VICTORIA" if victoria else "DERROTA"
	_desenlace.add_theme_color_override("font_color",
		COLOR_VICTORIA if victoria else COLOR_DERROTA)
	_desenlace.visible = true
	_velo.visible = true

	_cortar_final()
	_desenlace.offset_transform_scale = Vector2(ESCALA_DESENLACE, ESCALA_DESENLACE)
	_desenlace.offset_transform_position = Vector2.ZERO
	_desenlace.modulate.a = 0.0
	_velo.modulate.a = 0.0
	_tween_final = create_tween().set_parallel(true)
	_tween_final.tween_property(_desenlace, "offset_transform_scale", Vector2.ONE,
		ENTRADA_DESENLACE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_final.tween_property(_desenlace, "modulate:a", 1.0, ENTRADA_DESENLACE * 0.5)
	_tween_final.tween_property(_velo, "modulate:a", 1.0, ENTRADA_VELO)
	# El sacudon va despues de la entrada, paso por paso.
	for paso in SACUDON:
		_tween_final.chain().tween_property(_desenlace, "offset_transform_position", paso,
			PASO_SACUDON)


## El desenlace dice como termino; esto, por que. Los datos llegan como
## Dictionary y texto plano: el HUD no conoce la telemetria.
func _on_encuentro_cerrado(datos: Dictionary) -> void:
	# Sin encuentro, una lista vacia del tipo justo: un [] suelto no entra en
	# un Array[MetaEncuentro].
	var metas: Array[MetaEncuentro] = []
	if _encuentro != null:
		metas = _encuentro.metas
	var titulo: String = _encuentro.titulo if _encuentro != null else "Encuentro"
	_resumen.mostrar(titulo, datos, _battle.telemetria().observacion_causal(), metas, PIE_RESUMEN)


func _cortar_final() -> void:
	if _tween_final != null and _tween_final.is_valid():
		_tween_final.kill()
	_tween_final = null
	_desenlace.offset_transform_scale = Vector2.ONE
	_desenlace.offset_transform_position = Vector2.ZERO
	_desenlace.modulate.a = 1.0


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
