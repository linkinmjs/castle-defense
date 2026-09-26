class_name Apuntado
extends RefCounted
## Decide a quien le llega cada movimiento sin mouse: mira lo que el healer
## tiene enfrente.
##
## Con el cursor, en la linea amontonada el click caia en cualquiera y la
## punteria competia con la decision. Ahora la regla es de posicion y se puede
## aprender: la ligera toca a uno de la caja que el healer tiene adelante, la
## pesada a todos los de una caja mas grande. Un aliado pegado pero fuera de la
## caja no cuenta, y es a proposito: el juego premia pararse bien.
##
## Todo es estatico y recibe al healer como Node3D, por duck typing: tiparlo
## como Healer3D ataria el calculo a una escena, y lo usan tanto los
## movimientos como las pruebas y el HUD. Las cajas y las distancias viven en
## el plano del suelo (x del Rect2 = X del mundo, y del Rect2 = Z): el healer
## puede estar en el aire y el alcance no deberia cambiar por eso.

## Largo de la caja de la ligera, hacia donde mira el healer.
const ALCANCE_FRONTAL := 2.4
## Mitad del ancho de la caja de la ligera, en profundidad.
const ALCANCE_LATERAL := 1.3
## Cuanto se mete la caja por detras del healer. Sin este margen, el soldado
## que el healer tiene practicamente encima quedaria afuera por estar medio
## paso atras.
const MARGEN_TRASERO := 0.5
## Caja de la pesada: largo y mitad del ancho.
const ALCANCE_PESADA := Vector2(3.2, 2.0)


## -1 si el healer mira hacia -X (la base propia), +1 si mira hacia el frente.
static func direccion_frente(healer: Node3D) -> float:
	if healer.has_method(&"mirando_izquierda") and healer.call(&"mirando_izquierda"):
		return -1.0
	return 1.0


## Caja desde `atras` metros detras del healer hasta `largo` metros adelante,
## y `semiancho` para cada lado en profundidad. Siempre con tamano positivo,
## mire para donde mire.
static func caja_frontal(healer: Node3D, largo: float = ALCANCE_FRONTAL,
		semiancho: float = ALCANCE_LATERAL, atras: float = MARGEN_TRASERO) -> Rect2:
	var direccion := direccion_frente(healer)
	var pie := _plano(healer)
	var desde := pie.x - atras * direccion
	var hasta := pie.x + largo * direccion
	return Rect2(minf(desde, hasta), pie.y - semiancho, absf(hasta - desde), semiancho * 2.0)


## La caja de la ligera. Si el healer exporta sus propias medidas, mandan esas:
## asi se afinan desde el inspector sin tocar este archivo.
static func caja_ligera(healer: Node3D) -> Rect2:
	return caja_frontal(healer,
		_medida(healer, &"alcance_frontal", ALCANCE_FRONTAL),
		_medida(healer, &"alcance_lateral", ALCANCE_LATERAL),
		_medida(healer, &"margen_trasero", MARGEN_TRASERO))


## La caja de la pesada: mas larga y mas ancha que la de la ligera, con el
## mismo margen trasero.
static func caja_pesada(healer: Node3D) -> Rect2:
	var pesada := ALCANCE_PESADA
	var propia: Variant = healer.get(&"alcance_pesada")
	if propia is Vector2:
		pesada = propia
	return caja_frontal(healer, pesada.x, pesada.y,
		_medida(healer, &"margen_trasero", MARGEN_TRASERO))


## Aliados en pie o derribados cuyos pies caen dentro de la caja. Los
## derribados solo si se piden: para curar no sirven, para reanimar son lo
## unico que sirve.
static func aliados_en_caja(healer: Node3D, caja: Rect2,
		incluir_derribados: bool = false) -> Array[Unidad3D]:
	var lista: Array[Unidad3D] = []
	for nodo: Node in healer.get_tree().get_nodes_in_group(&"aliados"):
		var unidad := nodo as Unidad3D
		if not _en_juego(unidad):
			continue
		if unidad.esta_derribada() and not incluir_derribados:
			continue
		if caja.has_point(_plano(unidad)):
			lista.append(unidad)
	return lista


