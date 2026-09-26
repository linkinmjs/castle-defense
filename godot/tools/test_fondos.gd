extends SceneTree
## Fondos del campo y fuente de la UI: que esten y midan lo que tienen que
## medir, que las capas empalmen consigo mismas, que el pixel art siga duro
## (alpha 0 o 255, paleta corta) y que la fuente se importe sin suavizado.
##
## Lee los PNG fuente y no las texturas importadas: lo que se controla es lo
## que escribio tools/gen_fondos.gd, pixel por pixel.

const DIR := "res://assets/fondos"
const RUTA_FUENTE := "res://assets/fonts/ui.ttf"

const TAMANOS := {
	"cielo": Vector2i(16, 512),
	"montanas": Vector2i(1024, 256),
	"castillo": Vector2i(1024, 256),
	"arboles": Vector2i(1024, 192),
	"suelo": Vector2i(128, 128),
	"camino": Vector2i(128, 64),
	"muro": Vector2i(96, 192),
	"porton": Vector2i(128, 192),
}
## Las que van en un quad con repeat: el ancho tiene que ser potencia de 2.
const CAPAS := ["cielo", "montanas", "castillo", "arboles", "suelo", "camino"]
## Recortes con alpha que tienen que empalmar en X y apoyarse en el borde de
## abajo. El muro tambien empalma, pero no apoya en toda la fila de arriba.
const SILUETAS := ["montanas", "castillo", "arboles"]
const RECORTES := ["montanas", "castillo", "arboles", "muro", "porton"]
## Paleta corta: todas menos el cielo, que es el unico degradado.
const MAX_COLORES := 6

var _fallos := 0


func _initialize() -> void:
	var imagenes := _cargar()
	if imagenes.size() == TAMANOS.size():
		_potencias(imagenes)
		_siluetas(imagenes)
		_pisos(imagenes)
		_cielo(imagenes["cielo"])
		_paletas(imagenes)
	_fuente()
	_imports()

	print("")
	print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _cargar() -> Dictionary:
	print("--- estan y miden lo que tienen que medir ---")
	var imagenes := {}
	for nombre: String in TAMANOS:
		var ruta := "%s/%s.png" % [DIR, nombre]
		var tamano: Vector2i = TAMANOS[nombre]
		if not FileAccess.file_exists(ruta):
			_ok("%s.png existe" % nombre, false)
			continue
		# Con la ruta del sistema y no res://: asi Godot no avisa que se esta
		# salteando el importador, que es justo lo que se quiere aca.
		var imagen := Image.load_from_file(ProjectSettings.globalize_path(ruta))
		var ok := imagen != null and imagen.get_size() == tamano
		_ok("%s.png mide %dx%d" % [nombre, tamano.x, tamano.y], ok)
		if ok:
			imagen.convert(Image.FORMAT_RGBA8)
			imagenes[nombre] = imagen
	return imagenes


func _potencias(imagenes: Dictionary) -> void:
	print("--- las capas que se repiten tienen ancho potencia de 2 ---")
	for nombre: String in CAPAS:
		var ancho := (imagenes[nombre] as Image).get_width()
		_ok("%s: %d" % [nombre, ancho], ancho > 0 and (ancho & (ancho - 1)) == 0)


