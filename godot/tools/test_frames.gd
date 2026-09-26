extends PruebaBase
## Las hojas de sprites y sus SpriteFrames: que esten las animaciones que el
## codigo pide, con sus cuadros; que cada hoja mida lo que dice su tabla; que el
## contorno horneado este entero, sea del color de su lado y no cruce al cuadro
## vecino; que los efectos no lo tengan, y que nada se importe comprimido.
##
## Las tablas estan escritas a mano y no se leen de gen_frames.gd: si alguien
## cambia una hoja o un rango sin querer, esta prueba es la que avisa.
##
## No depende de la fisica: todo se comprueba en el primer tick.

const DIR := "res://assets/sprites"

const ALIADO := Color("#4a7fd4")
const ENEMIGO := Color("#c4553f")
const JUGADOR_1 := Color("#e8b84a")
const JUGADOR_2 := Color("#5fd3c7")
const CONTORNOS := [ALIADO, ENEMIGO, JUGADOR_1, JUGADOR_2]

## Los mismos umbrales que usa extraer_sprites.gd para hornear.
const ALFA_VACIO := 8
const ALFA_OPACO := 128

# animacion: [hoja, lado, cuadros de la hoja, cuadros de la animacion,
# primer cuadro usado (opcional, 0 si falta)]

const HEALER := {
	"idle": ["idle.png", 128, 6, 6],
	"walk": ["walk.png", 128, 12, 12],
	"run": ["run.png", 128, 12, 12],
	"jump": ["jump.png", 128, 10, 4, 5],
	"fall": ["fall.png", 128, 11, 11],
	"land": ["land.png", 128, 6, 6],
	"hurt": ["hurt.png", 128, 3, 3],
	"dead": ["dead.png", 128, 5, 5],
	"cast": ["cast.png", 128, 8, 8],
	"healing": ["healing.png", 128, 8, 8],
	"power_boost": ["power_boost.png", 128, 10, 10],
	"resurrection": ["resurrection.png", 128, 8, 8],
	"magic_shield": ["magic_shield.png", 128, 12, 12],
	"energy_wave": ["energy_wave.png", 128, 7, 7],
	"aerial_strike": ["aerial_strike.png", 128, 9, 9],
}

const ESPERADO := {
	"soldier": {
		"idle": ["idle.png", 128, 6, 6],
		"walk": ["walk.png", 128, 12, 12],
		"run": ["run.png", 128, 12, 12],
		"attack": ["attack.png", 128, 4, 4],
		"hurt": ["hurt.png", 128, 4, 4],
		"dead": ["dead.png", 128, 5, 5],
	},
	"lancero": {
		"idle": ["idle.png", 128, 6, 6],
		"walk": ["walk.png", 128, 12, 12],
		"run": ["run.png", 128, 12, 12],
		"attack": ["attack.png", 128, 5, 5],
		"hurt": ["hurt.png", 128, 4, 4],
		"dead": ["dead.png", 128, 5, 5],
	},
	"espadachin": {
		"idle": ["idle.png", 128, 6, 6],
		"walk": ["walk.png", 128, 12, 12],
		"run": ["run.png", 128, 12, 12],
		"attack": ["attack.png", 128, 6, 6],
		"hurt": ["hurt.png", 128, 4, 4],
		"dead": ["dead.png", 128, 5, 5],
	},
	"enemy": {
		"idle": ["idle.png", 128, 7, 7],
		"walk": ["walk.png", 128, 11, 11],
		"run": ["run.png", 128, 11, 11],
		"attack": ["attack.png", 128, 4, 4],
		"hurt": ["hurt.png", 128, 4, 4],
		"dead": ["dead.png", 128, 6, 6],
	},
	"healer": HEALER,
	"healer2": HEALER,
	"bruto": {
		"idle": ["idle.png", 40, 4, 4],
		"walk": ["walk.png", 40, 6, 6],
		"run": ["walk.png", 40, 6, 6],
		"attack": ["attack.png", 40, 6, 6],
		"hurt": ["hurt.png", 40, 4, 4],
		"dead": ["dead.png", 40, 6, 6],
	},
	"demonio": {
		"idle": ["idle.png", 96, 6, 6],
		"walk": ["walk.png", 96, 6, 6],
		"run": ["run.png", 96, 8, 8],
		"attack": ["attack.png", 96, 4, 4],
		"attack2": ["attack2.png", 96, 8, 8],
		"hurt": ["hurt.png", 96, 4, 4],
		"dead": ["dead.png", 96, 4, 4],
		"sneer": ["sneer.png", 96, 6, 6],
	},
	"fx": {
		"heal": ["heal.png", 72, 10, 10],
		"shield": ["shield.png", 72, 8, 8],
		"toque": ["toque.png", 72, 7, 7],
		"plegaria": ["plegaria.png", 72, 10, 10],
		"bendicion": ["bendicion.png", 72, 8, 8],
		"oleada": ["oleada.png", 72, 10, 10],
		"impulso": ["impulso.png", 72, 10, 10],
		"caida": ["caida.png", 128, 8, 8],
		"reanimar": ["reanimar.png", 128, 8, 8],
	},
}