## El aliado que toca la ligera, o null si no hay nadie en la caja.
##
## Prioridad: el que sangra, despues el de menor fraccion de vida, despues el
## mas cercano. Es la lectura que el juego le pide al jugador (la causa antes
## que la vida), hecha regla para que el apuntado no tenga que adivinar.
##
## `preferido` es pegajoso: si sigue en la caja, en pie y con algo que curar,
## gana aunque otro este peor. Un combo sobre un paciente no puede saltar al
## vecino a mitad de camino porque al vecino le llego un golpe.
static func objetivo_ligera(healer: Node3D, preferido: Unidad3D = null) -> Unidad3D:
	var candidatos := aliados_en_caja(healer, caja_ligera(healer))
	if candidatos.is_empty():
		return null
	if preferido != null and candidatos.has(preferido) and preferido.vida < preferido.vida_maxima:
		return preferido

	var mejor: Unidad3D = candidatos[0]
	for unidad in candidatos:
		if _va_antes(healer, unidad, mejor):
			mejor = unidad
	return mejor


## Los que alcanza la pesada: todos los de la caja grande que esten en pie.
static func objetivos_pesada(healer: Node3D) -> Array[Unidad3D]:
	return aliados_en_caja(healer, caja_pesada(healer))


## El derribado mas cercano dentro de la caja pesada, o null.
static func derribado_al_frente(healer: Node3D) -> Unidad3D:
	var mejor: Unidad3D = null
	var mejor_distancia := INF
	for unidad in aliados_en_caja(healer, caja_pesada(healer), true):
		if not unidad.esta_derribada():
			continue
		var distancia := distancia_en_plano(healer, unidad)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = unidad
	return mejor


## Aliados en pie a `radio` metros del healer, en cualquier direccion.
static func aliados_alrededor(healer: Node3D, radio: float) -> Array[Unidad3D]:
	return _alrededor(healer, &"aliados", radio)


## Enemigos en pie a `radio` metros del healer.
static func enemigos_alrededor(healer: Node3D, radio: float) -> Array[Unidad3D]:
	return _alrededor(healer, &"enemigos", radio)


## Si la unidad sigue en la caja de la ligera y en pie. Lo usan los movimientos
## que continuan sobre el ultimo aliado que toco el combo.
static func esta_al_frente(healer: Node3D, unidad: Unidad3D) -> bool:
	if not _en_juego(unidad) or unidad.esta_derribada():
		return false
	return caja_ligera(healer).has_point(_plano(unidad))


## Distancia sobre el suelo, sin contar la altura: en pleno salto el healer
## sigue estando al lado de quien tiene al lado.
static func distancia_en_plano(desde: Node3D, hasta: Node3D) -> float:
	return _plano(desde).distance_to(_plano(hasta))


static func _alrededor(healer: Node3D, grupo: StringName, radio: float) -> Array[Unidad3D]:
	var lista: Array[Unidad3D] = []
	for nodo: Node in healer.get_tree().get_nodes_in_group(grupo):
		var unidad := nodo as Unidad3D
		if not _en_juego(unidad) or unidad.esta_derribada():
			continue
		if distancia_en_plano(healer, unidad) <= radio:
			lista.append(unidad)
	return lista


## True si `a` va antes que `b` para la ligera.
static func _va_antes(healer: Node3D, a: Unidad3D, b: Unidad3D) -> bool:
	var sangra_a := a.sangrado_restante > 0.0
	var sangra_b := b.sangrado_restante > 0.0
	if sangra_a != sangra_b:
		return sangra_a
	var fraccion_a := a.vida / a.vida_maxima
	var fraccion_b := b.vida / b.vida_maxima
	if not is_equal_approx(fraccion_a, fraccion_b):
		return fraccion_a < fraccion_b
	return distancia_en_plano(healer, a) < distancia_en_plano(healer, b)


## Viva (derribada tambien cuenta) y no a punto de desaparecer del arbol.
static func _en_juego(unidad: Unidad3D) -> bool:
	return unidad != null and is_instance_valid(unidad) \
		and not unidad.is_queued_for_deletion() and unidad.esta_viva()


static func _medida(healer: Node3D, propiedad: StringName, por_defecto: float) -> float:
	var propia: Variant = healer.get(propiedad)
	if propia is float or propia is int:
		return float(propia)
	return por_defecto


static func _plano(nodo: Node3D) -> Vector2:
	return Vector2(nodo.global_position.x, nodo.global_position.z)
