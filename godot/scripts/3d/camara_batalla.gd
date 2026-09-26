class_name CamaraBatalla
extends Camera3D
## Camara lateral de la batalla: mira el campo de costado y un poco desde
## arriba, y solo se traslada sobre X.
##
## Antes vivia repartida en battle3d.gd, y la matematica es la misma: rotacion
## fija, mira un punto a la altura del pecho en la mitad de la profundidad, se
## para sobre el eje de vision a distancia fija, sigue con zona muerta y
## suavizado, y nunca muestra mas alla de los bordes del campo. Lo nuevo:
## - sigue a varios jugadores a la vez, por el punto medio entre los de las
##   puntas;
## - calcula en que rango de X tiene que quedarse cada jugador para no salir de
##   cuadro, como en un beat-em-up (el healer lo lee y se recorta solo);
## - respeta el limite del sector en curso;
## - si un jugador empuja contra el borde de la pantalla, corre la vista hacia
##   ese lado;
## - sacudida y punch de fov, que solo corren si hay pantalla (Presentacion).
##
## No tiene _process propio: la batalla llama a actualizar() desde el suyo. Asi
## el orden contra el resto del frame lo decide ella, y una prueba la avanza a
## mano con el delta que quiera.

## A cuanto del borde de su rango (en m) un jugador cuenta como pegado a el. El
## healer se recorta contra el rango de la X anterior, asi que queda justo en el
## borde o a un redondeo de distancia.
const TOLERANCIA_BORDE := 0.05
## Metros de Z que la batalla deja libres a cada lado del campo: la fila mas
## cercana a la camara por la que puede andar un jugador esta a esa distancia
## del borde.
const MARGEN_PROFUNDIDAD := 1.5
## Altura a la que se mide el ancho de pantalla de un jugador: el pecho, con el
## margen_jugador cubriendo el resto del cuerpo.
const ALTURA_PECHO := 1.0
## Frecuencias de la sacudida en X y en Y, en rad/s. Distintas y sin multiplo
## comun para que el dibujo no se repita; altas para que se lea como temblor y
## no como vaiven.
const FRECUENCIA_SACUDIDA := Vector2(97.0, 73.0)

## Cuanto se aleja la camara del punto que mira, sobre el eje de vision.
@export var distancia: float = 11.0
## Angulo picado, en grados: 0 seria de perfil puro, 90 seria cenital.
@export var angulo: float = 15.0
## La camara mira a la altura del pecho, no a los pies.
@export var altura_objetivo: float = 1.05
## Que tan rapido alcanza la X que quiere mirar. Es exponencial: con 4 recorre
## el 98 % del camino en un segundo, sin frenar de golpe al llegar.
@export var suavizado: float = 4.0
## Ventana alrededor del punto que mira la camara: mientras el punto medio de
## los jugadores se mueva dentro de ella, la camara no se mueve. Sin esto
## acompana cada pasito.
@export var zona_muerta: float = 1.8
## Cuanto antes del borde de la pantalla se frena un jugador. Su X es el centro
## del sprite: sin margen quedaria medio cuerpo afuera.
@export var margen_jugador: float = 0.8
## A que velocidad (m/s) se corre la vista cuando un jugador empuja contra el
## borde. Mas lenta que caminar, para que el borde se sienta como un borde.
@export var empuje_borde: float = 1.5

## A quienes sigue: uno o dos healers.
var _seguidos: Array[Node3D] = []
## Profundidad del campo: la camara mira siempre a su mitad.
var _profundidad: float = 0.0
## Bordes del campo en X. Sin configurar no hay bordes.
var _x_min: float = -INF
var _x_max: float = INF
## Borde derecho del sector en curso. INF es que no hay sector.
var _limite_x: float = INF
## X que la camara quiere mirar. Solo se mueve cuando el punto medio de los
## seguidos sale de la zona muerta o cuando alguno empuja un borde, y nunca
## queda fuera de los recortes.
var _x_objetivo: float = 0.0
## X en la que esta la camara, persiguiendo a _x_objetivo con suavizado. Es la
## que se ve, asi que es la que vale para recortar a los jugadores.
var _x_actual: float = 0.0
## El fov sin punch. Solo se usa mientras hay un punch: fuera de eso el fov de
## la camara ya es el base.
var _fov_base: float = 0.0

