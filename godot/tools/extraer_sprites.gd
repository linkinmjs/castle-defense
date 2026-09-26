extends SceneTree
## Saca de los packs de CraftPix las hojas de personajes y efectos que usa el
## juego y a las de personaje les hornea un contorno de 1 px del color de su
## bando.
##
## A los 11 m a los que mira la camara las figuras se amontonan en el frente y
## el maniqui celeste de los packs casi no se despega del suelo. Un pixel de
## color alrededor separa cada figura del fondo y de la vecina, y dice de que
## lado esta sin depender del tinte. Va horneado en la textura y no en un
## shader: cuesta cero en tiempo de ejecucion y no se pelea con el billboard,
## el alpha_cut ni la sombra que ya usan los AnimatedSprite3D.
##
## Los PNG que escribe este script NO se pueden cargar en la misma corrida. Hay
## que importar antes de generar los SpriteFrames:
##   godot --headless --path godot --script res://tools/extraer_sprites.gd
##   godot --headless --path godot --import
##   godot --headless --path godot --script res://tools/gen_frames.gd

const DIR := "res://assets/sprites"

const PACK_5 := "res://assets/_raw/craftpix-net-689963-pixel-prototype-medieval-character-sprites-pack-5.zip"
const PACK_6 := "res://assets/_raw/craftpix-net-852737-pixel-art-prototype-medieval-character-pack-6.zip"
const SABLE := "res://assets/_raw/craftpix-net-949015-prototype-saber-fighter-pixel-sprite-sheet.zip"
const ZOMBI := "res://assets/_raw/craftpix-net-834564-prototype-zombie-sprite-sheet-pixel-art-pack.zip"
const NIGROMANTE := "res://assets/_raw/craftpix-net-573981-free-necromancer-pixel-art-prototype-character-sprites.zip"
const PROTOTIPO := "res://assets/_raw/craftpix-net-405285-free-pixel-art-prototype-character-sprites.zip"
const HEROE := "res://assets/_raw/craftpix-net-196564-prototype-pixel-hero-free-sprite-pack-3.zip"
const MONSTRUOS := "res://assets/_raw/craftpix-987745-tiny-monsters-pixel-art-pack.zip"
const JEFES := "res://assets/_raw/craftpix-897123-boss-monsters-pixel-art.zip"
const MAGIA := "res://assets/_raw/craftpix-671189-10-magic-sprite-sheet-effects-pixel-art.zip"
const MAGIA_PROTOTIPO := "res://assets/_raw/craftpix-net-572720-magic-pixel-art-sprite-for-prototype.zip"
## El pack 572720 trae el zip de verdad adentro de otro zip. ZIPReader solo
## abre archivos del disco, asi que el de adentro se copia a user:// y se abre
## con un segundo lector. Se borra al terminar.
const MAGIA_PROTOTIPO_INTERNO := "Craftpix_Magic.zip"
const MAGIA_128 := "user://craftpix_572720_magic.zip"

## Nombre e id de cada pack, para la atribucion. En este orden sale en el LEEME.
const PACKS := [
	[PACK_5, "Pixel Prototype Medieval Character Sprites Pack 5", "689963"],
	[PACK_6, "Pixel Art Prototype Medieval Character Pack 6", "852737"],
	[SABLE, "Prototype Saber Fighter Pixel Sprite Sheet", "949015"],
	[ZOMBI, "Prototype Zombie Sprite Sheet Pixel Art Pack", "834564"],
	[NIGROMANTE, "Free Necromancer Pixel Art Prototype Character Sprites", "573981"],
	[PROTOTIPO, "Free Pixel Art Prototype Character Sprites", "405285"],
	[HEROE, "Prototype Pixel Hero Free Sprite Pack 3", "196564"],
	[MONSTRUOS, "Tiny Monsters Pixel Art Pack", "987745"],
	[JEFES, "Boss Monsters Pixel Art", "897123"],
	[MAGIA, "10 Magic Sprite Sheet Effects Pixel Art", "671189"],
	[MAGIA_128, "Magic Pixel Art Sprite for Prototype", "572720"],
]

## Colores de contorno. Aliados en azul y enemigos en rojo, como los tintes de
## Unidad3D; cada jugador con el suyo para distinguir a los dos healers.
const ALIADO := Color("#4a7fd4")
const ENEMIGO := Color("#c4553f")
const JUGADOR_1 := Color("#e8b84a")
const JUGADOR_2 := Color("#5fd3c7")

