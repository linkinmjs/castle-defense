class_name NumeroFlotante
extends Label3D
## Un numero o una palabra que sale de algo en el campo, sube y se apaga: "+18"
## al curar, lo que se desperdicio, el dano que recibe el healer, el nombre de un
## estado ("VENDAJE").
##
## Label3D y no un Label del HUD proyectado a pantalla: vive en el mundo, asi
## que acompana a la camara solo, tiene el tamano justo a la distancia de
## siempre y nadie tiene que convertir posiciones cada frame.
##
## Se crea con mostrar(), que se encarga de todo: lo arma, lo cuelga, lo anima
## y lo libera al terminar. Sin pantalla (Presentacion) no crea nada, salvo con
## forzar, que es para las pruebas.
##
## Los colores son una convencion: el mismo color tiene que decir siempre lo
## mismo, o el jugador deja de leerlos.
## - curacion: COLOR_CURA
## - desperdicio (la cura que no entro): COLOR_DESPERDICIO
## - dano al healer: COLOR_DANO
## - texto de estado ("VENDAJE"): el color del movimiento (Movimiento.color)
##
## Usa la fuente del tema del proyecto (gui/theme/custom) y, si no hay, la de
## Godot. Un Label3D no ve el theme de los Control: para que los numeros usen la
## fuente pixel de la interfaz alcanza con asignarla en _armar (font) o con hacer
## de ese tema el del proyecto.

const COLOR_CURA := Color("#7ddc7d")
const COLOR_DESPERDICIO := Color("#9a9aa8")
const COLOR_DANO := Color("#e07a6a")

## Nunca mas que estos a la vez. Una plegaria sobre la linea en medio de una
## pelea larga puede pedir docenas: pasado el tope, otro numero tapa el campo en
## vez de informar. Al llegar, se va el mas viejo, que ya se leyo.
const MAXIMO_VIVOS := 40
## Pixeles de la fuente. Junto con METROS_POR_PIXEL da el alto en el mundo.
const TAMANO_FUENTE := 40
## 40 px de fuente por 0.012 m dan ~0.5 m de letra: un cuarto de un soldado,
## legible a la distancia de la camara sin tapar al que se curo.
const METROS_POR_PIXEL := 0.012
## Contorno negro grueso, en pixeles de la fuente: el numero se tiene que leer
## sobre el pasto, sobre un sprite o sobre una explosion.
const CONTORNO := 14
## Cuanto sube, en metros, y en cuantos segundos.
const SUBIDA := 0.8
const DURACION := 0.8
## Los ultimos segundos de DURACION, en los que se apaga.
const DESVANECIDO := 0.3

## Los que estan en pantalla, del mas viejo al mas nuevo.
static var _vivos: Array[NumeroFlotante] = []


## Muestra texto en pos (global) y lo deja subir y apagarse. pos es la base del
## texto: el numero queda entero por encima, asi que puesto justo arriba de la
## barra de vida no la tapa. tamano escala todo el numero: 1 es el de siempre,
## 1.5 para lo que tiene que destacar. Devuelve el numero, o null si no hay
## pantalla y no se pidio forzar.
static func mostrar(padre: Node, pos: Vector3, texto: String, color: Color,
		tamano: float = 1.0, forzar: bool = false) -> NumeroFlotante:
	if not is_instance_valid(padre) or not (forzar or Presentacion.activa()):
		return null
	_hacer_lugar()
	var numero := NumeroFlotante.new()
	numero._armar(texto, color, tamano)
	padre.add_child(numero)
	if numero.is_inside_tree():
		numero.global_position = pos
	else:
		numero.position = pos
	numero._animar()
	_vivos.append(numero)
	return numero


## Cuantos hay en pantalla ahora, sin contar los que ya estan por liberarse.
static func cantidad_vivos() -> int:
	_podar()
	return _vivos.size()


func _notification(que: int) -> void:
	# Se borra de la lista al liberarse por cualquier camino: al terminar, al
	# desalojarlo el tope o al irse la escena entera.
	if que == NOTIFICATION_PREDELETE:
		_vivos.erase(self)


func _armar(texto: String, color: Color, tamano: float) -> void:
	name = "Numero"
	text = texto
	modulate = color
	font_size = TAMANO_FUENTE
	pixel_size = METROS_POR_PIXEL * maxf(tamano, 0.05)
	outline_size = CONTORNO
	outline_modulate = Color.BLACK
	vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Encima de todo: un numero tapado por el soldado que se curo no sirve.
	no_depth_test = true
	# Y despues de lo demas transparente (particulas incluidas). El contorno va
	# antes que el texto, como en cualquier Label3D.
	render_priority = 10
	outline_render_priority = 9
	# Pixeles duros como los de los sprites, no un borron.
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _animar() -> void:
	var tween := create_tween()
	# Con la fisica y no con el frame: una prueba que cuenta ticks lo ve siempre
	# en el mismo lugar.
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_parallel(true)
	tween.tween_property(self, ^"position:y", SUBIDA, DURACION).as_relative() \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# El texto y el contorno por separado: en un Label3D el contorno no hereda
	# el alfa del texto, y quedaria un fantasma negro.
	var espera := DURACION - DESVANECIDO
	tween.tween_property(self, ^"modulate:a", 0.0, DESVANECIDO).set_delay(espera)
	tween.tween_property(self, ^"outline_modulate:a", 0.0, DESVANECIDO).set_delay(espera)
	tween.chain().tween_callback(queue_free)


## Si ya estan todos los que entran, libera a los mas viejos hasta dejar lugar
## para uno.
static func _hacer_lugar() -> void:
	_podar()
	while _vivos.size() >= MAXIMO_VIVOS:
		var viejo: NumeroFlotante = _vivos.pop_front()
		viejo.queue_free()


## Saca de la lista a los que ya no estan o estan por irse. Se lee cada entrada
## sin tipo: un numero ya liberado no se puede asignar a una variable tipada.
static func _podar() -> void:
	for i in range(_vivos.size() - 1, -1, -1):
		var numero: Variant = _vivos[i]
		if not is_instance_valid(numero) or (numero as Node).is_queued_for_deletion():
			_vivos.remove_at(i)