var _sacudida_amplitud: float = 0.0
var _sacudida_duracion: float = 0.0
var _sacudida_restante: float = 0.0
## Reloj propio de la sacudida. El dibujo sale de aca y no de randf: la misma
## secuencia de golpes se ve siempre igual.
var _sacudida_reloj: float = 0.0
var _punch_delta: float = 0.0
var _punch_duracion: float = 0.0
var _punch_restante: float = 0.0


## Fija el campo que la camara puede mostrar: de x_min a x_max en X, y en
## profundidad mira siempre la mitad. Va al empezar cada encuentro, antes de
## saltar_a(). Borra el limite de sector: el que haga falta se pide despues,
## asi el de un encuentro no se filtra al siguiente.
func configurar(profundidad: float, x_min: float, x_max: float) -> void:
	_cortar_efectos()
	_profundidad = profundidad
	_x_min = x_min
	_x_max = x_max
	_limite_x = INF
	_fov_base = fov
	# Rotacion fija de una vez: la camara nunca gira, solo se traslada. Si se
	# le hiciera look_at cada frame mientras la posicion va con retraso, el
	# yaw iria corrigiendo y la vista se ladearia al caminar.
	rotation_degrees = Vector3(-angulo, 0.0, 0.0)
	# Lo que miraba antes puede haber quedado fuera del campo nuevo.
	var mitad := mitad_visible()
	_x_objetivo = _recortar(_x_objetivo, mitad)
	_x_actual = _recortar(_x_actual, mitad)
	_colocar()


## A quienes sigue. Se copia la lista: cambiarla despues no cambia a quien sigue
## hasta volver a llamar a esto.
func seguir(objetivos: Array[Node3D]) -> void:
	_seguidos = objetivos.duplicate()


## Limite del sector en curso: el borde derecho de lo que se ve no pasa de
## x_max hasta que se libere con INF. Si la camara ya estaba mas alla, vuelve
## con el suavizado de siempre en vez de saltar.
func limitar_x(x_max: float) -> void:
	_limite_x = x_max


## Un paso de la camara. La llama la batalla desde su _process.
func actualizar(delta: float) -> void:
	var mitad := mitad_visible()
	var mitad_jug := mitad_jugadores()
	# El rango contra el que se recortaron los jugadores en su ultimo paso de
	# fisica: el de la X de antes de mover la camara.
	var rango := _rango(mitad_jug)
	var minimo := INF
	var maximo := -INF
	var empuja_derecha := false
	var empuja_izquierda := false
	for nodo in _seguidos:
		# Un healer caido cuenta igual: sigue en el campo y no puede quedar
		# fuera de cuadro. No cuenta el que ya no existe o se esta por borrar,
		# ni el que salio del arbol, que no tiene posicion global.
		if not is_instance_valid(nodo) or nodo.is_queued_for_deletion() \
				or not nodo.is_inside_tree():
			continue
		var x := nodo.global_position.x
		minimo = minf(minimo, x)
		maximo = maxf(maximo, x)
		var vx := _velocidad_x(nodo)
		if vx > 0.0 and x >= rango.y - TOLERANCIA_BORDE:
			empuja_derecha = true
		elif vx < 0.0 and x <= rango.x + TOLERANCIA_BORDE:
			empuja_izquierda = true

	# Sin nadie a quien seguir se queda donde esta, dentro de los recortes.
	if minimo <= maximo:
		# El punto medio entre las puntas y no el promedio: con tres o mas, el
		# promedio se corre hacia donde hay mas gente y deja al de la punta
		# mas cerca del borde que al resto.
		var medio := (minimo + maximo) * 0.5
		_x_objetivo = clampf(_x_objetivo, medio - zona_muerta, medio + zona_muerta)
		_x_objetivo = _empujar(_x_objetivo, empuja_derecha, empuja_izquierda,
				minimo, maximo, mitad_jug, delta)
	_x_objetivo = _recortar(_x_objetivo, mitad)
	_x_actual = lerpf(_x_actual, _x_objetivo, 1.0 - exp(-suavizado * delta))
	_avanzar_efectos(delta)
	_colocar()


## Pone la camara en x sin suavizado, dentro de los recortes. Para el arranque y
## el reinicio de un encuentro: deslizarse desde donde quedo el anterior marea.
func saltar_a(x: float) -> void:
	_cortar_efectos()
	_x_objetivo = _recortar(x, mitad_visible())
	_x_actual = _x_objetivo
	_colocar()