## De que color es el contorno de cada carpeta. fx no esta: no lleva.
const CONTORNO_DE := {
	"soldier": ALIADO,
	"lancero": ALIADO,
	"espadachin": ALIADO,
	"enemy": ENEMIGO,
	"bruto": ENEMIGO,
	"demonio": ENEMIGO,
	"healer": JUGADOR_1,
	"healer2": JUGADOR_2,
}


func fase(numero: int) -> void:
	if numero != 0:
		return
	for carpeta: String in ESPERADO:
		_revisar_frames(carpeta, ESPERADO[carpeta])
	_revisar_gemelos()
	_revisar_contornos()
	_revisar_efectos()
	_revisar_importacion()
	terminar()


# --- SpriteFrames y medidas -------------------------------------------------

func _revisar_frames(carpeta: String, tabla: Dictionary) -> void:
	print("--- %s ---" % carpeta)
	var ruta := "%s/%s/%s_frames.tres" % [DIR, carpeta, carpeta]
	var frames := load(ruta) as SpriteFrames
	_ok("%s carga" % ruta.get_file(), frames != null)
	if frames == null:
		return

	var nombres := frames.get_animation_names()
	nombres.sort()
	var esperadas := PackedStringArray(tabla.keys())
	esperadas.sort()
	_ok("tiene exactamente %s" % ", ".join(esperadas), nombres == esperadas)

	var mal: PackedStringArray = []
	for animacion: String in tabla:
		if not _animacion_correcta(frames, carpeta, animacion, tabla[animacion]):
			mal.append(animacion)
	_ok("cada animacion con sus cuadros de la hoja y el lado esperados%s" % _cuales(mal), mal.is_empty())

	mal = PackedStringArray()
	for animacion: String in tabla:
		var datos: Array = tabla[animacion]
		var hoja := _cargar("%s/%s" % [carpeta, datos[0]])
		if hoja == null or hoja.get_width() != datos[1] * datos[2] or hoja.get_height() != datos[1]:
			mal.append(datos[0])
	_ok("cada PNG mide cuadros x lado de ancho y lado de alto%s" % _cuales(mal), mal.is_empty())


func _animacion_correcta(frames: SpriteFrames, carpeta: String, animacion: String, datos: Array) -> bool:
	if not frames.has_animation(animacion):
		return false
	var lado: int = datos[1]
	var cuadros: int = datos[3]
	var desde: int = datos[4] if datos.size() > 4 else 0
	if frames.get_frame_count(animacion) != cuadros:
		return false
	var hoja := "%s/%s/%s" % [DIR, carpeta, datos[0]]
	for i in cuadros:
		var atlas := frames.get_frame_texture(animacion, i) as AtlasTexture
		if atlas == null or atlas.atlas == null or atlas.atlas.resource_path != hoja:
			return false
		if atlas.region != Rect2((desde + i) * lado, 0, lado, lado):
			return false
	return true


## healer2 es el healer con otro contorno: mismo juego de animaciones con los
## mismos cuadros, velocidad y loop, asi el codigo los maneja igual.
func _revisar_gemelos() -> void:
	print("--- healer y healer2 ---")
	var uno := load("%s/healer/healer_frames.tres" % DIR) as SpriteFrames
	var dos := load("%s/healer2/healer2_frames.tres" % DIR) as SpriteFrames
	if uno == null or dos == null:
		_ok("cargan los dos", false)
		return
	var iguales := uno.get_animation_names() == dos.get_animation_names()
	if iguales:
		for animacion in uno.get_animation_names():
			iguales = iguales \
				and uno.get_frame_count(animacion) == dos.get_frame_count(animacion) \
				and uno.get_animation_speed(animacion) == dos.get_animation_speed(animacion) \
				and uno.get_animation_loop(animacion) == dos.get_animation_loop(animacion)
	_ok("mismas animaciones, cuadros, velocidad y loop", iguales)


