extends SceneTree
## Genera los fondos del campo de batalla y deja lista la fuente pixel de la UI.
##
## Todo es procedural y con semillas fijas: dos corridas escriben los mismos
## bytes. El tileset del pack 141897 es de prototipo (cada tile lleva un "32"
## impreso y los BackTiles son formas planas con rotulos), asi que no se copia
## ningun pixel: de ahi salen el modulo de 32 px y las pendientes de 45 y 27
## grados (escalones 1:1 y 2:1) que usan las siluetas.
##
## Los PNG no se pueden cargar como recurso en la misma corrida, y ui.ttf.import
## recien existe despues de importar, asi que son dos vueltas:
##   godot --headless --path godot --script res://tools/gen_fondos.gd
##   godot --headless --path godot --import
##   godot --headless --path godot --script res://tools/gen_fondos.gd
##   godot --headless --path godot --import
## La segunda vuelta solo cambia ui.ttf.import si todavia no estaba ajustado.
## Las vistas previas quedan en user:// (fuera del repo).

const DIR := "res://assets/fondos"
const DIR_FUENTES := "res://assets/fonts"
const RUTA_FUENTE := "res://assets/fonts/ui.ttf"
const ZIP_FUENTE := "res://assets/_raw/craftpix-671189-10-magic-sprite-sheet-effects-pixel-art.zip"
const FUENTE_EN_ZIP := "Font/Planes_ValMore.ttf"

# --- Paletas ------------------------------------------------------------------

const CIELO_ARRIBA := Color("1b1a3a")
const CIELO_MEDIO := Color("4a3560")
const CIELO_HORIZONTE := Color("c9694a")
const CIELO_BAJO := Color("e8a05a")

const MONTANA := Color("4c3f6b")
const MONTANA_BRUMA := Color("5a4c7c")

const CASTILLO := Color("352a4f")
const VENTANA := Color("e8a05a")

const ARBOL := Color("1c1730")
const ARBOL_FONDO := Color("241d3d")

const PASTO := Color("3f5a3a")
const PASTO_OSCURO := Color("365033")
const PASTO_CLARO := Color("4a6a44")
const TIERRA := Color("6b5138")
const TIERRA_OSCURA := Color("5a432f")
const PIEDRA := Color("7d7a6e")

const PIEDRA_CLARA := Color("5a4c7c")
const PIEDRA_MEDIA := Color("3d3358")
const PIEDRA_OSCURA := Color("2a2340")
const MADERA := Color("6b4a2a")
const HERRAJE := Color("3a3a44")
## Juntas entre tablones y el hueco del arco: la madera en sombra.
const MADERA_OSCURA := Color("4a321f")

const TRANSPARENTE := Color(0, 0, 0, 0)

# --- Montaje ------------------------------------------------------------------

## Donde va cada capa: z del borde inferior del quad y a que altura queda ese
## borde. Los quads van rotados -15 grados en X, paralelos al plano de la
## camara: asi la proyeccion es una escala pareja, las torres no se inclinan
## en los bordes de la pantalla y cada texel mide lo mismo en todo el quad.
## Cada capa se hunde un poco bajo el suelo para que su pie macizo tape los
## claros de la capa de adelante.
const MONTAJE := {
	"arboles": {"z": -8.0, "base": -0.5},
	"castillo": {"z": -16.0, "base": -1.5},
	"montanas": {"z": -30.0, "base": -2.5},
	"cielo": {"z": -60.0, "base": -1.5, "alto": 15.0},
}
## Fraccion del cielo que ocupa el degradado. Debajo, el resplandor sigue
## macizo hasta el borde del quad, que baja mas que el valle mas hondo de la
## cordillera: si el cielo terminara justo en el horizonte, en los valles se
## veria el fondo del Environment (con niebla, una raya oscura).
const CIELO_DEGRADADO := 0.846
## Pixeles de pantalla por texel a 1280x720. Con el ancho del quad calculado
## para que den exactos, cada texel ocupa siempre 2 px aunque la camara se
## corra: no hay texeles de 1 o de 3 que titilen al avanzar.
const PX_POR_TEXEL := 2.0
const ALTO_PANTALLA := 720.0
## Texeles de suelo.png por metro: los mismos 34 que los sprites.
const SUELO_TEXELES_POR_METRO := 34.0
## Donde termina hacia atras el plano del suelo que arma gen_scenes3d.
const SUELO_Z_MIN := -10.0
## X del mundo donde cae el centro de cada textura (la columna 512). En el
## castillo es donde queda el torreon: del lado enemigo del campo.
const CENTRO_X := {"arboles": 15.0, "castillo": 22.0, "montanas": 10.0}
## Niebla por profundidad que se sugiere para la escena (fog_mode = DEPTH):
## no toca el campo, oscurece el pasto de atras hacia el tono del monte y
## borra la raya recta donde el suelo se mete bajo los arboles. Las capas
## llevan disable_fog, asi que solo la ve el suelo.
const NIEBLA := {"color": Color("1c1730"), "desde": 16.0, "hasta": 26.0, "densidad": 0.85}

## Copia de lo que arma battle3d.gd: la vista previa y las medidas salen de aca.
const CAMARA_DISTANCIA := 11.0
const CAMARA_ANGULO := 15.0
const CAMARA_ALTURA := 1.05
const CAMARA_FOV := 42.0
const CAMPO_PROFUNDIDAD := 10.0


func _initialize() -> void:
	var fallos := 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_FUENTES))

	print("--- fondos ---")
	var imagenes := {
		"cielo": _cielo(),
		"montanas": _montanas(),
		"castillo": _castillo(),
		"arboles": _arboles(),
		"suelo": _suelo(),
		"camino": _camino(),
		"muro": _muro(),
		"porton": _porton(),
	}
	for nombre: String in imagenes:
		if not _guardar(imagenes[nombre], "%s/%s.png" % [DIR, nombre]):
			fallos += 1

	print("--- montaje ---")
	for nombre: String in ["arboles", "castillo", "montanas"]:
		var m := _medidas(nombre, imagenes[nombre])
		print("  %-9s z=%6.1f base=%5.2f  quad %6.2f x %5.2f m  (%.2f texel/m, uv1_scale.x=%.3f en 240 m)" % [
			nombre, m["z"], m["base"], m["ancho"], m["alto"],
			(imagenes[nombre] as Image).get_width() / float(m["ancho"]), 240.0 / float(m["ancho"])])

	print("--- fuente ---")
	if not _extraer_fuente():
		fallos += 1
	_ajustar_import_fuente()

	print("--- LEEME ---")
	if not _escribir_leemes(imagenes):
		fallos += 1

	print("--- vistas previas (user://) ---")
	_vistas_previas(imagenes)

	print("")
	if fallos > 0:
		print("FALLARON %d archivos" % fallos)
	else:
		print("TODO OK (correr --import para que Godot tome los PNG y la fuente)")
	quit(1 if fallos > 0 else 0)


func _guardar(imagen: Image, ruta: String) -> bool:
	if imagen.save_png(ProjectSettings.globalize_path(ruta)) != OK:
		push_error("no se pudo guardar %s" % ruta)
		return false
	print("  %-14s %4dx%-4d %2d colores" % [
		ruta.get_file(), imagen.get_width(), imagen.get_height(), _contar_colores(imagen)])
	return true


# --- Camara y medidas -----------------------------------------------------------

static func _ojo(camara_x: float) -> Vector3:
	var ang := deg_to_rad(CAMARA_ANGULO)
	return Vector3(camara_x, CAMARA_ALTURA + sin(ang) * CAMARA_DISTANCIA,
			CAMPO_PROFUNDIDAD * 0.5 + cos(ang) * CAMARA_DISTANCIA)


## Distancia de la camara a la capa medida sobre el eje de vision. Con el quad
## paralelo al plano de la camara es la misma en todo el quad.
static func _profundidad(z: float, base: float) -> float:
	var ang := deg_to_rad(CAMARA_ANGULO)
	var ojo := _ojo(0.0)
	return sin(ang) * (ojo.y - base) + cos(ang) * (ojo.z - z)


