extends SceneTree
## Saca del pack de UI solo lo que el juego usa, escalado al doble.
##
## Los assets vienen a 1x: un panel mide 80x168 y en una pantalla de 1280x720 se
## veria como una estampilla. Se escalan aca y no en el nodo porque escalar un
## Control descoloca a los containers, que calculan el tamano minimo sin mirar
## la escala, y porque escalar el CanvasLayer partiria el HUD en dos sistemas de
## coordenadas: el overlay de unidades proyecta el mundo a pantalla en 1:1.
##
## x2 y no x3: a x3 el panel de opciones mide 1008x768 y no entra en 720 de alto.
##
## Los PNG que escribe este script NO se pueden cargar en la misma corrida. Hay
## que importar antes de generar el tema:
##   godot --headless --path godot --script res://tools/extraer_ui.gd
##   godot --headless --path godot --import
##   godot --headless --path godot --script res://tools/gen_ui.gd

const ESCALA := 2

const ZIP_UI := "res://assets/_raw/craftpix-net-255216-free-basic-pixel-art-ui-for-rpg.zip"
const ZIP_POCIONES := "res://assets/_raw/craftpix-net-665232-100-potion-pixel-art-icons.zip"
const DIR := "res://assets/ui"
const DIR_ICONOS := "res://assets/ui/habilidades"

## Los paneles del pack traen un boton de cerrar dibujado en la esquina
## superior derecha. El juego no lo usa, y al estirar el panel con 9-slice esa
## X se deforma. Se tapa con el espejo de la esquina izquierda, que es marco
## limpio, para que el marco quede parejo a cualquier tamano.
##
## Hoja -> [esquina superior izquierda del panel, lado del parche], en 1x.
const ESQUINAS := {
	"PNG/Main_menu.png": [Vector2i(96, 4), Vector2i(80, 24)],
	"PNG/Settings.png": [Vector2i(7, 0), Vector2i(98, 24)],
	"PNG/Win_loose.png": [Vector2i(11, 299), Vector2i(90, 22)],
}

## Solo las hojas que se usan, como pide assets/_raw/README.md. El resto del
## pack (tienda, inventario, crafteo) es de otro juego.
const HOJAS := {
	"PNG/Buttons.png": "botones.png",
	"PNG/Main_menu.png": "panel_menu.png",
	"PNG/Settings.png": "panel_opciones.png",
	"PNG/Win_loose.png": "panel_desenlace.png",
	"PNG/character_panel.png": "panel_ficha.png",
	"PNG/Icons.png": "iconos.png",
}

## Que poción le toca a cada habilidad: la carpeta es el color del liquido y el
## numero es la silueta. Las 11 carpetas son el mismo set recoloreado, asi que
## el color se elige por significado y la forma se mantiene coherente.
##
## Los movimientos (resources/movimientos) buscan su icono por su propio nombre
## de archivo. Los que heredan el gesto de una habilidad heredan su pocion:
## Toque es Curar y Vendaje es Estabilizar. Oleada y Bendicion mantienen la
## silueta pero cambian de color, porque el turquesa ahora es el de Bendicion y
## una cura en area no puede compartirlo: pasan a burbujas doradas (las curas
## que alcanzan a varios) y a estrella turquesa.
const ICONOS := {
	"curar": [1, 1],          # frasco redondo rojo: la curacion de todos los dias
	"estabilizar": [6, 52],   # frasco gris con una banda cruzada, como un vendaje
	"bendicion": [2, 30],     # estrella turquesa: luz, proteccion
	"oleada": [7, 40],        # burbujas doradas: alcanza a varios
	"impulso": [7, 78],       # llama naranja en diagonal: velocidad
	"reanimar": [10, 81],     # rojo oscuro: levantar a alguien del suelo
	"toque": [1, 1],          # el frasco de Curar: la misma cura de todos los dias
	"vendaje": [6, 52],       # el de Estabilizar: la banda que ahora tambien cura
	"plegaria": [11, 28],     # aro crema, como una aureola: la cura que se reza
	"caida": [3, 39],         # flecha verde hacia abajo: la cura que cae del aire
}


func _initialize() -> void:
	var fallos := 0
	fallos += _extraer_hojas()
	fallos += _extraer_iconos()
	_escribir_atribucion()

	print("")
	if fallos > 0:
		print("FALLARON %d archivos" % fallos)
	else:
		print("TODO OK (correr --import antes de gen_ui.gd)")
	quit(1 if fallos > 0 else 0)


