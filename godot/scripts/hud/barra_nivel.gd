class_name BarraNivel
extends Control
## La barra del nivel, arriba al centro: de la base aliada a la enemiga, con
## lo que ya se libero, donde esta el choque y donde anda cada healer.
##
## Reemplaza al indicador del frente. El tira y afloja sigue ahi (el rombo, y
## el tramo azul hasta el) porque es la lectura mas rapida de si se gana o se
## pierde terreno; lo nuevo es el nivel partido en sectores: una marca donde
## termina cada uno y el tramo liberado mas claro. Sin sectores se comporta
## como el indicador de siempre.
##
## Todo lo que sabe del nivel lo pregunta por nombre (has_method, "x" in):
## la batalla con sectores es de otro paquete, y esto tiene que andar con la
## de hoy. Se dibuja a mano, con rectangulos llenos y coordenadas enteras,
## para que quede en pixeles duros como el resto del HUD.

const COLOR_ALIADO := Color("4a7fd4")
const COLOR_ENEMIGO := Color("c4553f")
const COLOR_PISTA := Color(0, 0, 0, 0.55)
const COLOR_BORDE := Color(0, 0, 0, 0.85)
## Cuanto terreno es nuestro ahora: hasta el frente.
const COLOR_TERRENO := Color(0.29, 0.5, 0.83, 0.75)
## Lo que ya se libero, mas claro que todo lo demas.
const COLOR_LIBERADO := Color(0.86, 0.92, 1.0, 0.95)
const COLOR_MARCA := Color(1, 1, 1, 0.55)
const COLOR_MARCA_LIBERADA := Color(1, 1, 1, 1)
## Velocidad del frente (m/s) a la que el rombo ya es del todo azul o rojo.
const EMPUJE_PLENO := 0.35
## Constante de tiempo con que se suaviza esa velocidad: el frente salta
## cuando cae alguien de la punta, y el color no puede parpadear con eso.
const SUAVIZADO_EMPUJE := 0.6
const ALTO_PISTA := 6
const MEDIO_ROMBO := 6
## Lo que no se usa de cada punta: ahi van las banderas de las bases.
const MARGEN := 12

var _battle: Node
## El encuentro en curso: si trae la lista de sectores, de ahi salen las
## marcas.
var _encuentro: Object
## Los sectores que la batalla fue anunciando, por indice: el ultimo recurso
## para saber donde termina cada uno.
var _vistos: Dictionary[int, Object] = {}
var _frente_previo: float = NAN
## Velocidad suavizada del frente, en m/s: positiva si empujamos nosotros.
var _empuje: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func seguir(battle: Node) -> void:
	_battle = battle
	_frente_previo = NAN
	_empuje = 0.0
	if battle.has_signal(&"encuentro_iniciado"):
		battle.connect(&"encuentro_iniciado", _on_encuentro_iniciado)
	if battle.has_signal(&"sector_iniciado"):
		battle.connect(&"sector_iniciado", _on_sector_iniciado)


func _process(delta: float) -> void:
	if _battle == null or not is_instance_valid(_battle):
		return
	var frente := _frente()
	if not is_nan(_frente_previo) and delta > 0.0:
		var velocidad := (frente - _frente_previo) / delta
		_empuje = lerpf(_empuje, velocidad, 1.0 - exp(-delta / SUAVIZADO_EMPUJE))
	_frente_previo = frente
	queue_redraw()


# --- Lo que leen las pruebas y el HUD -----------------------------------------

## Cuanto del nivel ya se libero, 0 a 1. Es progreso_nivel() de la batalla;
## una batalla sin sectores no libera nada.
func progreso() -> float:
	if _battle == null or not _battle.has_method(&"progreso_nivel"):
		return 0.0
	return clampf(float(_battle.call(&"progreso_nivel")), 0.0, 1.0)