## Por debajo de este alfa un pixel cuenta como vacio y puede volverse contorno.
const ALFA_VACIO := 8
## Desde este alfa un pixel es parte de la figura y proyecta contorno. Los que
## quedan en el medio no se tocan; en las hojas que se usan hay uno solo.
const ALFA_OPACO := 128

# Hoja destino: [zip, hoja dentro del zip]. El destino es el nombre de la
# animacion que la usa, que es lo que gen_frames.gd y el codigo conocen.

## Las mismas seis hojas que usaban los combatientes antes del contorno: las de
## entonces eran copias exactas de estas (mismo MD5).
const SOLDIER := {
	"idle.png": [PACK_5, "Animations/Idle.png"],
	"walk.png": [PACK_5, "Animations/Walk.png"],
	"run.png": [PACK_5, "Animations/Run.png"],
	"attack.png": [PACK_5, "Animations/Attack_1.png"],
	"hurt.png": [PACK_5, "Animations/Hurt.png"],
	"dead.png": [PACK_5, "Animations/Dead.png"],
}

const LANCERO := {
	"idle.png": [PACK_6, "Animations/Idle.png"],
	"walk.png": [PACK_6, "Animations/Walk.png"],
	"run.png": [PACK_6, "Animations/Run.png"],
	"attack.png": [PACK_6, "Animations/Attack_1.png"],
	"hurt.png": [PACK_6, "Animations/Hurt.png"],
	"dead.png": [PACK_6, "Animations/Dead.png"],
}

const ESPADACHIN := {
	"idle.png": [SABLE, "Animations/Idle.png"],
	"walk.png": [SABLE, "Animations/Walk.png"],
	"run.png": [SABLE, "Animations/Run.png"],
	"attack.png": [SABLE, "Animations/Attack 1.png"],
	"hurt.png": [SABLE, "Animations/Hurt.png"],
	"dead.png": [SABLE, "Animations/Dead.png"],
}

const ENEMY := {
	"idle.png": [ZOMBI, "Animations/Idle.png"],
	"walk.png": [ZOMBI, "Animations/Walk.png"],
	"run.png": [ZOMBI, "Animations/Run.png"],
	"attack.png": [ZOMBI, "Animations/Attack 1.png"],
	"hurt.png": [ZOMBI, "Animations/Hurt.png"],
	"dead.png": [ZOMBI, "Animations/Dead.png"],
}

## El healer deja de usar las hojas del lancero. Los tres packs dibujan el
## mismo maniqui con la misma paleta, asi que se pueden mezclar. Ninguna hoja
## lleva armas: los packs 700501, 671351 y 607243 tienen armas de fuego y no se
## usan.
##
## El idle es el del nigromante: brazos abiertos con energia en las manos, de
## la familia del orbe de Healing. Es la silueta de alguien que lanza hechizos
## y no se confunde con la del lancero (brazos abajo y la lanza por encima de
## la cabeza). El Relaxed del pack 565335 tiene la paleta exacta pero es el
## lancero sin la lanza. La paleta del nigromante difiere en menos de 8 por
## canal: no se nota al pasar de idle a caminar.
##
## cast y healing son la misma hoja: cast es el nombre que ya usa el codigo y
## healing el que va a usar cuando cada habilidad tenga su animacion.
const HEALER := {
	"idle.png": [NIGROMANTE, "Animations/Idle.png"],
	"walk.png": [PROTOTIPO, "Animations/Walking.png"],
	"run.png": [PROTOTIPO, "Animations/Running.png"],
	"jump.png": [PROTOTIPO, "Animations/Jumping.png"],
	# Falling no es la bajada de un salto: es tropezar y caer de espaldas al
	# suelo. Sirve para cuando al healer lo tiran.
	"fall.png": [PROTOTIPO, "Animations/Falling.png"],
	"land.png": [PROTOTIPO, "Animations/Landing.png"],
	"hurt.png": [HEROE, "Animations/Taking_Damage.png"],
	"dead.png": [HEROE, "Animations/Death.png"],
	"cast.png": [HEROE, "Animations/Healing.png"],
	"healing.png": [HEROE, "Animations/Healing.png"],
	"power_boost.png": [HEROE, "Animations/Power_Boost.png"],
	# Levantarse del suelo por su cuenta, no revivir a otro.
	"resurrection.png": [HEROE, "Animations/Resurrection.png"],
	"magic_shield.png": [HEROE, "Animations/Magic_Shield.png"],
	"energy_wave.png": [HEROE, "Animations/Energy_Wave.png"],
	"aerial_strike.png": [HEROE, "Animations/Aerial_Strike.png"],
}