static func _px_por_metro(profundidad: float) -> float:
	return ALTO_PANTALLA * 0.5 / (tan(deg_to_rad(CAMARA_FOV * 0.5)) * profundidad)


## Tamano del quad (una repeticion) para que un texel mida PX_POR_TEXEL.
static func _medidas(nombre: String, imagen: Image) -> Dictionary:
	var m: Dictionary = MONTAJE[nombre]
	var profundidad := _profundidad(m["z"], m["base"])
	var metros_por_texel := PX_POR_TEXEL / _px_por_metro(profundidad)
	return {
		"z": m["z"],
		"base": m["base"],
		"profundidad": profundidad,
		"ancho": imagen.get_width() * metros_por_texel,
		"alto": imagen.get_height() * metros_por_texel,
	}


# --- Utilidades ---------------------------------------------------------------

## Hash entero de 32 bits. El ruido lo usa en vez de randf() para depender
## solo de la celda: asi el valor en x y en x + periodo es el mismo.
static func _hash(a: int, b: int, semilla: int) -> int:
	var h := (a * 374761393 + b * 668265263 + semilla * 1442695041) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	return (h ^ (h >> 16)) & 0xffffffff


static func _azar(a: int, b: int, semilla: int) -> float:
	return float(_hash(a, b, semilla)) / 4294967296.0


## Ruido de valor en 1D que se repite exacto cada `periodo` columnas.
static func _ruido_1d(x: float, celdas: int, periodo: float, semilla: int) -> float:
	var t := x / periodo * celdas
	var i := floori(t)
	var f := t - i
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_azar(posmod(i, celdas), 0, semilla), _azar(posmod(i + 1, celdas), 0, semilla), f)


## Lo mismo en 2D: empalma en X y en Y sobre un cuadrado de `lado` pixeles.
static func _ruido_2d(x: float, y: float, celdas: int, lado: float, semilla: int) -> float:
	var tx := x / lado * celdas
	var ty := y / lado * celdas
	var ix := floori(tx)
	var iy := floori(ty)
	var fx := tx - ix
	var fy := ty - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var x0 := posmod(ix, celdas)
	var x1 := posmod(ix + 1, celdas)
	var y0 := posmod(iy, celdas)
	var y1 := posmod(iy + 1, celdas)
	var arriba := lerpf(_azar(x0, y0, semilla), _azar(x1, y0, semilla), fx)
	var abajo := lerpf(_azar(x0, y1, semilla), _azar(x1, y1, semilla), fx)
	return lerpf(arriba, abajo, fy)


static func _lienzo(ancho: int, alto: int) -> Image:
	var imagen := Image.create_empty(ancho, alto, false, Image.FORMAT_RGBA8)
	imagen.fill(TRANSPARENTE)
	return imagen


## Pinta envolviendo en X: lo que se sale por un costado entra por el otro.
## Es lo que hace que cada capa empalme consigo misma sin costura.
static func _px(imagen: Image, x: int, y: int, color: Color) -> void:
	if y < 0 or y >= imagen.get_height():
		return
	imagen.set_pixel(posmod(x, imagen.get_width()), y, color)


## Igual que _px pero envuelve tambien en Y, para las texturas de piso.
static func _px_toro(imagen: Image, x: int, y: int, color: Color) -> void:
	imagen.set_pixel(posmod(x, imagen.get_width()), posmod(y, imagen.get_height()), color)


static func _rect(imagen: Image, x: int, y: int, ancho: int, alto: int, color: Color) -> void:
	for yy in range(y, y + alto):
		for xx in range(x, x + ancho):
			_px(imagen, xx, yy, color)


## Rectangulo apoyado: `k` es la altura en texeles de su borde inferior,
## contada desde abajo de la imagen. Las capas se piensan asi, desde el pie.
static func _bloque(imagen: Image, x: int, k: int, ancho: int, alto: int, color: Color) -> void:
	_rect(imagen, x, imagen.get_height() - k - alto, ancho, alto, color)


## Columna llena desde el borde de abajo hasta `altura` texeles.
static func _columna(imagen: Image, x: int, altura: int, color: Color) -> void:
	var fondo := imagen.get_height() - 1
	for k in altura:
		_px(imagen, x, fondo - k, color)


static func _contar_colores(imagen: Image) -> int:
	var vistos := {}
	for y in imagen.get_height():
		for x in imagen.get_width():
			var c := imagen.get_pixel(x, y)
			if c.a > 0.0:
				vistos[c.to_html()] = true
	return vistos.size()


# --- Cielo --------------------------------------------------------------------

## Degradado en bandas planas: 23 franjas que se afinan hacia el horizonte,
## donde el color cambia mas rapido, y abajo la banda del resplandor. En
## pantalla, del resplandor se ve solo el filo que asoma en los valles.
## Sin nubes: en 16 px de ancho una nube que empalme seria una raya.
func _cielo() -> Image:
	var ancho := 16
	var alto := 512
	var imagen := _lienzo(ancho, alto)
	var bandas := 23
	var degradado := roundi(alto * CIELO_DEGRADADO)
	# La banda mas cercana a cada parada lleva el color exacto de la paleta,
	# no uno interpolado: asi 4a3560 y c9694a estan en el cielo tal cual.
	var exactas := {}
	for parada: Array in CIELO_PARADAS:
		var mejor := 0
		for banda in bandas:
			var centro := (_borde_banda(banda, bandas, degradado) + _borde_banda(banda + 1, bandas, degradado)) * 0.5 / degradado
			var centro_mejor := (_borde_banda(mejor, bandas, degradado) + _borde_banda(mejor + 1, bandas, degradado)) * 0.5 / degradado
			if absf(centro - float(parada[0])) < absf(centro_mejor - float(parada[0])):
				mejor = banda
		exactas[mejor] = parada[1]
	for banda in bandas:
		var desde := _borde_banda(banda, bandas, degradado)
		var hasta := _borde_banda(banda + 1, bandas, degradado)
		var color: Color = exactas.get(banda, _degradado_cielo((desde + hasta) * 0.5 / degradado))
		imagen.fill_rect(Rect2i(0, desde, ancho, hasta - desde), color)
	imagen.fill_rect(Rect2i(0, degradado, ancho, alto - degradado), CIELO_BAJO)
	return imagen


static func _borde_banda(banda: int, bandas: int, alto: int) -> int:
	return roundi(alto * (1.0 - pow(1.0 - float(banda) / bandas, 1.4)))


## Paradas del degradado, en fraccion de la parte degradada. El violeta sube
## hasta el tercio de arriba: los picos tienen que recortarse contra el
## naranja, porque contra 4a3560 la montana (4c3f6b) desaparece.
const CIELO_PARADAS := [
	[0.0, CIELO_ARRIBA],
	[0.3, CIELO_MEDIO],
	[0.84, CIELO_HORIZONTE],
]


static func _degradado_cielo(t: float) -> Color:
	var paradas := CIELO_PARADAS + [[1.0, CIELO_BAJO]]
	for i in paradas.size() - 1:
		var a: Array = paradas[i]
		var b: Array = paradas[i + 1]
		if t <= b[0]:
			var f := (t - float(a[0])) / (float(b[0]) - float(a[0]))
			return (a[1] as Color).lerp(b[1], f)
	return CIELO_BAJO


# --- Montanas -----------------------------------------------------------------

## Perfil de un pico suave: la punta redondeada y las faldas abiertas, que al
## rasterizar dan escalones 1:1 cerca de la cima y 2:1 o mas largos abajo (las
## pendientes de 45 y 27 grados del BackTileset, sin quiebres).
static func _loma(t: float) -> float:
	var u := 1.0 - absf(t)
	if u <= 0.0:
		return 0.0
	var punta := pow(u, 1.35)
	var redonda := u * u * (3.0 - 2.0 * u)
	return lerpf(punta, redonda, 0.6)


