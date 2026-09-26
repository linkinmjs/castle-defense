class_name Mundo
extends Node3D
## El escenario de la batalla: cielo, siluetas lejanas, suelo, camino, la
## muralla aliada y el porton enemigo con su muralla.
##
## gen_scenes3d.gd arma los nodos con sus texturas y materiales y los deja
## acomodados para el campo de 30 x 10 de la escena. Lo que depende del campo
## de cada encuentro se acomoda aca: la batalla no sabe nada del suelo ni de
## las bases, le pasa las medidas a configurar() y el mundo se estira, se
## centra y planta las murallas. configurar() no crea ni borra nodos, solo
## mueve y redimensiona los que ya estan: se puede llamar en cada encuentro, o
## dos veces en el mismo, sin que nada se duplique.
##
## Las capas del fondo son quads paralelos al plano de la camara (rotados -15
## grados en X, como ella): la proyeccion queda como una escala pareja, cada
## texel mide lo mismo en todo el quad y las torres no se tuercen hacia los
## bordes de la pantalla. El porton y las murallas van igual, por lo mismo.
## Ver assets/fondos/LEEME.md.

## Las capas del fondo, de la mas lejana a la mas cercana, como las colgo el
## autor de assets/fondos para el campo de 10 m de profundidad.
## - z: respecto del medio del campo, que es donde mira la camara. Asi cada
##   capa queda siempre a la misma distancia de ella y un texel mide 2 px a
##   720p (3 a 1080p) con cualquier profundidad: en z fija, con un campo de 6 m
##   la camara se acercaba 2 m y los texeles pasaban a medir 2.17 px, que al
##   avanzar se ven de 2 y de 3 y titilan.
## - base: altura del borde de abajo. Negativa hunde el pie macizo de la capa
##   bajo el suelo y tapa los claros de la de adelante.
## - repeticion: cuanto mide una vuelta de la textura, en m. Es la que da 2 px
##   por texel a esa distancia; el alto sale de la misma cuenta. El cielo es
##   liso en X y se estira a lo ancho.
## - ancla: donde cae la columna del medio de la textura, respecto del medio
##   del campo. Las capas "del_torreon" no la usan: van atadas a la base
##   enemiga.
## - una_vuelta: el quad mide una sola repeticion, centrada en el ancla. Es el
##   castillo: repetido cada 70 m, en un campo de 90 m se veia dos veces (al
##   arrancar y al llegar), y el castillo enemigo es uno solo.
## - filas: solo esas filas de abajo de la textura. Es la loma del castillo,
##   que corre de punta a punta y tapa los claros entre los arboles: sin el
##   resto del castillo repetido, sigue haciendolo en los 240 m. Va 1 cm
##   detras del castillo, que la tapa donde estan los dos.
const CAPAS := {
	&"Cielo": {"textura": "cielo", "z": -65.0, "base": -1.5, "alto": 15.0, "repeticion": 240.0, "ancla": 0.0},
	&"Montanas": {"textura": "montanas", "z": -35.0, "base": -2.5, "alto": 24.96, "repeticion": 99.86, "ancla": -5.0},
	&"Loma": {"textura": "castillo", "z": -21.01, "base": -1.5, "alto": 2.04375, "repeticion": 69.76,
		"del_torreon": true, "filas": 30},
	&"Castillo": {"textura": "castillo", "z": -21.0, "base": -1.5, "alto": 17.44, "repeticion": 69.76,
		"del_torreon": true, "una_vuelta": true},
	&"Arboles": {"textura": "arboles", "z": -13.0, "base": -0.5, "alto": 9.81, "repeticion": 52.32, "ancla": 0.0},
}
## Ancho de cada quad del fondo. Con el campo mas ancho que viene (90 m) la
## camara barre, en la capa del cielo, de x = -44 a x = 134: centrado en el
## medio del campo, 240 m cubren eso con margen para pantallas mas anchas.
const ANCHO_CAPA := 240.0
## Texeles por metro de todo lo que esta a la escala de los sprites (68
## texeles en 2 m): suelo, camino, muralla y porton.
const TEXELES_POR_METRO := 34.0
## El torreon del castillo lejano cae del lado enemigo, esto antes de la base.
## En el campo de 30 m queda en x = 22, donde lo puso el autor de los fondos.
const TORREON_ANTES_DE_LA_BASE := 6.5
## Cuanto sobra el suelo a los costados del campo. La camara, en su tope, ve
## hasta ~15 m mas alla del borde en el fondo del campo.
const SUELO_COSTADOS := 20.0
## Donde termina el suelo hacia atras, respecto del medio del campo: pasa por
## debajo del pie de los arboles (13 m atras). Asi el pasto se mete bajo la
## capa a 24 m de la camara o mas, donde la niebla ya lo llevo al color del
## monte, y no queda raya. Cortado antes, entre el borde del suelo y los
## arboles se veia el pie hundido de la capa.
const SUELO_ATRAS := -15.0
## Cuanto sigue el suelo hacia adelante del campo. El borde de abajo de la
## pantalla pisa el suelo menos de 1 m adelante del campo: esto llega hasta
## debajo de la camara.
const SUELO_ADELANTE := 6.0
## Altura del camino sobre el suelo: lo justo para que no se peleen en el
## z-buffer.
const ALTURA_CAMINO := 0.005
## Linea de las murallas: apenas detras del borde de atras del campo, para que
## ningun soldado quede adentro del muro. Mas adelante el porton ya no entra en
## la pantalla: parado en el fondo del campo, la punta de sus torres queda
## justo bajo el borde de arriba.
const Z_MURALLAS := -0.3
## Las murallas van un poco detras del porton: el pie de la torrecita tapa el
## arranque del muro sin que los dos quads se peleen en el z-buffer.
const Z_MUROS_DETRAS := 0.05
## Cuanto se mete el arranque de la muralla enemiga debajo de la torrecita del
## porton, para que no quede una rendija entre los dos.
const SOLAPE_MURO := 0.2
## El porton va pasando el borde jugable enemigo: los healers llegan hasta la
## base enemiga y el porton arranca 10 cm despues.
const PORTON_TRAS_LA_BASE := 2.0
## La muralla aliada, del otro lado: un tramo centrado aca, y de ahi hasta el
## final del suelo.
const MURO_TRAS_LA_BASE := 2.5
## En muro.png la ultima almena termina en la columna 90 de 96: la muralla
## aliada termina ahi, al ras de una almena, y no en el hueco entre dos.
const MURO_COLUMNA_ULTIMA_ALMENA := 90.0

