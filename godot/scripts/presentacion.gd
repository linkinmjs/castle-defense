class_name Presentacion
extends RefCounted
## Lo que se ve y no cambia el juego: sacudidas, hit-stop, particulas, numeros
## flotantes. Todo efecto de ese tipo pregunta aca antes de hacer nada.
##
## En headless no hay nadie mirando, y ahi corren las pruebas: un hit-stop que
## frenara el tiempo o una sacudida que moviera la camara harian que la misma
## prueba midiera distinto segun cuanto tarda cada frame. Cortandolos en un
## solo lugar, las pruebas siguen deterministas sin que cada efecto tenga que
## acordarse de hacerlo.
##
## Estatico y no un autoload, igual que Opciones y Navegacion: es una pregunta
## y un reloj, no hace falta un singleton con ciclo de vida propio.

## Escala del tiempo durante un hit-stop. No es cero: congelado del todo, las
## animaciones se cortan en seco y el golpe se siente como un tiron, no como un
## peso.
const ESCALA_HIT_STOP := 0.05

## Hay un hit-stop corriendo. Con esto, un golpe que llega en el medio estira el
## que ya esta en vez de abrir otro reloj.
static var _hit_stop_en_curso: bool = false
## El reloj que devuelve la escala a 1. Se guarda para poder estirarlo.
static var _reloj_hit_stop: SceneTreeTimer = null


## Hay alguien mirando la pantalla.
static func activa() -> bool:
	return DisplayServer.get_name() != "headless"


## Frena el juego un instante para que un golpe pese.
##
## No acumula: un golpe que llega durante otro hit-stop solo lo estira hasta
## cubrir su propia duracion. Sumarlos haria que una rafaga de golpes dejara la
## pantalla en camara lenta.
static func hit_stop(arbol: SceneTree, segundos: float = 0.05) -> void:
	if not activa():
		return
	_frenar(arbol, segundos)


## El hit-stop sin preguntar por la pantalla. Separado de hit_stop() para que
## las pruebas lo puedan ejercitar en headless; el juego llama a hit_stop().
static func _frenar(arbol: SceneTree, segundos: float) -> void:
	if arbol == null or segundos <= 0.0:
		return
	Engine.time_scale = ESCALA_HIT_STOP
	if _hit_stop_en_curso and _reloj_hit_stop != null:
		_reloj_hit_stop.time_left = maxf(_reloj_hit_stop.time_left, segundos)
		return
	_hit_stop_en_curso = true
	# Ignora la escala de tiempo: con la escala en 0.05, un reloj comun tardaria
	# veinte veces lo pedido. Y corre en pausa: pausar justo despues de un golpe
	# no puede dejar el juego frenado al volver.
	_reloj_hit_stop = arbol.create_timer(segundos, true, false, true)
	_reloj_hit_stop.timeout.connect(_soltar)


static func _soltar() -> void:
	Engine.time_scale = 1.0
	_hit_stop_en_curso = false
	_reloj_hit_stop = null