## Media anchura que entra en pantalla a la distancia del punto que mira: cuanto
## campo se ve a cada lado de la X de la camara. Es la cuenta de battle3d.gd.
##
## El fov de Camera3D es vertical (keep_aspect en KEEP_HEIGHT, el de siempre):
## la media altura a esa distancia es tan(fov/2)*distancia, y el aspecto la
## pasa a anchura. Se mide sobre el plano del punto que mira, a la altura del
## pecho; el suelo, un poco mas lejos, muestra apenas mas, asi que el recorte
## peca de prudente. Usa el fov sin punch: un efecto no puede achicarle la
## pantalla a los jugadores.
func mitad_visible() -> float:
	return tan(deg_to_rad(_fov_sin_efectos() * 0.5)) * distancia * _aspecto()


## Entre que X puede estar un jugador sin salir de cuadro, segun lo que se ve
## ahora. El healer se recorta contra esto despues de moverse.
func rango_x_jugadores() -> Vector2:
	return _rango(mitad_jugadores())


## Media anchura que entra en pantalla en la fila mas cercana a la camara por
## la que puede andar un jugador. Mas cerca de la camara entra menos campo:
## medida en el plano del medio, un healer en la fila delantera quedaba fuera
## de cuadro contra el borde. La batalla deja MARGEN_PROFUNDIDAD de Z libre a
## cada lado del campo, asi que esa es la fila delantera.
func mitad_jugadores() -> float:
	return mitad_visible_en(_profundidad - MARGEN_PROFUNDIDAD, ALTURA_PECHO)


## Media anchura visible en el plano paralelo a la camara que pasa por un punto
## del mundo a esa profundidad y altura (la X no importa). Es la distancia
## perpendicular a la camara por la tangente del medio fov y el aspecto.
func mitad_visible_en(z: float, y: float = 0.0) -> float:
	var radianes := deg_to_rad(angulo)
	var camara_y := altura_objetivo + sin(radianes) * distancia
	var camara_z := _profundidad * 0.5 + cos(radianes) * distancia
	var perpendicular := (camara_z - z) * cos(radianes) + (camara_y - y) * sin(radianes)
	return tan(deg_to_rad(_fov_sin_efectos() * 0.5)) * maxf(perpendicular, 0.1) * _aspecto()


## La X de la camara tal como se ve: ya suavizada y sin sacudida.
func x_actual() -> float:
	return _x_actual


## Tiembla la vista, decayendo linealmente hasta cero en duracion segundos. Una
## sacudida mas debil que la que esta corriendo no la pisa.
func sacudir(amplitud: float = 0.12, duracion: float = 0.2) -> void:
	if Presentacion.activa():
		_iniciar_sacudida(amplitud, duracion)


## Suma delta_fov al fov (negativo acerca) y lo devuelve linealmente en
## duracion segundos. Un punch mas debil que el que esta corriendo no lo pisa.
func punch(delta_fov: float = -2.5, duracion: float = 0.18) -> void:
	if Presentacion.activa():
		_iniciar_punch(delta_fov, duracion)


# --- Internos -----------------------------------------------------------------

## Corre la X objetivo hacia el borde contra el que empuja un jugador.
##
## Con dos jugadores la zona muerta sola no alcanza: si uno se queda atras, el
## punto medio deja de avanzar cuando el de adelante toca el borde, y la camara
## se queda quieta aunque al de atras todavia le sobre pantalla. El tope es
## justo ese resto: la vista se corre hasta dejar al de atras en su propio
## borde, nunca mas, para que nadie salga de cuadro (tampoco un healer caido).
## Si empujan los dos para lados opuestos, no hay para donde ir.
func _empujar(x: float, derecha: bool, izquierda: bool, minimo: float,
		maximo: float, mitad: float, delta: float) -> float:
	if derecha == izquierda:
		return x
	var paso := empuje_borde * delta
	var hueco := maxf(mitad - margen_jugador, 0.0)
	# Si ya estaba pasada del tope, el empuje no la trae de vuelta: solo empuja.
	if derecha:
		return maxf(x, minf(x + paso, minimo + hueco))
	return minf(x, maxf(x - paso, maximo - hueco))


## Lleva una X de camara adentro del campo y del sector. Si lo que queda es mas
## angosto que la pantalla, ninguna X deja de mostrar algo de afuera: se centra.
func _recortar(x: float, mitad: float) -> float:
	var derecha := minf(_x_max, _limite_x)
	var desde := _x_min + mitad
	var hasta := derecha - mitad
	if desde > hasta:
		return (_x_min + derecha) * 0.5
	return clampf(x, desde, hasta)