## Las medidas con las que esta acomodado ahora. Se guardan en la escena: el
## generador la deja armada para su campo, y valen hasta el primer
## configurar().
@export_storage var _ancho: float = 30.0
@export_storage var _profundidad: float = 10.0
@export_storage var _base_aliada_x: float = 1.5
@export_storage var _base_enemiga_x: float = 28.5

## Si alguien lo acomodo desde que se instancio. Lo que trae la escena no
## cuenta: es el campo de fabrica, no el del encuentro.
var _configurado := false


## Acomoda todo para un campo de ancho x profundidad con las bases en esas X.
## Se puede llamar cuantas veces haga falta: pisa lo que dejo la anterior.
func configurar(ancho: float, profundidad: float, base_aliada_x: float, base_enemiga_x: float) -> void:
	_ancho = ancho
	_profundidad = profundidad
	_base_aliada_x = base_aliada_x
	_base_enemiga_x = base_enemiga_x
	for nombre: StringName in CAPAS:
		_colgar_capa(nombre)
	_estirar_suelo()
	_tender_camino()
	_levantar_murallas()
	_configurado = true


func esta_configurado() -> bool:
	return _configurado


## Entre que X se juega: desde un metro antes de la base aliada hasta medio
## metro pasando la enemiga. Afuera estan las murallas.
func limite_x_jugable() -> Vector2:
	return Vector2(_base_aliada_x - 1.0, _base_enemiga_x + 0.5)


# --- Internos -----------------------------------------------------------------

func _medio_x() -> float:
	return _ancho * 0.5


func _medio_z() -> float:
	return _profundidad * 0.5