# --- Contorno ------------------------------------------------------------------

func _revisar_contornos() -> void:
	print("--- contorno horneado ---")
	var pedidos := {
		"soldier/idle.png": ALIADO,
		"enemy/idle.png": ENEMIGO,
		"healer/idle.png": JUGADOR_1,
		"healer2/idle.png": JUGADOR_2,
	}
	for ruta: String in pedidos:
		var color: Color = pedidos[ruta]
		var medida := _medir_contorno(_cargar(ruta), color)
		_ok("%s tiene pixeles #%s junto a pixeles vacios (%d)" % [
			ruta, color.to_html(false), medida[0]], medida[0] > 0)

	# El resto de las hojas, con la regla completa: que el contorno rodee toda
	# la figura, que cada pixel de contorno toque la figura de su propio cuadro
	# y que no aparezca el color de otro lado.
	for carpeta: String in CONTORNO_DE:
		var color: Color = CONTORNO_DE[carpeta]
		var incompletas: PackedStringArray = []
		var sueltas: PackedStringArray = []
		var ajenas: PackedStringArray = []
		for hoja in _hojas(carpeta):
			var medida := _medir_contorno(_cargar("%s/%s" % [carpeta, hoja]), color)
			if medida[0] == 0 or medida[1] > 0:
				incompletas.append(hoja)
			if medida[2] > 0:
				sueltas.append(hoja)
			if medida[3] > 0:
				ajenas.append(hoja)
		_ok("%s: contorno #%s alrededor de toda la figura%s" % [
			carpeta, color.to_html(false), _cuales(incompletas)], incompletas.is_empty())
		_ok("%s: ningun contorno cruza de cuadro ni queda suelto%s" % [carpeta, _cuales(sueltas)],
			sueltas.is_empty())
		_ok("%s: sin colores de contorno de otro lado%s" % [carpeta, _cuales(ajenas)],
			ajenas.is_empty())


## Recorre la hoja cuadro por cuadro y devuelve cuatro cuentas:
## [0] pixeles del color de contorno que tocan un vacio,
## [1] vacios que tocan la figura sin contorno en el medio,
## [2] pixeles de contorno que no tocan la figura de su mismo cuadro,
## [3] pixeles visibles con el color de otro contorno.
## "Tocar" es en 8-vecindad y sin salir del cuadro, como al hornear.
func _medir_contorno(hoja: Image, color: Color) -> Array[int]:
	var cuentas: Array[int] = [0, 0, 0, 0]
	if hoja == null:
		return cuentas
	var propio := _rgb(color)
	var otros: Array[int] = []
	for otro: Color in CONTORNOS:
		if otro != color:
			otros.append(_rgb(otro))

	var lado := hoja.get_height()
	var ancho := hoja.get_width()
	var datos := hoja.get_data()
	for c in int(ancho / float(lado)):
		var x0 := c * lado
		var usado := hoja.get_region(Rect2i(x0, 0, lado, lado)).get_used_rect()
		if not usado.has_area():
			continue
		# Un pixel de contorno, o un vacio que lo necesite, esta a lo sumo a un
		# pixel de lo dibujado.
		var zona := usado.grow(1).intersection(Rect2i(0, 0, lado, lado))
		for y in range(zona.position.y, zona.end.y):
			for x in range(x0 + zona.position.x, x0 + zona.end.x):
				var i := (y * ancho + x) * 4
				var alfa := datos[i + 3]
				var rgb := (datos[i] << 16) | (datos[i + 1] << 8) | datos[i + 2]
				if alfa < ALFA_VACIO:
					if _toca(datos, ancho, lado, x0, x, y, propio, true):
						cuentas[1] += 1
					continue
				if alfa == 255 and rgb == propio:
					if _toca(datos, ancho, lado, x0, x, y, propio, false):
						cuentas[0] += 1
					if not _toca(datos, ancho, lado, x0, x, y, propio, true):
						cuentas[2] += 1
				if rgb in otros:
					cuentas[3] += 1
	return cuentas


## Si algun vecino del pixel, dentro de su cuadro, es figura (opaco y no del
## color de contorno) o, con figura en false, un vacio.
func _toca(datos: PackedByteArray, ancho: int, lado: int, x0: int, x: int, y: int,
		propio: int, figura: bool) -> bool:
	for vy in range(maxi(y - 1, 0), mini(y + 2, lado)):
		for vx in range(maxi(x - 1, x0), mini(x + 2, x0 + lado)):
			if vx == x and vy == y:
				continue
			var i := (vy * ancho + vx) * 4
			var alfa := datos[i + 3]
			if figura:
				var rgb := (datos[i] << 16) | (datos[i + 1] << 8) | datos[i + 2]
				if alfa >= ALFA_OPACO and rgb != propio:
					return true
			elif alfa < ALFA_VACIO:
				return true
	return false