## Altura por columna de una fila de lomas [x, altura, medio ancho izquierdo,
## medio ancho derecho], con la distancia medida envolviendo: una loma cerca
## del borde sigue del otro lado. Dos medios anchos distintos dan laderas
## asimetricas, que es lo que separa una montana de una carpa.
static func _perfil(ancho: int, lomas: Array) -> PackedFloat32Array:
	var alturas := PackedFloat32Array()
	alturas.resize(ancho)
	for x in ancho:
		var h := 0.0
		for loma: Array in lomas:
			var d := fposmod(x - float(loma[0]) + ancho * 0.5, ancho) - ancho * 0.5
			var medio: float = loma[2] if d < 0.0 else loma[3]
			h = maxf(h, float(loma[1]) * _loma(d / medio))
		alturas[x] = h
	return alturas


## Redondea y saca los dientes o muescas de un pixel de ancho, que en pixel
## art se leen como ruido y no como forma.
static func _limpiar_perfil(alturas: PackedFloat32Array) -> PackedInt32Array:
	var n := alturas.size()
	var enteras := PackedInt32Array()
	enteras.resize(n)
	for x in n:
		enteras[x] = roundi(alturas[x])
	for pasada in 2:
		for x in n:
			var a := enteras[posmod(x - 1, n)]
			var b := enteras[x]
			var c := enteras[posmod(x + 1, n)]
			if (b > a and b > c) or (b < a and b < c):
				enteras[x] = a if absi(a - b) < absi(c - b) else c
	return enteras