## El pack no trae carrera: gen_frames.gd usa la caminata mas rapida.
const BRUTO := {
	"idle.png": [MONSTRUOS, "1 Bear/Idle.png"],
	"walk.png": [MONSTRUOS, "1 Bear/Walk.png"],
	"attack.png": [MONSTRUOS, "1 Bear/Attack.png"],
	"hurt.png": [MONSTRUOS, "1 Bear/Hurt.png"],
	"dead.png": [MONSTRUOS, "1 Bear/Death.png"],
}

## El idle es el sneer en loop y no Demon_Boss.png: ese es un solo cuadro, el
## de reposo con que empiezan sneer, hurt y attack1, y quieto el jefe se ve
## congelado entre soldados que se mueven. En el sneer sube y baja los hombros
## y los cuadros 0 y 5 son el reposo, asi que el loop cierra sin salto.
const DEMONIO := {
	"idle.png": [JEFES, "2 Demon/Demon_Boss_sneer.png"],
	"walk.png": [JEFES, "2 Demon/Demon_Boss_walk.png"],
	"run.png": [JEFES, "2 Demon/Demon_Boss_run.png"],
	"attack.png": [JEFES, "2 Demon/Demon_Boss_attack1.png"],
	"attack2.png": [JEFES, "2 Demon/Demon_Boss_attack2.png"],
	"hurt.png": [JEFES, "2 Demon/Demon_Boss_hurt.png"],
	"dead.png": [JEFES, "2 Demon/Demon_Boss_death.png"],
	"sneer.png": [JEFES, "2 Demon/Demon_Boss_sneer.png"],
}

## Carpeta, contorno, espejar y hojas. Los monstruos de 987745 y 897123 vienen
## mirando a la izquierda. Las demas hojas miran a la derecha y el codigo cuenta
## con eso (flip_h = true es mirar a la izquierda), asi que se espejan cuadro
## por cuadro.
const PERSONAJES := [
	["soldier", ALIADO, false, SOLDIER],
	["lancero", ALIADO, false, LANCERO],
	["espadachin", ALIADO, false, ESPADACHIN],
	["enemy", ENEMIGO, false, ENEMY],
	["healer", JUGADOR_1, false, HEALER],
	["healer2", JUGADOR_2, false, HEALER],
	["bruto", ENEMIGO, true, BRUTO],
	["demonio", ENEMIGO, true, DEMONIO],
]

## Los efectos no llevan contorno: son luz, no cuerpos, y un borde de color los
## volveria calcomanias. Se copian byte a byte. Lado esperado de cada hoja: los
## de 671189 son de 72 px y los de 572720 de 128.
const EFECTOS := {
	"heal.png": [MAGIA, "4 Sun strike/Sun-strike.png", 72],
	"shield.png": [MAGIA, "8 Shield/Shield.png", 72],
	"toque.png": [MAGIA, "3 Midas touch/Midas-touch.png", 72],
	"plegaria.png": [MAGIA, "4 Sun strike/Sun-strike.png", 72],
	"bendicion.png": [MAGIA, "8 Shield/Shield.png", 72],
	"oleada.png": [MAGIA, "5 Explosion/Explosion.png", 72],
	"impulso.png": [MAGIA, "2 Lightning bolt/Lightning-bolt.png", 72],
	"caida.png": [MAGIA_128, "Lightning/Lightning Ring.png", 128],
	"reanimar.png": [MAGIA_128, "Fire/Pillar of fire.png", 128],
}

var _zips: Dictionary[String, ZIPReader] = {}


func _initialize() -> void:
	var fallos := 0
	if not _desanidar(MAGIA_PROTOTIPO, MAGIA_PROTOTIPO_INTERNO, MAGIA_128):
		fallos += 1
	for datos: Array in PERSONAJES:
		fallos += _extraer_personaje(datos[0], datos[1], datos[2], datos[3])
	fallos += _extraer_efectos()
	if not _escribir_atribucion():
		fallos += 1

	for zip: ZIPReader in _zips.values():
		zip.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAGIA_128))

	print("")
	if fallos > 0:
		print("FALLARON %d archivos" % fallos)
	else:
		print("TODO OK (correr --import antes de gen_frames.gd)")
	quit(1 if fallos > 0 else 0)