func _rango(mitad: float) -> Vector2:
	var hueco := maxf(mitad - margen_jugador, 0.0)
	return Vector2(_x_actual - hueco, _x_actual + hueco)


## La velocidad en X de un seguido, si la tiene (un CharacterBody3D o cualquiera
## con una propiedad velocity). Sin velocidad no empuja.
func _velocidad_x(nodo: Node3D) -> float:
	var velocidad: Variant = nodo.get(&"velocity")
	if velocidad is Vector3:
		return (velocidad as Vector3).x
	return 0.0


## Ancho sobre alto de lo que se ve. En headless la ventana mide 100x100 y el
## estirado del proyecto la informa como 1280x1280: un 1:1 que ningun jugador
## ve, y con el que las pruebas medirian otra pantalla que la del juego. Ahi, o
## si el viewport no mide nada, vale la resolucion base del proyecto.
func _aspecto() -> float:
	if DisplayServer.get_name() != "headless" and is_inside_tree():
		var tamanio := get_viewport().get_visible_rect().size
		if tamanio.x > 0.0 and tamanio.y > 0.0:
			return tamanio.x / tamanio.y
	var ancho := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	var alto := float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	return ancho / alto if alto > 0.0 else 16.0 / 9.0


## Pone la camara donde la deja la matematica de siempre: sobre el eje de
## vision, a distancia del punto que mira. Mas la sacudida, si hay.
func _colocar() -> void:
	var radianes := deg_to_rad(angulo)
	var objetivo := Vector3(_x_actual, altura_objetivo, _profundidad * 0.5)
	var posicion := objetivo + Vector3(
		0.0,
		sin(radianes) * distancia,
		cos(radianes) * distancia)
	posicion += _desplazamiento_sacudida()
	if is_inside_tree():
		global_position = posicion
	else:
		position = posicion


## Separados de sacudir() y punch() para que las pruebas los ejerciten en
## headless, donde Presentacion los corta. El juego llama a los publicos.
func _iniciar_sacudida(amplitud: float, duracion: float) -> void:
	if amplitud <= 0.0 or duracion <= 0.0 or amplitud < _amplitud_sacudida():
		return
	_sacudida_amplitud = amplitud
	_sacudida_duracion = duracion
	_sacudida_restante = duracion


func _iniciar_punch(delta_fov: float, duracion: float) -> void:
	if is_zero_approx(delta_fov) or duracion <= 0.0:
		return
	if _punch_restante > 0.0:
		if absf(delta_fov) < absf(_delta_punch()):
			return
	else:
		# El base se toma al arrancar y nunca durante: tomado en medio de otro
		# punch se llevaria el efecto puesto, y el fov no volveria.
		_fov_base = fov
	_punch_delta = delta_fov
	_punch_duracion = duracion
	_punch_restante = duracion
	fov = _fov_base + _punch_delta


func _avanzar_efectos(delta: float) -> void:
	if _sacudida_restante > 0.0:
		_sacudida_restante = maxf(_sacudida_restante - delta, 0.0)
		_sacudida_reloj += delta
	if _punch_restante > 0.0:
		_punch_restante = maxf(_punch_restante - delta, 0.0)
		fov = _fov_base + _delta_punch()


## Corta los efectos en seco y deja el fov en el base. Para configurar() y
## saltar_a(): un corte de encuentro no arrastra el temblor del anterior.
func _cortar_efectos() -> void:
	if _punch_restante > 0.0:
		fov = _fov_base
	_punch_restante = 0.0
	_sacudida_restante = 0.0


func _amplitud_sacudida() -> float:
	if _sacudida_restante <= 0.0:
		return 0.0
	return _sacudida_amplitud * _sacudida_restante / _sacudida_duracion


func _delta_punch() -> float:
	if _punch_restante <= 0.0:
		return 0.0
	return _punch_delta * _punch_restante / _punch_duracion


func _desplazamiento_sacudida() -> Vector3:
	var amplitud := _amplitud_sacudida()
	if amplitud <= 0.0:
		return Vector3.ZERO
	return Vector3(
		sin(_sacudida_reloj * FRECUENCIA_SACUDIDA.x) * amplitud,
		sin(_sacudida_reloj * FRECUENCIA_SACUDIDA.y + 1.7) * amplitud,
		0.0)


func _fov_sin_efectos() -> float:
	return _fov_base if _punch_restante > 0.0 else fov