func _montanas() -> Image:
	var ancho := 1024
	var imagen := _lienzo(ancho, 256)

	# Siete picos grandes que mandan, y cerros menores entre ellos para que
	# los valles no caigan todos hasta la bruma.
	var lomas := [
		[70, 74, 100, 125], [215, 82, 115, 95], [395, 68, 85, 105],
		[548, 79, 100, 125], [700, 70, 95, 85], [842, 81, 105, 115],
		[992, 62, 65, 75],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 16
	for i in 12:
		var medio := rng.randf_range(40.0, 70.0)
		lomas.append([rng.randf_range(0.0, ancho), rng.randf_range(48.0, 62.0),
				medio, medio * rng.randf_range(0.8, 1.3)])
	var picos := _perfil(ancho, lomas)
	var alturas := PackedFloat32Array()
	alturas.resize(ancho)
	for x in ancho:
		# Un lomo bajo que ondula y a ratos asoma sobre la bruma: une los
		# cerros sin volverse meseta. Las dos octavas de ruido dan hombros.
		var lomo := 36.0 + _ruido_1d(x, 12, ancho, 13) * 14.0
		var h := maxf(picos[x], lomo)
		h += (_ruido_1d(x, 24, ancho, 14) - 0.5) * 7.0
		h += (_ruido_1d(x, 64, ancho, 15) - 0.5) * 3.0
		alturas[x] = h
	var cordillera := _limpiar_perfil(alturas)

	# Faldeo de bruma: lomas bajas y anchas delante de la cordillera.
	var bajas := _perfil(ancho, [
		[0, 44, 150, 150], [150, 38, 130, 130], [290, 47, 160, 150],
		[450, 37, 120, 130], [560, 44, 150, 150], [700, 36, 120, 120],
		[850, 46, 160, 150],
	])
	for x in ancho:
		bajas[x] += (_ruido_1d(x, 32, ancho, 12) - 0.5) * 3.0
	var faldeo := _limpiar_perfil(bajas)

	# Siluetas planas, sin filo de luz: el sol esta detras, asi que de este
	# lado las laderas estan en sombra y el recorte limpio contra el
	# resplandor es lo que se tiene que leer.
	for x in ancho:
		_columna(imagen, x, maxi(cordillera[x], 1), MONTANA)
		_columna(imagen, x, maxi(faldeo[x], 1), MONTANA_BRUMA)
	return imagen


# --- Castillo -----------------------------------------------------------------

## El castillo ocupa el centro de la repeticion: un solo castillo en el
## horizonte, no una muralla infinita. A los costados queda solo la loma, que
## vive detras de los arboles y tapa sus claros.
## Torres: [centro, ancho, altura del cuerpo (k), remate].
const TORRES := [
	[356, 16, 68, "almenas"],
	[432, 12, 60, "cono"],
	[596, 12, 64, "cono"],
	[672, 16, 72, "almenas"],
]
const MURALLA_DESDE := 350
const MURALLA_HASTA := 678
const MURALLA_K := 46

## Ventanas de 2x3 (x, k del borde inferior): pocas y a distintas alturas,
## para que parezca que adentro hay alguien y no un patron.
const VENTANAS := [
	[352, 52], [358, 40],
	[430, 46],
	[498, 70], [506, 58], [520, 74], [526, 60], [514, 48],
	[540, 86],
	[594, 50],
	[668, 58], [676, 46],
	# Las de la muralla, bien arriba: mas abajo asoman entre los arboles y
	# parecen fogatas en el bosque.
	[392, 41], [640, 42],
]


func _castillo() -> Image:
	var ancho := 1024
	var imagen := _lienzo(ancho, 256)

	# Loma corrida de punta a punta: es la que empalma en el borde y la que
	# tapa los claros entre arboles. Queda casi toda detras del monte.
	for x in ancho:
		var h := 24 + roundi(_ruido_1d(x, 8, ancho, 71) * 6.0)
		_columna(imagen, x, h, CASTILLO)

	# Muralla con almenas de 3 y huecos de 2.
	_bloque(imagen, MURALLA_DESDE, 0, MURALLA_HASTA - MURALLA_DESDE, MURALLA_K, CASTILLO)
	var x := MURALLA_DESDE
	while x < MURALLA_HASTA:
		_bloque(imagen, x, MURALLA_K, mini(3, MURALLA_HASTA - x), 3, CASTILLO)
		x += 5

	for torre: Array in TORRES:
		_torre(imagen, torre[0], torre[1], torre[2], torre[3])

	# Torreon central y la torrecita que lo corona.
	_torre(imagen, 512, 48, 84, "almenas")
	_torre(imagen, 538, 10, 94, "cono")

	for v: Array in VENTANAS:
		_bloque(imagen, v[0], v[1], 2, 3, VENTANA)
	return imagen


## Torre de `ancho` texeles centrada en cx, con el cuerpo hasta `k`. Con
## almenas lleva un matacan (un escalon mas ancho) y merlones de 2; con cono,
## un techo de pendiente 2:1 y un banderin.
func _torre(imagen: Image, cx: int, ancho: int, k: int, remate: String) -> void:
	var x0 := cx - ancho / 2
	_bloque(imagen, x0, 0, ancho, k, CASTILLO)
	if remate == "cono":
		var medio := ancho / 2 + 1
		for i in medio + 1:
			_bloque(imagen, x0 - 1 + i, k + i * 2, ancho + 2 - i * 2, 2, CASTILLO)
		var punta := k + (medio + 1) * 2
		_bloque(imagen, cx, punta, 1, 5, CASTILLO)
		_bloque(imagen, cx + 1, punta + 4, 3, 1, CASTILLO)
		_bloque(imagen, cx + 1, punta + 3, 2, 1, CASTILLO)
	else:
		_bloque(imagen, x0 - 1, k, ancho + 2, 3, CASTILLO)
		var x := x0 - 1
		while x < x0 + ancho - 1:
			_bloque(imagen, x, k + 3, 2, 2, CASTILLO)
			x += 4
		# El ultimo merlon siempre en la esquina, para que la torre cierre pareja.
		_bloque(imagen, x0 + ancho - 1, k + 3, 2, 2, CASTILLO)


# --- Arboles ------------------------------------------------------------------

## Texeles desde abajo de arboles.png hasta la linea del suelo, con el quad
## hundido como dice MONTAJE (0.5 m a ~20 texeles por metro).
const ARBOLES_SUELO_K := 10


func _arboles() -> Image:
	var ancho := 1024
	var imagen := _lienzo(ancho, 192)
	var pie := imagen.get_height() - 1 - ARBOLES_SUELO_K

	# Fila de atras, mas alta y un tono mas clara: el aire la aleja. Un ruido
	# lento arma grupos altos y claros mas bajos, para que la linea respire.
	# La costura cae en el centro de una copa redonda, que es simetrica: las
	# columnas 1023 y 0 quedan a la misma altura aunque se toquen las semillas.
	_copa(imagen, 0, pie, 42, ARBOL_FONDO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var x := 10.0
	while x < ancho - 8:
		var grupo := _ruido_1d(x, 10, ancho, 81)
		var tope := roundi(lerpf(40.0, 60.0, grupo)) + rng.randi_range(-3, 3)
		if rng.randf() < 0.75:
			_pino(imagen, roundi(x), pie, tope - ARBOLES_SUELO_K, ARBOL_FONDO)
		else:
			_copa(imagen, roundi(x), pie, tope - ARBOLES_SUELO_K - 4, ARBOL_FONDO)
		x += rng.randf_range(8.0, 14.0)

	# Fila de adelante, mas baja y oscura, mitad copas redondas.
	rng.seed = 9
	x = 4.0
	while x < ancho:
		var grupo := _ruido_1d(x, 14, ancho, 82)
		var tope := roundi(lerpf(28.0, 46.0, grupo)) + rng.randi_range(-3, 3)
		if rng.randf() < 0.5:
			_pino(imagen, roundi(x), pie, tope - ARBOLES_SUELO_K, ARBOL)
		else:
			_copa(imagen, roundi(x), pie, tope - ARBOLES_SUELO_K, ARBOL)
		x += rng.randf_range(9.0, 15.0)

	# Monte bajo macizo: tapa troncos y cualquier claro hasta mas abajo del
	# suelo, que es lo que evita ver el cielo entre los arboles.
	for cx in ancho:
		var h := 22 + roundi(_ruido_1d(cx, 64, ancho, 21) * 5.0)
		_columna(imagen, cx, h, ARBOL)
	return imagen


## Pino de pisos con la punta `altura` texeles arriba de `pie`: cada piso se
## abre hacia abajo y el siguiente arranca mas angosto, que es lo que dibuja
## los escalones del contorno.
func _pino(imagen: Image, cx: int, pie: int, altura: int, color: Color) -> void:
	var punta := pie - altura + 1
	var pisos := clampi(altura / 9, 3, 6)
	var ancho_base := maxf(3.0, altura * 0.21)
	var follaje := float(altura - 2)
	for d in altura:
		var mitad := 0
		if d >= 2:
			var t := (d - 2) / follaje
			var en_piso := t * pisos - floorf(t * pisos)
			mitad = roundi(lerpf(1.0, ancho_base, t) * (0.55 + 0.45 * en_piso))
		_rect(imagen, cx - mitad, punta + d, mitad * 2 + 1, 1, color)


## Arbol de copa redonda: un disco con lobulos arriba y a los costados, como
## un coliflor, sobre un tronco corto.
func _copa(imagen: Image, cx: int, pie: int, altura: int, color: Color) -> void:
	var radio := clampi(roundi(altura * 0.3), 4, 11)
	var cy := pie - altura + radio + 1
	_disco(imagen, cx, cy, radio, color)
	var lobulos := 3 if radio < 8 else 4
	for i in lobulos:
		var ang := PI + PI * (i + 0.5) / lobulos
		_disco(imagen, cx + roundi(cos(ang) * radio * 0.7), cy + roundi(sin(ang) * radio * 0.6),
				maxi(2, roundi(radio * 0.45)), color)
	_disco(imagen, cx - roundi(radio * 0.85), cy + roundi(radio * 0.55), roundi(radio * 0.6), color)
	_disco(imagen, cx + roundi(radio * 0.85), cy + roundi(radio * 0.5), roundi(radio * 0.55), color)
	_rect(imagen, cx - 1, cy, 3, pie - cy + 1, color)


## Disco sin dientes sueltos en los cuatro extremos.
func _disco(imagen: Image, cx: int, cy: int, radio: int, color: Color) -> void:
	var r2 := radio * radio + radio
	for dy in range(-radio, radio + 1):
		for dx in range(-radio, radio + 1):
			if dx * dx + dy * dy <= r2:
				_px(imagen, cx + dx, cy + dy, color)


# --- Suelo --------------------------------------------------------------------

## Tipos de celda del suelo, antes de pasar a color.
enum Suelo { PASTO, OSCURO, TIERRA }


## Pasto pisoteado, 3.8 m por repeticion a 34 texeles por metro. Se ve
## rasante: a mitad del campo un texel mide ~2.5 px de ancho y menos de 1 de
## alto, asi que nada importante puede tener menos de 3 texeles de alto. Y se
## repite seguido, asi que ninguna mancha puede llamar la atencion sola: la
## variacion es chica y pareja.
func _suelo() -> Image:
	var lado := 128
	var imagen := _lienzo(lado, lado)
	var tipos := PackedInt32Array()
	tipos.resize(lado * lado)

	# Solo manchas de pasto oscuro: las claras con borde duro se leian como
	# parches repetidos. El verde claro queda para el grano.
	for y in lado:
		for x in lado:
			var n := _ruido_2d(x, y, 8, lado, 31) * 0.6 + _ruido_2d(x, y, 16, lado, 32) * 0.4
			tipos[y * lado + x] = Suelo.OSCURO if n < 0.38 else Suelo.PASTO

	# Tierra pisoteada: manchas estiradas en X, que es por donde pasan las
	# tropas, con el borde comido por ruido. [x, y, radio x, radio y]
	for mancha: Vector4 in [
		Vector4(24, 28, 11, 5), Vector4(90, 70, 8, 4), Vector4(54, 106, 13, 5),
		Vector4(112, 16, 5, 3),
	]:
		for dy in range(-9, 10):
			for dx in range(-18, 19):
				var x := posmod(roundi(mancha.x) + dx, lado)
				var y := posmod(roundi(mancha.y) + dy, lado)
				var d := Vector2(dx / mancha.z, dy / mancha.w).length()
				var borde := (_ruido_2d(x, y, 32, lado, 34) - 0.5) * 0.8 \
						+ (_ruido_2d(x, y, 16, lado, 37) - 0.5) * 0.6
				if d + borde < 1.0:
					tipos[y * lado + x] = Suelo.TIERRA
	_despeckle(tipos, lado, lado)

	var colores := [PASTO, PASTO_OSCURO, TIERRA]
	for y in lado:
		for x in lado:
			var tipo := tipos[y * lado + x]
			var color: Color = colores[tipo]
			# El borde de arriba de la tierra, mas oscuro: la mancha queda
			# apenas hundida respecto del pasto.
			if tipo == Suelo.TIERRA and tipos[posmod(y - 1, lado) * lado + x] != Suelo.TIERRA:
				color = TIERRA_OSCURA
			imagen.set_pixel(x, y, color)

	# Grano: rayitas cortas en X, que a ras del suelo es como se ve el pasto.
	# Sobre el pasto, claras con su sombra abajo; sobre lo oscuro, un tono
	# mas arriba y sin sombra, para que las manchas no se ensucien.
	for cy in range(0, lado, 4):
		for cx in range(0, lado, 4):
			if _azar(cx, cy, 38) > 0.2:
				continue
			var x := cx + floori(_azar(cx, cy, 39) * 4.0)
			var y := cy + floori(_azar(cx, cy, 40) * 4.0)
			var tipo := tipos[posmod(y, lado) * lado + posmod(x, lado)]
			if tipo == Suelo.TIERRA:
				continue
			var largo := 2 + floori(_azar(cx, cy, 41) * 2.0)
			for dx in largo:
				if tipo == Suelo.OSCURO:
					_px_toro(imagen, x + dx, y, PASTO)
				else:
					_px_toro(imagen, x + dx, y, PASTO_CLARO)
					_px_toro(imagen, x + dx, y + 1, PASTO_OSCURO)

	# Piedras: pocas y chicas, con sombra abajo.
	for piedra: Vector3i in [Vector3i(40, 50, 3), Vector3i(100, 96, 2), Vector3i(12, 88, 2), Vector3i(76, 12, 3)]:
		for dx in piedra.z:
			_px_toro(imagen, piedra.x + dx, piedra.y, PIEDRA)
			_px_toro(imagen, piedra.x + dx, piedra.y + 1, PIEDRA)
			_px_toro(imagen, piedra.x + dx, piedra.y + 2, TIERRA_OSCURA)
	return imagen


## Saca los pixeles sueltos: si tres o cuatro vecinos son de otro tipo, el
## pixel toma el tipo que mas se repite alrededor. En pixel art un punto
## aislado es ruido, no textura.
static func _despeckle(tipos: PackedInt32Array, ancho: int, alto: int) -> void:
	for pasada in 2:
		for y in alto:
			for x in ancho:
				var t := tipos[y * ancho + x]
				var vecinos := [
					tipos[posmod(y - 1, alto) * ancho + x],
					tipos[posmod(y + 1, alto) * ancho + x],
					tipos[y * ancho + posmod(x - 1, ancho)],
					tipos[y * ancho + posmod(x + 1, ancho)],
				]
				var distintos := 0
				for v: int in vecinos:
					if v != t:
						distintos += 1
				if distintos < 3:
					continue
				var votos := {}
				for v: int in vecinos:
					votos[v] = int(votos.get(v, 0)) + 1
				var mejor: int = vecinos[0]
				for v: int in votos:
					if int(votos[v]) > int(votos[mejor]):
						mejor = v
				tipos[y * ancho + x] = mejor


# --- Camino -------------------------------------------------------------------

## Franja de tierra apisonada con dos huellas de carro, de 3.8 x 1.9 m. Los
## bordes son pasto para que el quad se funda con el suelo sin alpha.
func _camino() -> Image:
	var ancho := 128
	var alto := 64
	var imagen := _lienzo(ancho, alto)
	for x in ancho:
		# Bordes ondulados y distintos arriba y abajo.
		var borde_sup := 5 + roundi(_ruido_1d(x, 16, ancho, 41) * 4.0)
		var borde_inf := alto - 6 - roundi(_ruido_1d(x, 16, ancho, 42) * 4.0)
		var huella_a := 18 + roundi((_ruido_1d(x, 4, ancho, 43) - 0.5) * 2.0)
		var huella_b := 40 + roundi((_ruido_1d(x, 4, ancho, 44) - 0.5) * 2.0)
		for y in alto:
			var color := TIERRA
			if y < borde_sup or y > borde_inf:
				var n := _ruido_2d(x, y, 16, ancho, 45)
				color = PASTO_OSCURO if n < 0.4 else PASTO
			elif y == borde_sup or y == borde_inf:
				color = TIERRA_OSCURA
			elif (y >= huella_a and y < huella_a + 4) or (y >= huella_b and y < huella_b + 4):
				# Huella: 4 texeles de alto, que es lo minimo que sobrevive
				# cuando el camino se ve rasante.
				color = TIERRA_OSCURA
			imagen.set_pixel(x, y, color)
	# Grano de la tierra: rayitas oscuras cortas, sin tocar las huellas.
	for cy in range(8, alto - 8, 4):
		for cx in range(0, ancho, 4):
			if _azar(cx, cy, 47) > 0.18:
				continue
			var x := cx + floori(_azar(cx, cy, 48) * 4.0)
			var y := cy + floori(_azar(cx, cy, 49) * 4.0)
			if imagen.get_pixel(posmod(x, ancho), y) != TIERRA:
				continue
			_px(imagen, x, y, TIERRA_OSCURA)
			_px(imagen, x + 1, y, TIERRA_OSCURA)
	# Matas en el lomo del medio y en los bordes, y piedritas.
	for i in 10:
		var x := floori(_azar(i, 0, 50) * ancho)
		var y := 27 + floori(_azar(i, 1, 50) * 7.0)
		_px(imagen, x, y, PASTO_OSCURO)
		_px(imagen, x + 1, y, PASTO)
		_px(imagen, x + 2, y, PASTO_OSCURO)
		_px(imagen, x + 1, y - 1, PASTO_CLARO)
	for i in 16:
		var x := floori(_azar(i, 2, 50) * ancho)
		var arriba := i % 2 == 0
		var y := 6 + floori(_azar(i, 3, 50) * 4.0) if arriba else alto - 8 - floori(_azar(i, 3, 50) * 4.0)
		_px(imagen, x, y, PASTO_CLARO)
		_px(imagen, x + 1, y, PASTO_CLARO)
		_px(imagen, x, y + (1 if arriba else -1), PASTO)
	for i in 5:
		var x := floori(_azar(i, 4, 50) * ancho)
		var y := 12 + floori(_azar(i, 5, 50) * 40.0)
		if imagen.get_pixel(posmod(x, ancho), y) != TIERRA:
			continue
		_px(imagen, x, y, PIEDRA)
		_px(imagen, x + 1, y, PIEDRA)
		_px(imagen, x, y + 1, TIERRA_OSCURA)
		_px(imagen, x + 1, y + 1, TIERRA_OSCURA)
	return imagen


# --- Muro y porton --------------------------------------------------------------

## Sillares de 16x8 en aparejo trabado (media pieza de corrimiento por hilada),
## con la junta oscura y un filo claro arriba de cada piedra. `piezas` es
## cuantas piedras entran por hilada en una repeticion: con el indice
## envuelto, la piedra que cruza el borde es la misma de los dos lados.
func _sillares(imagen: Image, x0: int, y0: int, ancho: int, alto: int, semilla: int, piezas := 0) -> void:
	for y in range(y0, y0 + alto):
		var hilada := floori(float(y - y0) / 8.0)
		var dentro_y := (y - y0) % 8
		for x in range(x0, x0 + ancho):
			var corrido := x + (8 if hilada % 2 == 1 else 0)
			var dentro_x := posmod(corrido, 16)
			var pieza := floori(corrido / 16.0)
			if piezas > 0:
				pieza = posmod(pieza, piezas)
			var color := PIEDRA_MEDIA
			if dentro_y == 7 or dentro_x == 15:
				color = PIEDRA_OSCURA
			elif dentro_y == 0:
				color = PIEDRA_CLARA
			elif _azar(pieza, hilada, semilla) < 0.12 and dentro_x < 14 and dentro_y > 4:
				color = PIEDRA_OSCURA
			_px(imagen, x, y, color)


## Segmento de muralla de 2.8 m que empalma consigo mismo en X: merlones de 20
## con huecos de 12 (periodo 32) y sillares de 16.
func _muro() -> Image:
	var ancho := 96
	var alto := 192
	var imagen := _lienzo(ancho, alto)
	var tope := 24
	for x in range(6, ancho, 32):
		_sillares(imagen, x, tope, 20, 16, 51, 6)
		_rect(imagen, x, tope, 20, 1, PIEDRA_CLARA)
	_sillares(imagen, 0, tope + 16, ancho, alto - tope - 16, 52, 6)
	# Cornisa bajo el adarve y zocalo abajo.
	_rect(imagen, 0, tope + 16, ancho, 2, PIEDRA_CLARA)
	_rect(imagen, 0, tope + 18, ancho, 1, PIEDRA_OSCURA)
	_rect(imagen, 0, alto - 12, ancho, 1, PIEDRA_CLARA)
	_rect(imagen, 0, alto - 3, ancho, 3, PIEDRA_OSCURA)
	return imagen


## Porton entre dos torrecitas. El muro del medio tiene la misma altura que
## muro.png, para que los segmentos le empalmen a los costados.
func _porton() -> Image:
	var ancho := 128
	var alto := 192
	var imagen := _lienzo(ancho, alto)
	var tope_muro := 24

	for x: int in [36, 68]:
		_sillares(imagen, x, tope_muro, 24, 16, 61)
		_rect(imagen, x, tope_muro, 24, 1, PIEDRA_CLARA)
	_sillares(imagen, 28, tope_muro + 16, 72, alto - tope_muro - 16, 62)
	_rect(imagen, 28, tope_muro + 16, 72, 2, PIEDRA_CLARA)
	_rect(imagen, 28, tope_muro + 18, 72, 1, PIEDRA_OSCURA)

	for x0: int in [0, 96]:
		_sillares(imagen, x0, 12, 32, alto - 12, 63 + x0)
		for m: int in [0, 12, 24]:
			_sillares(imagen, x0 + m, 0, 8, 12, 64 + x0)
			_rect(imagen, x0 + m, 0, 8, 1, PIEDRA_CLARA)
		# Matacan: una hilada saliente con canecillos debajo.
		_rect(imagen, x0, 12, 32, 3, PIEDRA_CLARA)
		_rect(imagen, x0, 15, 32, 1, PIEDRA_OSCURA)
		for c in range(x0 + 2, x0 + 32, 6):
			_rect(imagen, c, 16, 3, 2, PIEDRA_MEDIA)
			_rect(imagen, c, 18, 3, 1, PIEDRA_OSCURA)
		# Aspilleras con el derrame claro abajo.
		for y: int in [44, 100]:
			_rect(imagen, x0 + 15, y, 2, 12, PIEDRA_OSCURA)
			_rect(imagen, x0 + 14, y + 12, 4, 1, PIEDRA_CLARA)
		# Sombra donde la torre se adelanta al muro.
		var borde := x0 + 31 if x0 == 0 else x0
		_rect(imagen, borde, 19, 1, alto - 19, PIEDRA_OSCURA)

	# Arco de medio punto con dovelas (un anillo de piedras radiales) y el hueco
	# en sombra entre el arco y la puerta, que le da profundidad.
	var cx := 64
	var radio := 22
	var arranque := 104
	for y in range(arranque - radio - 6, alto):
		for x in range(cx - radio - 6, cx + radio + 6):
			var dy := maxf(0.0, float(arranque - y))
			var dx := x + 0.5 - cx
			var d := Vector2(dx, dy).length()
			if d <= radio:
				var color := MADERA
				var tabla := posmod(x - (cx - radio), 7)
				if tabla == 0:
					color = MADERA_OSCURA
				if d > radio - 3 and y <= arranque:
					color = MADERA_OSCURA
				if y == 130 or y == 131 or y == 162 or y == 163:
					color = HERRAJE
				imagen.set_pixel(x, y, color)
			elif d <= radio + 6 and y <= arranque:
				var ang := atan2(dy, dx)
				var dovela := posmod(floori(ang / PI * 9.0 + 0.5), 2)
				var color := PIEDRA_CLARA if dovela == 0 else PIEDRA_MEDIA
				if d > radio + 5 or absf(fposmod(ang / PI * 9.0 + 0.5, 1.0) - 0.5) > 0.44:
					color = PIEDRA_OSCURA
				imagen.set_pixel(x, y, color)
	# Clavos en las bandas y la argolla.
	for x in range(cx - radio + 3, cx + radio - 2, 7):
		_px(imagen, x, 126, HERRAJE)
		_px(imagen, x, 158, HERRAJE)
	_rect(imagen, cx + 8, 146, 3, 3, HERRAJE)
	_px(imagen, cx + 9, 147, MADERA)
	return imagen


# --- Fuente -------------------------------------------------------------------

## Copia la fuente tal cual: el EULA que trae adentro prohibe modificarla, y
## renombrar el archivo no toca sus bytes.
func _extraer_fuente() -> bool:
	var zip := ZIPReader.new()
	if zip.open(ProjectSettings.globalize_path(ZIP_FUENTE)) != OK:
		push_error("no se pudo abrir %s" % ZIP_FUENTE)
		return false
	var bytes := zip.read_file(FUENTE_EN_ZIP)
	zip.close()
	if bytes.is_empty():
		push_error("falta %s en el zip" % FUENTE_EN_ZIP)
		return false
	# Si ya esta igual no se toca: reescribirla le cambia la fecha y Godot
	# puede querer reimportarla por nada.
	if FileAccess.file_exists(RUTA_FUENTE) and FileAccess.get_file_as_bytes(RUTA_FUENTE) == bytes:
		print("  %-14s ya estaba (%d bytes, %s)" % [RUTA_FUENTE.get_file(), bytes.size(), FUENTE_EN_ZIP])
		return true
	var archivo := FileAccess.open(RUTA_FUENTE, FileAccess.WRITE)
	if archivo == null:
		push_error("no se pudo escribir %s" % RUTA_FUENTE)
		return false
	archivo.store_buffer(bytes)
	archivo.close()
	print("  %-14s %d bytes (%s)" % [RUTA_FUENTE.get_file(), bytes.size(), FUENTE_EN_ZIP])
	return true


## Valores del importador de fuentes para que los glifos salgan duros: sin
## antialiasing, sin hinting que mueva los bordes y sin posicion subpixel, que
## en una fuente pixel parte los trazos en dos columnas a medio tono.
const IMPORT_FUENTE := {
	"antialiasing": "0",
	"hinting": "0",
	"subpixel_positioning": "0",
	"multichannel_signed_distance_field": "false",
	"oversampling": "0.0",
	"generate_mipmaps": "false",
}


func _ajustar_import_fuente() -> void:
	var ruta := ProjectSettings.globalize_path(RUTA_FUENTE + ".import")
	if not FileAccess.file_exists(ruta):
		print("  ui.ttf.import todavia no existe: correr --import y volver a correr este script")
		return
	var lineas := FileAccess.get_file_as_string(ruta).split("\n")
	var cambios := 0
	for i in lineas.size():
		var partes := lineas[i].split("=", true, 1)
		if partes.size() == 2 and IMPORT_FUENTE.has(partes[0]) and partes[1] != IMPORT_FUENTE[partes[0]]:
			lineas[i] = "%s=%s" % [partes[0], IMPORT_FUENTE[partes[0]]]
			cambios += 1
	if cambios == 0:
		print("  ui.ttf.import ya estaba ajustado para pixel art")
		return
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	archivo.store_string("\n".join(lineas))
	archivo.close()
	print("  ui.ttf.import: %d valores ajustados (correr --import de nuevo)" % cambios)


# --- LEEME ----------------------------------------------------------------------

func _escribir_leemes(imagenes: Dictionary) -> bool:
	var filas := ""
	for nombre: String in ["arboles", "castillo", "montanas"]:
		var m := _medidas(nombre, imagenes[nombre])
		filas += "| `%s.png` | %.0f | %.2f | %.2f x %.2f | %.3f |\n" % [
			nombre, m["z"], m["base"], m["ancho"], m["alto"], 240.0 / float(m["ancho"])]
	var cielo: Dictionary = MONTAJE["cielo"]
	var castillo := _medidas("castillo", imagenes["castillo"])
	var fondos := """# Fondos del campo de batalla

Generados por `tools/gen_fondos.gd`: todo procedural, con semillas fijas.
**No editarlos a mano**: se cambia el generador y se vuelve a correr (ver el
encabezado del script). La vista previa con la camara de la batalla queda en
`user://fondos_preview.png`.

| Archivo | Tamano | Que es |
|---|---|---|
| `cielo.png` | 16x512 | Atardecer en 23 bandas planas (1b1a3a, 4a3560, c9694a) y abajo el resplandor e8a05a, macizo en el ultimo 15%: en pantalla solo asoma su filo en los valles. Se estira. |
| `montanas.png` | 1024x256 | Cordillera lejana 4c3f6b de picos suaves y, delante, un faldeo mas bajo y mas claro 5a4c7c: el aire entre las dos filas. Empalma en X. |
| `castillo.png` | 1024x256 | Castillo enemigo 352a4f en el centro de la repeticion (torreon, cuatro torres, muralla con almenas) con ventanas e8a05a, sobre una loma corrida. Empalma en X. |
| `arboles.png` | 1024x192 | Linea de pinos y copas redondas: fila de atras 241d3d, fila de adelante y monte bajo 1c1730. Empalma en X. |
| `suelo.png` | 128x128 | Pasto pisoteado (3f5a3a, 365033, 4a6a44) con manchas de tierra (6b5138, 5a432f) y alguna piedra 7d7a6e. Empalma en X y en Y. |
| `camino.png` | 128x64 | Tierra apisonada con dos huellas de carro y bordes de pasto. Empalma en X. |
| `muro.png` | 96x192 | Segmento de muralla de sillares con almenas, de frente (5a4c7c, 3d3358, 2a2340). Empalma en X. |
| `porton.png` | 128x192 | Porton en arco con puerta de tablones (6b4a2a, 4a321f) y herrajes 3a3a44 entre dos torrecitas. |

Las siluetas tienen alpha 0 o 255 (nada intermedio), fila de arriba vacia y
fila de abajo llena. Ninguna capa pasa de 6 colores salvo el cielo.

## Como se cuelgan

Pensado para la camara de `battle3d.gd` (fov 42, a 11 m, picado de 15
grados) a 1280x720. Cada capa es un `QuadMesh` con `center_offset =
(0, alto/2, 0)`, asi el nodo queda en el borde de abajo:

- `rotation_degrees = (-15, 0, 0)`: paralelo al plano de la camara. Parado
  derecho, las torres se inclinan hacia los bordes de la pantalla y los
  texeles cambian de tamano de arriba abajo.
- Material: `shading_mode = UNSHADED`, `transparency = ALPHA_SCISSOR`,
  `texture_filter = NEAREST` (el default es lineal con mipmaps),
  `texture_repeat = true`, `uv1_scale = (240 / ancho, 1, 1)` para un quad
  de 240 m y `disable_fog = true`: la perspectiva aerea ya esta pintada, y
  con la niebla actual las montanas quedarian tres cuartos azul noche.
- `cast_shadow = OFF`: el sol viene de atras, y la silueta proyectaria una
  franja de sombra hacia el campo.

| Capa | z (m) | Borde de abajo en y (m) | Una repeticion (m) | uv1_scale.x en 240 m |
|---|---|---|---|---|
""" + filas + """
Con esas medidas cada texel ocupa 2 px de pantalla exactos a 720p (como un
texel de sprite a mitad del campo; a otra resolucion escala igual que los
sprites): al moverse la camara los texeles no cambian de ancho, solo se
corren de a un pixel. Cada repeticion es mas ancha que todo lo que la camara
barre en una batalla, asi que ninguna capa se ve dos veces. Las bases
negativas hunden el pie macizo de cada capa bajo el suelo: es lo que tapa
los claros entre los arboles.

El centro de cada textura (columna 512) cae en la x del mundo que se elija
con `uv1_offset.x = 0.5 - (X - borde_izquierdo_del_quad) / ancho` (tomar la
parte fraccionaria). En el castillo esa columna es el torreon: conviene
ponerlo detras del lado enemigo. Con el quad centrado en x = 15 y el
torreon en x = 22 da `uv1_offset.x = {offset_castillo}`.

Cielo: quad del mismo estilo en z = {cielo_z}, con el borde de abajo en
y = {cielo_base} m y {cielo_alto} m de alto (`uv1_scale = (1, 1, 1)`; es liso
en X). Asi el azul noche queda arriba, bajo el HUD, el naranja detras de los
picos, y el borde de abajo del quad pasa por debajo del valle mas hondo de
la cordillera: no hay rendija por donde se vea el fondo del Environment.
Alternativa sin geometria: `Environment.background_mode = BG_CANVAS` y el
PNG en un `TextureRect` estirado en una `CanvasLayer` con `layer = -1`.

Niebla (opcional, probada en el render Compatibility): con
`fog_mode = FOG_MODE_DEPTH`, `fog_light_color = 1c1730`,
`fog_depth_begin = 16`, `fog_depth_end = 26` y `fog_density = 0.85` el campo
queda limpio y el pasto de atras se oscurece hacia el tono del monte, que
borra la raya recta donde el suelo se mete bajo los arboles. Las capas no la
ven por `disable_fog`.

Suelo: `uv1_scale` = metros del plano x 34 / 128 (una repeticion cada
3.76 m): el pasto queda con el mismo texel que los sprites. Con el plano
actual de 66 x 30 m son `(17.53, 7.97, 1)`; si se quieren numeros redondos,
una repeticion cada 4 m (32 texeles/m, el tile de 32 px = 1 m) da
`(16.5, 7.5, 1)`. Con la luz actual (sol fff2d8 x1.1) el pasto renderiza
entre 1.6 y 2 veces su albedo en lineal: si para el atardecer se ve muy vivo,
conviene bajar o entibiar el sol antes que oscurecer la textura. El camino va
igual que el suelo: 34 texeles/m, o sea 3.76 x 1.88 m por repeticion.

Muro y porton: a 34 texeles/m miden 2.8 x 5.6 m y 3.8 x 5.6 m. Con la
camara actual, parado en el fondo del campo (z = 0) el borde de arriba de
la pantalla queda a ~5.5 m: el porton entra justo; mas adelante se corta.

## Origen y atribucion

No hay pixeles de terceros: todo sale del script. Se miro el pack
*Free Prototype 2D Platformer 32x32 Pixel Tileset* de
[CraftPix](https://craftpix.net/freebies/)
(`_raw/craftpix-net-141897-free-prototype-2d-platformer-32x32-pixel-tileset.zip`)
para piedra y almenas, pero es un tileset de prototipo: cada tile trae un
"32" impreso y los `BackTiles` son formas planas con rotulos de angulo. De
ahi se tomo solo la escala (modulo de 32 px: sillares de 16x8, almenas y
torres en multiplos de 4) y las pendientes de 45 y 27 grados de las laderas.
Licencia del pack: https://craftpix.net/file-licenses/
""".format({
		"cielo_z": "%.0f" % float(cielo["z"]),
		"cielo_base": "%.2f" % float(cielo["base"]),
		"cielo_alto": "%.1f" % float(cielo["alto"]),
		"offset_castillo": "%.3f" % fposmod(0.5 - (22.0 - (15.0 - 120.0)) / float(castillo["ancho"]), 1.0),
	})

	var fuentes := """# Fuente de la interfaz

`ui.ttf` es **Planes_ValMore** ("Typeface (c) ValMore. 2019. All Rights
Reserved", version 1.00), copiada sin tocar un byte de
`_raw/craftpix-671189-10-magic-sprite-sheet-effects-pixel-art.zip`
(`Font/Planes_ValMore.ttf`; la misma viene en los packs 897123 y 987745).
La extrae `tools/gen_fondos.gd`, que tambien deja `ui.ttf.import` sin
antialiasing, sin hinting y sin posicion subpixel.

## Licencia: pendiente de verificar

- El zip no trae `Font.txt` ni licencia de la fuente: solo `License.txt` con
  la URL de CraftPix, https://craftpix.net/file-licenses/ .
- La fuente trae adentro (tabla `name`, campo de descripcion de licencia) un
  EULA de ValMore en ruso. Resumido: la licencia es para un usuario o
  empresa; la fuente sigue siendo de ValMore; se pueden hacer copias de
  respaldo pero **no modificarla** ni hacer fuentes derivadas; para usarla en
  un juego u otro software **no hace falta una licencia especial**; se puede
  usar en proyectos ilimitados; y el uso comercial es "despues de comprar la
  fuente". El contacto del autor esta en ese mismo campo.
- Lo que falta confirmar: si la licencia de CraftPix del pack gratuito cubre
  el uso comercial de una fuente de terceros que el EULA ata a una compra.
  Hasta entonces, tratarla como apta para el prototipo y revisarla antes de
  publicar.

## Uso

- La grilla de la fuente es de 68 unidades sobre 1000: un pixel de la fuente
  mide 0.068 em. Los tamanos nitidos son 15 (x1), 29 o 30 (x2) y 44 (x3); en
  16 o en 32 algunos pixeles salen dobles. Importada asi, los glifos salen
  sin un solo pixel de alpha intermedio.
- Glifos: ASCII menos `$ & ' < > ^ ~` y el acento grave, cirilico, comillas
  y rayas. **No trae acentos, ni ene, ni signos de apertura**: esos
  caracteres caen al fallback (en web, sin fuentes del sistema, se ven como
  cajitas). Hoy los usan el objetivo de e3 ("dano" con ene) y los botones
  "<" y ">" de `menu_principal.tscn` y `menu_pausa.tscn`: antes de aplicar
  la fuente a todo el tema hay que darles un fallback o cambiarlos.
"""
	var ok := _escribir_texto("%s/LEEME.md" % DIR, fondos)
	ok = _escribir_texto("%s/LEEME.md" % DIR_FUENTES, fuentes) and ok
	return ok


func _escribir_texto(ruta: String, texto: String) -> bool:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("no se pudo escribir %s" % ruta)
		return false
	archivo.store_string(texto)
	archivo.close()
	print("  %s" % ruta)
	return true


# --- Vistas previas -------------------------------------------------------------

## Todo va a user://: son para mirar, no se versionan.
func _vistas_previas(imagenes: Dictionary) -> void:
	_vista(imagenes, 15.0).save_png("user://fondos_preview.png")
	print("  user://fondos_preview.png (camara a mitad del campo)")
	_vista(imagenes, 22.5).save_png("user://fondos_preview_derecha.png")
	print("  user://fondos_preview_derecha.png (camara en el tope enemigo)")
	_vista(imagenes, 15.0, false).save_png("user://fondos_preview_sin_niebla.png")
	print("  user://fondos_preview_sin_niebla.png")

	# El suelo repetido 3x3, para buscar costuras a ojo.
	var suelo: Image = imagenes["suelo"]
	var mosaico := Image.create_empty(suelo.get_width() * 3, suelo.get_height() * 3, false, Image.FORMAT_RGBA8)
	for j in 3:
		for i in 3:
			mosaico.blit_rect(suelo, Rect2i(Vector2i.ZERO, suelo.get_size()),
					Vector2i(i * suelo.get_width(), j * suelo.get_height()))
	mosaico.resize(mosaico.get_width() * 2, mosaico.get_height() * 2, Image.INTERPOLATE_NEAREST)
	mosaico.save_png("user://fondos_suelo_3x3.png")
	print("  user://fondos_suelo_3x3.png")


## Dibuja lo que veria la camara de la batalla: tira un rayo por pixel contra
## el suelo y los quads de las capas tal como dice MONTAJE. No es el render de
## Godot (no hay sombras y la luz del suelo es una medicion), pero la
## proyeccion, el muestreo nearest y la niebla son los mismos: contra una
## captura del render Compatibility, el 99.7% de los pixeles del fondo
## difiere en 6 niveles o menos (lo que redondea el render en los oscuros).
func _vista(imagenes: Dictionary, camara_x: float, con_niebla := true) -> Image:
	var ancho := 1280
	var alto := 720
	var imagen := Image.create_empty(ancho, alto, false, Image.FORMAT_RGBA8)
	var ang := deg_to_rad(CAMARA_ANGULO)
	var ojo := _ojo(camara_x)
	var adelante := Vector3(0.0, -sin(ang), -cos(ang))
	var arriba := Vector3(0.0, cos(ang), -sin(ang))
	var tan_medio := tan(deg_to_rad(CAMARA_FOV * 0.5))
	var aspecto := float(ancho) / alto

	var suelo: Image = imagenes["suelo"]
	var cielo: Image = imagenes["cielo"]
	var capas: Array[Image] = []
	var profundidades := PackedFloat32Array()
	var bordes: Array[Vector3] = []
	var anchos := PackedFloat32Array()
	var altos := PackedFloat32Array()
	var desfases := PackedFloat32Array()
	for nombre: String in ["arboles", "castillo", "montanas"]:
		var m := _medidas(nombre, imagenes[nombre])
		capas.append(imagenes[nombre])
		profundidades.append(m["profundidad"])
		bordes.append(Vector3(0.0, m["base"], m["z"]))
		anchos.append(m["ancho"])
		altos.append(m["alto"])
		# Corre la textura para que el centro de la repeticion caiga en
		# CENTRO_X[nombre]: el castillo detras del lado enemigo.
		desfases.append(float(CENTRO_X[nombre]) - float(m["ancho"]) * 0.5)
	var m_cielo: Dictionary = MONTAJE["cielo"]
	var borde_cielo := Vector3(0.0, m_cielo["base"], m_cielo["z"])
	var profundidad_cielo := _profundidad(m_cielo["z"], m_cielo["base"])

	for py in alto:
		var ny := 1.0 - (py + 0.5) / (alto * 0.5)
		var luz := _luz_suelo(py)
		for px in ancho:
			var nx := (px + 0.5) / (ancho * 0.5) - 1.0
			# Con adelante de largo 1 y derecha/arriba perpendiculares, el
			# parametro del rayo es justo la profundidad sobre el eje de vision.
			var dir := adelante + Vector3(nx * tan_medio * aspecto, 0.0, 0.0) + arriba * (ny * tan_medio)
			var color := TRANSPARENTE
			# El plano del suelo de la batalla termina en z = -10: mas atras el
			# rayo sigue de largo y lo frenan los pies hundidos de las capas.
			var t_suelo := INF
			if dir.y < 0.0:
				var t := -ojo.y / dir.y
				if ojo.z + dir.z * t >= SUELO_Z_MIN:
					t_suelo = t
			for i in capas.size():
				if t_suelo < profundidades[i]:
					break
				var p := ojo + dir * profundidades[i]
				var s := (p - bordes[i]).dot(arriba)
				var c := _muestra_capa(capas[i], p.x - desfases[i], s, anchos[i], altos[i])
				if c.a > 0.5:
					color = c
					break
			if color.a == 0.0 and t_suelo < INF:
				var p := ojo + dir * t_suelo
				color = _muestra_suelo(suelo, p.x, p.z, luz)
				if con_niebla:
					# Como el shader de Godot: smoothstep entre desde y hasta
					# sobre la distancia a la camara, por la densidad, y la
					# mezcla en lineal (en sRGB oscurece de mas).
					var f := smoothstep(float(NIEBLA["desde"]), float(NIEBLA["hasta"]), (p - ojo).length())
					var niebla: Color = NIEBLA["color"]
					color = color.srgb_to_linear().lerp(niebla.srgb_to_linear(),
							f * float(NIEBLA["densidad"])).linear_to_srgb()
			if color.a == 0.0:
				var p := ojo + dir * profundidad_cielo
				var s := (p - borde_cielo).dot(arriba)
				var v := 1.0 - s / float(m_cielo["alto"])
				if v >= 0.0 and v < 1.0:
					color = cielo.get_pixel(0, floori(v * cielo.get_height()))
				else:
					# Fuera del quad del cielo se ve el fondo del Environment
					# de la batalla: si aparece, falta cielo.
					color = Color("161a27")
			imagen.set_pixel(px, py, color)

	# Referencias de escala: un sprite de 68x136 px por bando y el healer.
	for ref: Array in [[440, Color("4a7fd4")], [606, Color("e0b84a")], [772, Color("c4553f")]]:
		imagen.fill_rect(Rect2i(ref[0], 400 - 136, 68, 136), ref[1])
	return imagen


## Muestra nearest de una capa en el punto x (metros del mundo) y s (metros
## sobre el quad desde su borde inferior).
static func _muestra_capa(capa: Image, x: float, s: float, ancho_m: float, alto_m: float) -> Color:
	var v := 1.0 - s / alto_m
	if v < 0.0 or v >= 1.0:
		return TRANSPARENTE
	var u := fposmod(x / ancho_m, 1.0)
	return capa.get_pixel(mini(floori(u * capa.get_width()), capa.get_width() - 1),
			mini(floori(v * capa.get_height()), capa.get_height() - 1))


static func _muestra_suelo(suelo: Image, x: float, z: float, luz: Color) -> Color:
	var escala := SUELO_TEXELES_POR_METRO
	var tx := posmod(floori(x * escala), suelo.get_width())
	var ty := posmod(floori(z * escala), suelo.get_height())
	var albedo := suelo.get_pixel(tx, ty).srgb_to_linear()
	return Color(albedo.r * luz.r, albedo.g * luz.g, albedo.b * luz.b).linear_to_srgb()


## Cuanto aclara la luz de la batalla al albedo del suelo, en lineal, medido
## contra una captura del render Compatibility con la luz de gen_scenes3d (sol
## fff2d8 x1.1 a -52/-130, ambiente 5a6180 x0.9, rugosidad 1). Un Lambert a
## mano da la mitad: con el rayo rasante el especular y el difuso Burley suman
## mucho, y mas cuanto mas lejos. De la fila 310 de pantalla a la 660.
const LUZ_SUELO_LEJOS := Color(2.07, 1.84, 1.95)
const LUZ_SUELO_CERCA := Color(1.75, 1.58, 1.60)


static func _luz_suelo(fila: int) -> Color:
	return LUZ_SUELO_LEJOS.lerp(LUZ_SUELO_CERCA, clampf((fila - 310.0) / 350.0, 0.0, 1.0))