func _extraer_personaje(carpeta: String, contorno: Color, espejar: bool, hojas: Dictionary) -> int:
	print("--- %s ---" % carpeta)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [DIR, carpeta]))
	var fallos := 0
	for destino: String in hojas:
		var origen: Array = hojas[destino]
		var bytes := _leer(origen[0], origen[1])
		if bytes.is_empty():
			fallos += 1
			continue
		var hoja := _hornear(bytes, contorno, espejar)
		if hoja == null:
			push_error("%s no es una tira de cuadros cuadrados" % origen[1])
			fallos += 1
			continue
		var ruta := "%s/%s/%s" % [DIR, carpeta, destino]
		if hoja.save_png(ProjectSettings.globalize_path(ruta)) != OK:
			push_error("no se pudo guardar %s" % ruta)
			fallos += 1
			continue
		print("  %-18s %2d x %-3d <- %s" % [
			destino, _cuadros(hoja, hoja.get_height()), hoja.get_height(), origen[1]])
	return fallos


func _extraer_efectos() -> int:
	print("--- fx ---")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/fx" % DIR))
	var fallos := 0
	for destino: String in EFECTOS:
		var origen: Array = EFECTOS[destino]
		var bytes := _leer(origen[0], origen[1])
		if bytes.is_empty():
			fallos += 1
			continue
		# Se decodifica solo para comprobar que es la hoja esperada; lo que se
		# guarda son los bytes del pack, asi heal y shield quedan identicos a
		# los de antes y el archivo no depende del codificador de Godot.
		var imagen := Image.new()
		var lado: int = origen[2]
		if imagen.load_png_from_buffer(bytes) != OK \
				or imagen.get_height() != lado or imagen.get_width() % lado != 0:
			push_error("%s no es una tira de cuadros de %d px" % [origen[1], lado])
			fallos += 1
			continue
		var ruta := "%s/fx/%s" % [DIR, destino]
		var archivo := FileAccess.open(ruta, FileAccess.WRITE)
		if archivo == null or not archivo.store_buffer(bytes):
			push_error("no se pudo guardar %s" % ruta)
			fallos += 1
			continue
		archivo.close()
		print("  %-18s %2d x %-3d <- %s" % [destino, _cuadros(imagen, lado), lado, origen[1]])
	return fallos


## Copia a disco el zip que viene adentro de otro zip.
func _desanidar(zip_externo: String, interno: String, destino: String) -> bool:
	var bytes := _leer(zip_externo, interno)
	if bytes.is_empty():
		return false
	var archivo := FileAccess.open(destino, FileAccess.WRITE)
	if archivo == null or not archivo.store_buffer(bytes):
		push_error("no se pudo copiar %s a %s" % [interno, destino])
		return false
	archivo.close()
	return true


## Lee un archivo de un zip. Devuelve vacio, y avisa, si no esta.
func _leer(ruta_zip: String, interna: String) -> PackedByteArray:
	var zip := _abrir(ruta_zip)
	if zip == null:
		return PackedByteArray()
	if not zip.file_exists(interna):
		push_error("falta %s en %s" % [interna, ruta_zip.get_file()])
		return PackedByteArray()
	return zip.read_file(interna)


## Cada zip se abre una sola vez: el healer lee quince hojas de tres packs.
func _abrir(ruta_zip: String) -> ZIPReader:
	if _zips.has(ruta_zip):
		return _zips[ruta_zip]
	var zip := ZIPReader.new()
	if zip.open(ProjectSettings.globalize_path(ruta_zip)) != OK:
		push_error("no se pudo abrir %s" % ruta_zip)
		return null
	_zips[ruta_zip] = zip
	return zip


## Decodifica una tira de cuadros cuadrados y le hornea el contorno cuadro por
## cuadro. Devuelve null si la hoja no es una tira de cuadros cuadrados.
func _hornear(bytes: PackedByteArray, contorno: Color, espejar: bool) -> Image:
	var hoja := Image.new()
	if hoja.load_png_from_buffer(bytes) != OK:
		return null
	# Los packs de monstruos vienen con paleta: se pasa todo a RGBA8 para leer
	# el alfa de cada pixel en el mismo lugar.
	hoja.convert(Image.FORMAT_RGBA8)
	var lado := hoja.get_height()
	if lado == 0 or hoja.get_width() % lado != 0:
		return null

	var salida := Image.create_empty(hoja.get_width(), lado, false, Image.FORMAT_RGBA8)
	for i in _cuadros(hoja, lado):
		# Cada cuadro por separado: el contorno de un cuadro no puede asomar en
		# el vecino, que en el juego se ve en otro momento de la animacion.
		var cuadro := hoja.get_region(Rect2i(i * lado, 0, lado, lado))
		if espejar:
			cuadro.flip_x()
		_contornear(cuadro, contorno)
		salida.blit_rect(cuadro, Rect2i(Vector2i.ZERO, cuadro.get_size()), Vector2i(i * lado, 0))
	return salida