func cantidad_marcas() -> int:
	if _battle == null or not _battle.has_method(&"cantidad_sectores"):
		return 0
	return maxi(int(_battle.call(&"cantidad_sectores")), 0)


## Donde cae cada marca, como fraccion de la barra (0 la base aliada, 1 la
## enemiga): el x_fin de cada sector si se lo encuentra, y si no, sectores
## iguales.
func fracciones_marcas() -> PackedFloat32Array:
	var fracciones := PackedFloat32Array()
	var total := cantidad_marcas()
	for i in total:
		var x_fin := _x_fin(i)
		fracciones.append(_fraccion(x_fin) if not is_nan(x_fin) else float(i + 1) / total)
	return fracciones


## Donde esta el choque, 0 a 1.
func fraccion_frente() -> float:
	return _fraccion(_frente())


## El color del rombo: azul si empujamos, rojo si nos empujan, blanco si la
## linea esta quieta.
func color_frente() -> Color:
	var t := clampf(_empuje / EMPUJE_PLENO, -1.0, 1.0)
	if t >= 0.0:
		return Color.WHITE.lerp(COLOR_ALIADO.lightened(0.15), t)
	return Color.WHITE.lerp(COLOR_ENEMIGO.lightened(0.1), -t)


## Cada healer en juego: {jugador, fraccion}.
func marcadores_healers() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	if not is_inside_tree():
		return lista
	for nodo in get_tree().get_nodes_in_group(&"healer"):
		var healer := nodo as Node3D
		if healer == null or not healer.is_inside_tree():
			continue
		var jugador: Variant = healer.get(&"jugador")
		lista.append({
			"jugador": int(jugador) if jugador != null else 1,
			"fraccion": _fraccion(healer.global_position.x),
		})
	return lista


# --- Dibujo -------------------------------------------------------------------

func _draw() -> void:
	if _battle == null or not is_instance_valid(_battle):
		return
	var x0 := float(MARGEN)
	var x1 := size.x - MARGEN
	var ancho := x1 - x0
	var medio := roundf(size.y * 0.5) + 2.0
	var pista := Rect2(x0, medio - ALTO_PISTA / 2.0, ancho, ALTO_PISTA)

	_bandera(Vector2(x0 - 8.0, medio), COLOR_ALIADO, 1.0)
	_bandera(Vector2(x1 + 8.0, medio), COLOR_ENEMIGO, -1.0)

	draw_rect(pista.grow(1.0), COLOR_BORDE)
	draw_rect(pista, COLOR_PISTA)
	var x_frente := roundf(lerpf(x0, x1, fraccion_frente()))
	draw_rect(Rect2(pista.position, Vector2(x_frente - x0, ALTO_PISTA)), COLOR_TERRENO)
	var x_liberado := roundf(lerpf(x0, x1, progreso()))
	if x_liberado > x0:
		draw_rect(Rect2(pista.position, Vector2(x_liberado - x0, ALTO_PISTA)), COLOR_LIBERADO)

	for fraccion in fracciones_marcas():
		var x := roundf(lerpf(x0, x1, fraccion))
		var color := COLOR_MARCA_LIBERADA if x <= x_liberado + 0.5 else COLOR_MARCA
		draw_rect(Rect2(x - 2.0, medio - 7.0, 4.0, 14.0), COLOR_BORDE)
		draw_rect(Rect2(x - 1.0, medio - 6.0, 2.0, 12.0), color)

	for marcador in marcadores_healers():
		var x := roundf(lerpf(x0, x1, marcador["fraccion"]))
		_flechita(Vector2(x, medio - ALTO_PISTA / 2.0 - 3.0),
			OverlayUnidades.color_jugador(marcador["jugador"]))

	_rombo(Vector2(x_frente, medio), color_frente())