func _siluetas(imagenes: Dictionary) -> void:
	print("--- las siluetas empalman, apoyan y tienen borde duro ---")
	for nombre: String in SILUETAS + ["muro"]:
		var imagen: Image = imagenes[nombre]
		var ultima := imagen.get_width() - 1
		var izquierda := _altura_opaca(imagen, 0)
		var derecha := _altura_opaca(imagen, ultima)
		_ok("%s: la columna 0 y la %d arrancan a la misma altura (%d y %d)" % [
			nombre, ultima, izquierda, derecha], absi(izquierda - derecha) <= 2)
	for nombre: String in SILUETAS:
		var imagen: Image = imagenes[nombre]
		var arriba_vacia := true
		var abajo_llena := true
		for x in imagen.get_width():
			if imagen.get_pixel(x, 0).a8 != 0:
				arriba_vacia = false
			if imagen.get_pixel(x, imagen.get_height() - 1).a8 != 255:
				abajo_llena = false
		_ok("%s: fila de arriba transparente" % nombre, arriba_vacia)
		_ok("%s: fila de abajo opaca" % nombre, abajo_llena)
	for nombre: String in RECORTES:
		var intermedios := _contar(imagenes[nombre], func(c: Color) -> bool: return c.a8 != 0 and c.a8 != 255)
		_ok("%s: alpha 0 o 255, sin bordes suaves (%d intermedios)" % [nombre, intermedios], intermedios == 0)


## Altura del primer pixel opaco de la columna, contada desde abajo.
func _altura_opaca(imagen: Image, x: int) -> int:
	for y in imagen.get_height():
		if imagen.get_pixel(x, y).a8 > 0:
			return imagen.get_height() - y
	return 0


func _pisos(imagenes: Dictionary) -> void:
	print("--- el piso no tiene huecos y empalma ---")
	for nombre: String in ["suelo", "camino"]:
		var imagen: Image = imagenes[nombre]
		var huecos := _contar(imagen, func(c: Color) -> bool: return c.a8 != 255)
		_ok("%s: ningun pixel transparente (%d)" % [nombre, huecos], huecos == 0)
		_costura("%s: columna %d contra la 0" % [nombre, imagen.get_width() - 1], imagen, true)
	_costura("suelo: fila 127 contra la 0", imagenes["suelo"], false)


## Una costura se nota cuando el salto entre la ultima linea y la primera es
## mas grande que el salto tipico entre dos lineas vecinas de adentro. Para
## que la prueba muerda, el salto contra una linea lejana (la de la mitad)
## tiene que ser claramente mas grande que el de vecinas: se imprime al lado.
func _costura(que: String, imagen: Image, en_x: bool) -> void:
	var largo := imagen.get_width() if en_x else imagen.get_height()
	var vecinas := 0.0
	for i in largo - 1:
		vecinas += _salto(imagen, i, i + 1, en_x)
	vecinas /= largo - 1
	var borde := _salto(imagen, largo - 1, 0, en_x)
	var lejos := _salto(imagen, 0, largo / 2, en_x)
	_ok("%s (borde %.1f, vecinas %.1f, lejana %.1f)" % [que, borde, vecinas, lejos],
		borde <= vecinas * 1.5 + 1.0)


## Diferencia media de color, en unidades de 0 a 255 sumando RGB, entre dos
## columnas (o dos filas) enteras.
func _salto(imagen: Image, a: int, b: int, en_x: bool) -> float:
	var largo := imagen.get_height() if en_x else imagen.get_width()
	var suma := 0
	for i in largo:
		var ca := imagen.get_pixel(a, i) if en_x else imagen.get_pixel(i, a)
		var cb := imagen.get_pixel(b, i) if en_x else imagen.get_pixel(i, b)
		suma += absi(ca.r8 - cb.r8) + absi(ca.g8 - cb.g8) + absi(ca.b8 - cb.b8)
	return float(suma) / largo


