extends SceneTree
## Encuentra las piezas sueltas dentro de una hoja del pack de UI.
##
## Las hojas del pack son atlas: muchas piezas separadas por transparencia. Para
## recortarlas hay que saber en que coordenadas esta cada una, y sacarlas a ojo
## de una captura es donde aparecen los errores de un pixel que despues se ven
## como un borde cortado.
##
## Agrupa los pixeles opacos en islas conectadas e imprime el rectangulo de cada
## una, listo para pegar como Rect2i en gen_ui.gd.
##
## Uso:
##   godot --headless --path godot --script res://tools/inspeccionar_atlas.gd -- <png> [alto_min]

## Las islas mas chicas que esto se agrupan aparte: suelen ser puntos sueltos de
## una sombra, no piezas de verdad.
const AREA_MINIMA := 24


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("falta la ruta del png")
		quit(1)
		return

	var imagen := Image.load_from_file(args[0])
	if imagen == null:
		print("no se pudo abrir %s" % args[0])
		quit(1)
		return

	var alto_min := int(args[1]) if args.size() > 1 else 0
	var islas := _buscar_islas(imagen)
	_informar(args[0], imagen, islas, alto_min)
	quit()


## Recorre la imagen y junta cada grupo de pixeles opacos vecinos. Sin
## recursion: una hoja de 400x528 desbordaria la pila.
func _buscar_islas(imagen: Image) -> Array[Rect2i]:
	var ancho := imagen.get_width()
	var alto := imagen.get_height()
	var visto := {}
	var islas: Array[Rect2i] = []

	for y in alto:
		for x in ancho:
			var clave := y * ancho + x
			if visto.has(clave) or imagen.get_pixel(x, y).a < 0.5:
				continue

			var pendientes: Array[Vector2i] = [Vector2i(x, y)]
			visto[clave] = true
			var caja := Rect2i(x, y, 1, 1)

			while not pendientes.is_empty():
				var p: Vector2i = pendientes.pop_back()
				caja = caja.expand(p).expand(p + Vector2i.ONE)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var v := p + Vector2i(dx, dy)
						if v.x < 0 or v.y < 0 or v.x >= ancho or v.y >= alto:
							continue
						var k := v.y * ancho + v.x
						if visto.has(k) or imagen.get_pixel(v.x, v.y).a < 0.5:
							continue
						visto[k] = true
						pendientes.append(v)

			islas.append(caja)

	islas.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		if a.position.y != b.position.y:
			return a.position.y < b.position.y
		return a.position.x < b.position.x)
	return islas


func _informar(ruta: String, imagen: Image, islas: Array[Rect2i], alto_min: int) -> void:
	print("%s  %dx%d  -> %d islas" % [
		ruta.get_file(), imagen.get_width(), imagen.get_height(), islas.size()])

	# Agrupadas por tamano: en un atlas, las piezas que cumplen la misma funcion
	# miden igual, asi que el conteo por tamano dice cuantas variantes hay.
	var por_tamano := {}
	for isla in islas:
		var clave := "%dx%d" % [isla.size.x, isla.size.y]
		por_tamano[clave] = por_tamano.get(clave, 0) + 1

	var tamanos := por_tamano.keys()
	tamanos.sort_custom(func(a: String, b: String) -> bool:
		return por_tamano[a] > por_tamano[b])
	print("--- tamanos mas repetidos ---")
	for t: String in tamanos.slice(0, 14):
		print("  %-12s x%d" % [t, por_tamano[t]])

	print("--- islas (fila por fila) ---")
	var fila_previa := -100
	for isla in islas:
		if isla.size.x * isla.size.y < AREA_MINIMA:
			continue
		if isla.size.y < alto_min:
			continue
		# Un renglon en blanco cada vez que baja de fila, para leerlo como se ve.
		if isla.position.y - fila_previa > 4:
			print("")
		fila_previa = isla.position.y
		print("  Rect2i(%3d, %3d, %3d, %3d),   # %dx%d" % [
			isla.position.x, isla.position.y, isla.size.x, isla.size.y,
			isla.size.x, isla.size.y])