## Pinta del color de contorno cada pixel vacio que toca, en 8-vecindad, un
## pixel de la figura. Lo demas queda como estaba.
##
## Se lee de la copia original y se escribe en otra: si el contorno recien
## pintado contara como figura, creceria un pixel por cada pixel que se pinta.
## Donde la figura toca el borde del cuadro no hay lugar y queda sin contorno.
func _contornear(cuadro: Image, color: Color) -> void:
	var usado := cuadro.get_used_rect()
	if not usado.has_area():
		return
	var ancho := cuadro.get_width()
	var alto := cuadro.get_height()
	# El contorno cae a lo sumo a un pixel de lo dibujado: no hace falta
	# recorrer el cuadro entero, que en la mayoria esta vacio.
	var zona := usado.grow(1).intersection(Rect2i(0, 0, ancho, alto))
	var original := cuadro.get_data()
	var datos := original.duplicate()
	for y in range(zona.position.y, zona.end.y):
		for x in range(zona.position.x, zona.end.x):
			var i := (y * ancho + x) * 4
			if original[i + 3] >= ALFA_VACIO or not _toca_figura(original, ancho, alto, x, y):
				continue
			datos[i] = color.r8
			datos[i + 1] = color.g8
			datos[i + 2] = color.b8
			datos[i + 3] = 255
	cuadro.set_data(ancho, alto, false, Image.FORMAT_RGBA8, datos)


## Cuantos cuadros de lado x lado entran a lo ancho de la hoja.
func _cuadros(hoja: Image, lado: int) -> int:
	return int(hoja.get_width() / float(lado))


## El propio pixel entra en el recorrido, pero solo se pregunta por vacios, que
## nunca llegan a ALFA_OPACO: es lo mismo que mirar los ocho vecinos.
func _toca_figura(datos: PackedByteArray, ancho: int, alto: int, x: int, y: int) -> bool:
	for vy in range(maxi(y - 1, 0), mini(y + 2, alto)):
		for vx in range(maxi(x - 1, 0), mini(x + 2, ancho)):
			if datos[(vy * ancho + vx) * 4 + 3] >= ALFA_OPACO:
				return true
	return false


func _escribir_atribucion() -> bool:
	var filas := ""
	for pack: Array in PACKS:
		filas += "| %s | %s | %s |\n" % [pack[1], pack[2], _usos(pack[0])]

	var texto := """# Sprites de personajes y efectos

Derivados de packs gratuitos de [CraftPix](https://craftpix.net/freebies/) por
`tools/extraer_sprites.gd`. Los originales estan en `assets/_raw/` y no se tocan.

A las hojas de personaje se les hornea un contorno de 1 px del color de su lado
(aliados azul, enemigos rojo, jugador 1 dorado, jugador 2 turquesa). Las de
`bruto/` y `demonio/` ademas se espejan cuadro por cuadro para que miren a la
derecha, como el resto. Los efectos de `fx/` se copian tal cual.

| Pack | Id | Hojas |
|---|---|---|
%s
La licencia de los packs gratuitos esta en https://craftpix.net/file-licenses/ .
Permite usarlos dentro de un juego, incluso comercial, pero no redistribuirlos
como assets sueltos. **Conviene releerla antes de publicar.**

Estos archivos se generan: no editarlos a mano. Para cambiar que se extrae o de
que color es el contorno, tocar `tools/extraer_sprites.gd`, volver a correrlo,
importar y correr `tools/gen_frames.gd`.
""" % filas
	var archivo := FileAccess.open("%s/LEEME.md" % DIR, FileAccess.WRITE)
	if archivo == null or not archivo.store_string(texto):
		push_error("no se pudo escribir LEEME.md")
		return false
	archivo.close()
	print("  LEEME.md con la atribucion")
	return true


## Que hojas salen de un pack, agrupadas por carpeta: "healer/ (idle), ...".
func _usos(ruta_zip: String) -> String:
	var tablas: Array = []
	for datos: Array in PERSONAJES:
		tablas.append([datos[0], datos[3]])
	tablas.append(["fx", EFECTOS])

	var partes: PackedStringArray = []
	for tabla: Array in tablas:
		var hojas: PackedStringArray = []
		for destino: String in tabla[1]:
			if tabla[1][destino][0] == ruta_zip:
				hojas.append(destino.get_basename())
		if not hojas.is_empty():
			partes.append("`%s/` (%s)" % [tabla[0], ", ".join(hojas)])
	return ", ".join(partes)