## Un rombo de pixeles: filas de rectangulos que crecen y se achican. Con un
## poligono los bordes saldrian suavizados o dentados segun donde caiga.
func _rombo(centro: Vector2, color: Color) -> void:
	for fila in range(-MEDIO_ROMBO - 1, MEDIO_ROMBO + 2):
		var medio_ancho := MEDIO_ROMBO + 1 - absi(fila)
		draw_rect(Rect2(centro.x - medio_ancho, centro.y + fila, medio_ancho * 2 + 1, 1), COLOR_BORDE)
	for fila in range(-MEDIO_ROMBO, MEDIO_ROMBO + 1):
		var medio_ancho := MEDIO_ROMBO - absi(fila)
		draw_rect(Rect2(centro.x - medio_ancho, centro.y + fila, medio_ancho * 2 + 1, 1), color)


## Un triangulo que apunta hacia abajo, con la punta en `punta`.
func _flechita(punta: Vector2, color: Color) -> void:
	for fila in 5:
		var medio_ancho := fila + 1
		draw_rect(Rect2(punta.x - medio_ancho, punta.y - fila - 1, medio_ancho * 2 + 1, 1), COLOR_BORDE)
	for fila in 4:
		var medio_ancho := fila
		draw_rect(Rect2(punta.x - medio_ancho, punta.y - fila - 1, medio_ancho * 2 + 1, 1), color)


## El mastil y el banderin de una base. Sentido 1 flamea a la derecha.
func _bandera(pie: Vector2, color: Color, sentido: float) -> void:
	draw_rect(Rect2(pie.x - 1.0, pie.y - 12.0, 3.0, 16.0), COLOR_BORDE)
	draw_rect(Rect2(pie.x, pie.y - 11.0, 1.0, 14.0), Color(0.85, 0.8, 0.7))
	var tela := Rect2(pie.x + (1.0 if sentido > 0.0 else -7.0), pie.y - 11.0, 7.0, 5.0)
	draw_rect(tela.grow(1.0), COLOR_BORDE)
	draw_rect(tela, color)


# --- Nivel --------------------------------------------------------------------

func _frente() -> float:
	if _battle.has_method(&"frente_x"):
		return float(_battle.call(&"frente_x"))
	return lerpf(_base_aliada(), _base_enemiga(), 0.5)


func _base_aliada() -> float:
	var x: Variant = _battle.get(&"base_aliada_x")
	return float(x) if x != null else 0.0


func _base_enemiga() -> float:
	var x: Variant = _battle.get(&"base_enemiga_x")
	return float(x) if x != null else 1.0


func _fraccion(x: float) -> float:
	var a := _base_aliada()
	var e := _base_enemiga()
	return clampf((x - a) / maxf(e - a, 0.001), 0.0, 1.0)


## Donde termina el sector i, o NAN si no hay forma de saberlo. Se busca en
## la batalla, en el encuentro y en lo que se fue anunciando, en ese orden.
func _x_fin(i: int) -> float:
	var sector := _sector(i)
	if sector == null:
		return NAN
	var x: Variant = sector.get(&"x_fin")
	return float(x) if x != null else NAN


func _sector(i: int) -> Object:
	if _battle.has_method(&"sector_en"):
		var directo: Variant = _battle.call(&"sector_en", i)
		if directo is Object:
			return directo
	var lista: Variant = null
	if _battle.has_method(&"sectores"):
		lista = _battle.call(&"sectores")
	elif &"sectores" in _battle:
		lista = _battle.get(&"sectores")
	elif _encuentro != null and &"sectores" in _encuentro:
		lista = _encuentro.get(&"sectores")
	if lista is Array and i < (lista as Array).size() and (lista as Array)[i] is Object:
		return (lista as Array)[i]
	return _vistos.get(i)


func _on_encuentro_iniciado(encuentro: Object, _semilla: int, _indice: int) -> void:
	_encuentro = encuentro
	_vistos.clear()
	_frente_previo = NAN
	_empuje = 0.0


func _on_sector_iniciado(indice: int, sector: Variant) -> void:
	if sector is Object:
		_vistos[indice] = sector