func _cielo(imagen: Image) -> void:
	print("--- el cielo aclara de arriba hacia el horizonte ---")
	var luces := PackedFloat32Array()
	for y in imagen.get_height():
		var suma := 0.0
		for x in imagen.get_width():
			suma += imagen.get_pixel(x, y).get_luminance()
		luces.append(suma / imagen.get_width())
	var monotono := true
	for y in range(1, luces.size()):
		if luces[y] < luces[y - 1] - 0.0001:
			monotono = false
	_ok("ninguna fila es mas oscura que la de arriba", monotono)
	var tercio := imagen.get_height() / 3
	var medias: Array[float] = []
	for t in 3:
		var suma := 0.0
		for y in range(t * tercio, (t + 1) * tercio):
			suma += luces[y]
		medias.append(suma / tercio)
	_ok("tercios cada vez mas claros (%.2f, %.2f, %.2f)" % [medias[0], medias[1], medias[2]],
		medias[0] < medias[1] and medias[1] < medias[2])
	var arriba := imagen.get_pixel(0, 0).to_html(false)
	var abajo := imagen.get_pixel(0, imagen.get_height() - 1).to_html(false)
	_ok("arriba azul noche y abajo el resplandor (%s, %s)" % [arriba, abajo],
		arriba == "1b1a3a" and abajo == "e8a05a")


func _paletas(imagenes: Dictionary) -> void:
	print("--- paleta corta ---")
	for nombre: String in TAMANOS:
		if nombre == "cielo":
			continue
		var vistos := {}
		var imagen: Image = imagenes[nombre]
		for y in imagen.get_height():
			for x in imagen.get_width():
				var c := imagen.get_pixel(x, y)
				if c.a8 > 0:
					vistos[c.to_html(false)] = true
		_ok("%s: %d colores (maximo %d)" % [nombre, vistos.size(), MAX_COLORES], vistos.size() <= MAX_COLORES)


func _fuente() -> void:
	print("--- la fuente de la UI se importa como pixel art ---")
	_ok("ui.ttf existe", FileAccess.file_exists(RUTA_FUENTE))
	var ruta_import := RUTA_FUENTE + ".import"
	if not FileAccess.file_exists(ruta_import):
		_ok("ui.ttf.import existe (correr --import)", false)
		return
	var params := _params(ruta_import)
	_ok("antialiasing apagado", params.get("antialiasing", "") == "0")
	_ok("sin hinting", params.get("hinting", "") == "0")
	_ok("sin posicion subpixel", params.get("subpixel_positioning", "") == "0")
	_ok("sin campo de distancia (MSDF)", params.get("multichannel_signed_distance_field", "") == "false")
	# Si el .import se edito y nadie reimporto, el recurso sigue suavizado.
	var fuente := load(RUTA_FUENTE) as FontFile
	_ok("el recurso importado tambien viene sin antialiasing",
		fuente != null and fuente.antialiasing == TextServer.FONT_ANTIALIASING_NONE)


func _imports() -> void:
	print("--- los fondos se importan sin compresion de VRAM ---")
	var dir := DirAccess.open(DIR)
	if dir == null:
		_ok("%s existe" % DIR, false)
		return
	var pngs := 0
	var comprimidos: Array[String] = []
	for archivo in dir.get_files():
		if archivo.ends_with(".png"):
			pngs += 1
			if not FileAccess.file_exists("%s/%s.import" % [DIR, archivo]):
				_ok("%s tiene su .import (correr --import)" % archivo, false)
		elif archivo.ends_with(".import"):
			if _params("%s/%s" % [DIR, archivo]).get("compress/mode", "") == "2":
				comprimidos.append(archivo)
	_ok("los %d PNG estan importados" % pngs, pngs == TAMANOS.size())
	_ok("ninguno usa compress/mode=2 %s" % str(comprimidos), comprimidos.is_empty())


## La seccion [params] de un .import, como texto.
func _params(ruta: String) -> Dictionary:
	var params := {}
	var en_params := false
	for linea in FileAccess.get_file_as_string(ruta).split("\n"):
		linea = linea.strip_edges()
		if linea.begins_with("["):
			en_params = linea == "[params]"
			continue
		var partes := linea.split("=", true, 1)
		if en_params and partes.size() == 2:
			params[partes[0]] = partes[1]
	return params


func _contar(imagen: Image, criterio: Callable) -> int:
	var n := 0
	for y in imagen.get_height():
		for x in imagen.get_width():
			if criterio.call(imagen.get_pixel(x, y)):
				n += 1
	return n


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])