func _extraer_hojas() -> int:
	print("--- hojas de UI ---")
	var zip := ZIPReader.new()
	if zip.open(ProjectSettings.globalize_path(ZIP_UI)) != OK:
		push_error("no se pudo abrir %s" % ZIP_UI)
		return 1

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var fallos := 0
	for interna: String in HOJAS:
		if not _guardar_escalado(zip, interna, "%s/%s" % [DIR, HOJAS[interna]]):
			fallos += 1
	zip.close()
	return fallos


func _extraer_iconos() -> int:
	print("--- iconos de habilidad ---")
	var zip := ZIPReader.new()
	if zip.open(ProjectSettings.globalize_path(ZIP_POCIONES)) != OK:
		push_error("no se pudo abrir %s" % ZIP_POCIONES)
		return 1

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_ICONOS))
	var fallos := 0
	for nombre: String in ICONOS:
		var carpeta: int = ICONOS[nombre][0]
		var numero: int = ICONOS[nombre][1]
		# El pack numera con dos digitos hasta el 9 y sin relleno despues.
		var sufijo := "%02d" % numero if numero < 10 else str(numero)
		var interna := "Icons/%d/Icons_12_%d_%s.png" % [carpeta, carpeta, sufijo]
		if not _guardar_escalado(zip, interna, "%s/%s.png" % [DIR_ICONOS, nombre]):
			fallos += 1
	zip.close()
	return fallos


## Lee una imagen del zip, la agranda al doble sin suavizar y la guarda.
func _guardar_escalado(zip: ZIPReader, interna: String, destino: String) -> bool:
	var bytes := zip.read_file(interna)
	if bytes.is_empty():
		push_error("falta %s en el zip" % interna)
		return false

	var imagen := Image.new()
	if imagen.load_png_from_buffer(bytes) != OK:
		push_error("no se pudo leer %s" % interna)
		return false

	if ESQUINAS.has(interna):
		var datos: Array = ESQUINAS[interna]
		_tapar_boton_cerrar(imagen, datos[0], datos[1].x, datos[1].y)

	var antes := imagen.get_size()
	# NEAREST y no bilineal: cualquier interpolacion convierte el pixel art en
	# una mancha borrosa.
	imagen.resize(antes.x * ESCALA, antes.y * ESCALA, Image.INTERPOLATE_NEAREST)
	if imagen.save_png(ProjectSettings.globalize_path(destino)) != OK:
		push_error("no se pudo guardar %s" % destino)
		return false

	print("  %-26s %4dx%-4d -> %4dx%-4d" % [
		destino.get_file(), antes.x, antes.y, antes.x * ESCALA, antes.y * ESCALA])
	return true


## Copia la esquina superior izquierda del panel, espejada, sobre la derecha.
## El marco es simetrico, asi que el resultado es el mismo marco sin la X.
func _tapar_boton_cerrar(imagen: Image, origen: Vector2i, ancho_panel: int, lado: int) -> void:
	var esquina := imagen.get_region(Rect2i(origen, Vector2i(lado, lado)))
	esquina.flip_x()
	imagen.blit_rect(
		esquina,
		Rect2i(Vector2i.ZERO, esquina.get_size()),
		Vector2i(origen.x + ancho_panel - lado, origen.y))


func _escribir_atribucion() -> void:
	var texto := """# Assets de interfaz

Derivados de packs gratuitos de [CraftPix](https://craftpix.net/freebies/),
escalados al doble por `tools/extraer_ui.gd`. Los originales estan en
`assets/_raw/` y no se tocan.

- Interfaz: *Free Basic Pixel Art UI for RPG*
- Iconos de habilidad: *100 Potion Pixel Art Icons*

La licencia de los packs gratuitos esta en https://craftpix.net/file-licenses/ .
Permite usarlos dentro de un juego, incluso comercial, pero no redistribuirlos
como assets sueltos. **Conviene releerla antes de publicar.**

Estos archivos se generan: no editarlos a mano. Para cambiar que se extrae o
con que escala, tocar `tools/extraer_ui.gd` y volver a correrlo.
"""
	var archivo := FileAccess.open("%s/LEEME.md" % DIR, FileAccess.WRITE)
	if archivo == null:
		push_error("no se pudo escribir LEEME.md")
		return
	archivo.store_string(texto)
	archivo.close()
	print("  LEEME.md con la atribucion")
