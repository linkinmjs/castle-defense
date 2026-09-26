class_name Vineta
extends CanvasLayer
## Oscurece apenas los bordes de la pantalla, y los tine de rojo un instante
## cuando el healer recibe un golpe.
##
## El borde rojo avisa el golpe sin que haga falta mirar la barra de vida: el
## healer pasa la pelea mirando a sus soldados, no a si mismo. La sombra de base
## junta la mirada en el centro, que es donde esta la pelea.
##
## Es un ColorRect a pantalla completa con un shader que pinta un degrade
## encima (assets/shaders/vineta.gdshader). El rect es transparente: si el
## shader no compilara, no tapa nada. Se arma entera en _init para que se pueda
## usar (y probar) antes de entrar al arbol, y en headless funciona igual,
## aunque nadie la vea.

const SHADER := preload("res://assets/shaders/vineta.gdshader")
## Grupo en el que se anota. Quien recibe el golpe no necesita tenerla a mano:
## get_tree().call_group(Vineta.GRUPO, &"pulsar_dano", fuerza).
const GRUPO := &"vineta"
## Sobre las barras de las unidades y el HUD (capa 1), debajo del menu de pausa
## (capa 10).
const CAPA := 5
## Oscuridad de los bordes si nadie pide otra.
const INTENSIDAD_BASE := 0.35
## Segundos que tarda en apagarse un pulso entero (dano 1). Uno mas debil tarda
## lo proporcional.
const DURACION_PULSO := 0.6

var _rect: ColorRect
var _material: ShaderMaterial
var _dano: float = 0.0
var _intensidad: float = INTENSIDAD_BASE


func _init() -> void:
	layer = CAPA
	add_to_group(GRUPO)
	# El pulso se sigue apagando con el juego en pausa: pausar justo despues
	# de un golpe no puede dejar el borde rojo fijo debajo del menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.name = "Rect"
	_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.material = _material
	add_child(_rect)
	_aplicar()


func _process(delta: float) -> void:
	if _dano <= 0.0:
		return
	_dano = maxf(_dano - delta / DURACION_PULSO, 0.0)
	_aplicar()


## Un golpe al healer. El rojo salta a fuerza (0 a 1) sin bajar uno que ya
## estaba mas fuerte, y se apaga solo en DURACION_PULSO * fuerza segundos.
func pulsar_dano(fuerza: float = 1.0) -> void:
	_dano = maxf(_dano, clampf(fuerza, 0.0, 1.0))
	_aplicar()


## Cuanto se oscurecen los bordes, de 0 (nada) a 1.
func set_intensidad(valor: float) -> void:
	_intensidad = clampf(valor, 0.0, 1.0)
	_aplicar()


## El pulso de dano que se esta viendo ahora, de 0 a 1.
func dano_actual() -> float:
	return _dano


func _aplicar() -> void:
	_material.set_shader_parameter(&"intensidad", _intensidad)
	_material.set_shader_parameter(&"dano", _dano)
	# Sin sombra ni pulso no hay nada que pintar: no hace falta cubrir la
	# pantalla con un rect invisible.
	_rect.visible = _intensidad > 0.0 or _dano > 0.0