## Cuelga la capa a su distancia de la camara, centrada en el medio del campo
## (o en su ancla, si es de una sola vuelta), y corre la textura para que su
## columna del medio caiga en el ancla. La textura queda fija en el mundo:
## mover el quad no la mueve.
func _colgar_capa(nombre: StringName) -> void:
	var capa := get_node(NodePath(nombre)) as MeshInstance3D
	var datos: Dictionary = CAPAS[nombre]
	var ancla := _medio_x() + float(datos.get("ancla", 0.0))
	if datos.get("del_torreon", false):
		ancla = _base_enemiga_x - TORREON_ANTES_DE_LA_BASE
	var x := ancla if datos.get("una_vuelta", false) else _medio_x()
	capa.position = Vector3(x, float(datos["base"]), _medio_z() + float(datos["z"]))
	var borde := x - (capa.mesh as QuadMesh).size.x * 0.5
	var material := capa.material_override as StandardMaterial3D
	material.uv1_offset.x = fposmod(0.5 - (ancla - borde) / float(datos["repeticion"]), 1.0)


func _estirar_suelo() -> void:
	var suelo := $Suelo as MeshInstance3D
	var plano := suelo.mesh as PlaneMesh
	var atras := _medio_z() + SUELO_ATRAS
	var adelante := _profundidad + SUELO_ADELANTE
	plano.size = Vector2(_ancho + 2.0 * SUELO_COSTADOS, adelante - atras)
	suelo.position = Vector3(_medio_x(), 0.0, (atras + adelante) * 0.5)
	# A la escala de los sprites: una vuelta de la textura cada 128/34 m.
	var textura := _textura(suelo)
	(suelo.material_override as StandardMaterial3D).uv1_scale = Vector3(
		plano.size.x * TEXELES_POR_METRO / textura.get_width(),
		plano.size.y * TEXELES_POR_METRO / textura.get_height(), 1.0)


## Una franja de tierra a lo largo del campo, por la mitad de la profundidad:
## por ahi marchan las lineas.
func _tender_camino() -> void:
	var camino := $Camino as MeshInstance3D
	var plano := camino.mesh as PlaneMesh
	var textura := _textura(camino)
	plano.size = Vector2(_ancho + 2.0 * SUELO_COSTADOS, textura.get_height() / TEXELES_POR_METRO)
	camino.position = Vector3(_medio_x(), ALTURA_CAMINO, _medio_z())
	(camino.material_override as StandardMaterial3D).uv1_scale = Vector3(
		plano.size.x * TEXELES_POR_METRO / textura.get_width(), 1.0, 1.0)


## El porton enemigo pasando su base, con la muralla que sigue desde su
## torrecita derecha hasta el final del suelo; y del lado aliado otra muralla
## que viene desde el final del suelo y termina pasando la base aliada.
func _levantar_murallas() -> void:
	var porton := $Porton as MeshInstance3D
	var porton_x := _base_enemiga_x + PORTON_TRAS_LA_BASE
	porton.position = Vector3(porton_x, 0.0, Z_MURALLAS)

	var enemigo := $MuroEnemigo as MeshInstance3D
	var desde := porton_x + (porton.mesh as QuadMesh).size.x * 0.5 - SOLAPE_MURO
	_tender_muro(enemigo, desde, _ancho + SUELO_COSTADOS, desde)

	var aliado := $MuroAliado as MeshInstance3D
	var tramo := _textura(aliado).get_width() / TEXELES_POR_METRO
	var fin := _base_aliada_x - MURO_TRAS_LA_BASE + tramo * 0.5
	_tender_muro(aliado, -SUELO_COSTADOS, fin, fin - MURO_COLUMNA_ULTIMA_ALMENA / TEXELES_POR_METRO)


## Estira una muralla de desde a hasta en X, repitiendo muro.png, con el
## arranque de una vuelta de la textura (su columna 0) en ancla_x.
func _tender_muro(muro: MeshInstance3D, desde: float, hasta: float, ancla_x: float) -> void:
	var quad := muro.mesh as QuadMesh
	var tramo := _textura(muro).get_width() / TEXELES_POR_METRO
	quad.size.x = maxf(hasta - desde, 0.01)
	muro.position = Vector3((desde + hasta) * 0.5, 0.0, Z_MURALLAS - Z_MUROS_DETRAS)
	var material := muro.material_override as StandardMaterial3D
	material.uv1_scale = Vector3(quad.size.x / tramo, 1.0, 1.0)
	material.uv1_offset.x = fposmod(-(ancla_x - desde) / tramo, 1.0)


func _textura(nodo: MeshInstance3D) -> Texture2D:
	return (nodo.material_override as StandardMaterial3D).albedo_texture