# --- Efectos e importacion -------------------------------------------------

func _revisar_efectos() -> void:
	print("--- efectos sin contorno ---")
	var colores: Array[int] = []
	for color: Color in CONTORNOS:
		colores.append(_rgb(color))
	var con_contorno: PackedStringArray = []
	for hoja in _hojas("fx"):
		var cuenta := _contar_colores(_cargar("fx/%s" % hoja), colores)
		if hoja == "toque.png":
			_ok("fx/toque.png no tiene ningun color de contorno (%d)" % cuenta, cuenta == 0)
		elif cuenta > 0:
			con_contorno.append(hoja)
	_ok("ni el resto de fx%s" % _cuales(con_contorno), con_contorno.is_empty())


func _contar_colores(hoja: Image, colores: Array[int]) -> int:
	if hoja == null:
		return -1
	var datos := hoja.get_data()
	var cuenta := 0
	for i in range(0, datos.size(), 4):
		if datos[i + 3] > 0 and ((datos[i] << 16) | (datos[i + 1] << 8) | datos[i + 2]) in colores:
			cuenta += 1
	return cuenta


## Pixel art comprimido pierde los colores exactos del contorno, y
## detect_3d/compress_to=1 lo comprime solo la primera vez que un sprite se
## dibuja en 3D, que es justo lo que hacen todos estos.
func _revisar_importacion() -> void:
	print("--- importacion ---")
	var imports := _archivos(DIR, ".import")
	var comprimidos: PackedStringArray = []
	for ruta in imports:
		var texto := FileAccess.get_file_as_string(ruta)
		if texto.contains("compress/mode=2") or texto.contains("detect_3d/compress_to=1"):
			comprimidos.append(ruta.trim_prefix(DIR + "/"))
	_ok("ningun .import con compress/mode=2 ni detect_3d/compress_to=1 (%d revisados)%s" % [
		imports.size(), _cuales(comprimidos)], not imports.is_empty() and comprimidos.is_empty())

	var sin_importar: PackedStringArray = []
	for ruta in _archivos(DIR, ".png"):
		if not FileAccess.file_exists(ruta + ".import"):
			sin_importar.append(ruta.trim_prefix(DIR + "/"))
	_ok("cada PNG tiene su .import%s" % _cuales(sin_importar), sin_importar.is_empty())

	var leeme := FileAccess.get_file_as_string("%s/LEEME.md" % DIR)
	_ok("LEEME.md con la atribucion y la licencia", leeme.contains("craftpix.net/file-licenses"))


# --- Utilidades ------------------------------------------------------------

## Las hojas de una carpeta segun su tabla, sin repetir (run del bruto usa la
## misma hoja que walk).
func _hojas(carpeta: String) -> PackedStringArray:
	var hojas: PackedStringArray = []
	var tabla: Dictionary = ESPERADO[carpeta]
	for animacion: String in tabla:
		var hoja: String = tabla[animacion][0]
		if hoja not in hojas:
			hojas.append(hoja)
	return hojas


## El PNG tal como esta en disco, no la textura importada: lo que se comprueba
## es lo que escribio extraer_sprites.gd. Por ruta absoluta para que Godot no
## avise que cargar un recurso importado como imagen no anda exportado.
func _cargar(relativa: String) -> Image:
	var imagen := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [DIR, relativa]))
	if imagen != null:
		imagen.convert(Image.FORMAT_RGBA8)
	return imagen


func _archivos(carpeta: String, extension: String) -> PackedStringArray:
	var salida: PackedStringArray = []
	for archivo in DirAccess.get_files_at(carpeta):
		if archivo.ends_with(extension):
			salida.append(carpeta.path_join(archivo))
	for sub in DirAccess.get_directories_at(carpeta):
		salida.append_array(_archivos(carpeta.path_join(sub), extension))
	return salida


func _rgb(color: Color) -> int:
	return (color.r8 << 16) | (color.g8 << 8) | color.b8


func _cuales(lista: PackedStringArray) -> String:
	return "" if lista.is_empty() else " -> fallan: %s" % ", ".join(lista)
