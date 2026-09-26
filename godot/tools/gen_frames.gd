extends SceneTree
## Genera los recursos SpriteFrames a partir de las hojas de assets/sprites/.
## Cada hoja es una tira horizontal de cuadros cuadrados.
##
## El lado del cuadro es el alto de la hoja y no una constante por carpeta: fx
## mezcla efectos de 72 px con otros de 128, y el bruto y el demonio no miden
## lo mismo que los humanos.
##
## Las hojas las escribe tools/extraer_sprites.gd; hay que importarlas antes de
## correr este script.

# animacion: [archivo, fps, loop, (desde, hasta) opcional]

## healer y healer2 usan esta misma tabla: son las mismas hojas con otro color
## de contorno.
const HEALER := {
	"idle": ["idle.png", 8.0, true],
	"walk": ["walk.png", 10.0, true],
	"run": ["run.png", 12.0, true],
	# La hoja trae cinco cuadros de agachada antes de despegar y dos de
	# aterrizaje. El salto fisico arranca al apretar, asi que se usa desde el
	# impulso (5) hasta la pose de llegada (8), que queda puesta hasta tocar el
	# suelo: los cuatro cuadros duran 0.5 s y el arco del salto, 0.63.
	"jump": ["jump.png", 8.0, false, 5, 8],
	# Tropezar y caer de espaldas, no la bajada de un salto.
	"fall": ["fall.png", 12.0, false],
	"land": ["land.png", 14.0, false],
	# Tres cuadros a 12 fps: los 0.25 s que dura el golpe en Healer3D.
	"hurt": ["hurt.png", 12.0, false],
	"dead": ["dead.png", 10.0, false],
	# cast es el nombre que usa hoy el codigo; healing es la misma hoja con el
	# nombre que va a tener cuando cada habilidad use su animacion.
	"cast": ["cast.png", 14.0, false],
	"healing": ["healing.png", 14.0, false],
	"power_boost": ["power_boost.png", 12.0, false],
	# Levantarse del suelo: la vuelta de fall o de dead.
	"resurrection": ["resurrection.png", 10.0, false],
	"magic_shield": ["magic_shield.png", 14.0, false],
	"energy_wave": ["energy_wave.png", 14.0, false],
	"aerial_strike": ["aerial_strike.png", 14.0, false],
}

const COMBATIENTE := {
	"idle": ["idle.png", 8.0, true],
	"walk": ["walk.png", 10.0, true],
	"run": ["run.png", 12.0, true],
	"attack": ["attack.png", 11.0, false],
	"hurt": ["hurt.png", 14.0, false],
	"dead": ["dead.png", 10.0, false],
}

## El oso de 40 px. El pack no trae carrera: run es la misma caminata mas
## rapida, para que el codigo pueda pedir "run" como a cualquier soldado.
const BRUTO := {
	"idle": ["idle.png", 8.0, true],
	"walk": ["walk.png", 10.0, true],
	"run": ["walk.png", 14.0, true],
	"attack": ["attack.png", 12.0, false],
	"hurt": ["hurt.png", 12.0, false],
	"dead": ["dead.png", 10.0, false],
}

## El jefe de 96 px, un poco mas lento que el resto para que pese. El idle es
## el sneer en loop; sneer suelto es la burla, una sola vez.
const DEMONIO := {
	"idle": ["idle.png", 6.0, true],
	"walk": ["walk.png", 8.0, true],
	"run": ["run.png", 10.0, true],
	"attack": ["attack.png", 10.0, false],
	"attack2": ["attack2.png", 11.0, false],
	"hurt": ["hurt.png", 12.0, false],
	"dead": ["dead.png", 8.0, false],
	"sneer": ["sneer.png", 8.0, false],
}

## Los primeros siete son de 72 px; caida y reanimar, de 128.
const EFECTOS := {
	"heal": ["heal.png", 18.0, false],
	"shield": ["shield.png", 16.0, false],
	"toque": ["toque.png", 14.0, false],
	"plegaria": ["plegaria.png", 16.0, false],
	"bendicion": ["bendicion.png", 16.0, false],
	"oleada": ["oleada.png", 16.0, false],
	"impulso": ["impulso.png", 18.0, false],
	"caida": ["caida.png", 14.0, false],
	"reanimar": ["reanimar.png", 14.0, false],
}


func _initialize() -> void:
	var fallos := 0
	fallos += _generar("res://assets/sprites/healer", HEALER, "healer_frames.tres")
	fallos += _generar("res://assets/sprites/healer2", HEALER, "healer2_frames.tres")
	fallos += _generar("res://assets/sprites/soldier", COMBATIENTE, "soldier_frames.tres")
	fallos += _generar("res://assets/sprites/enemy", COMBATIENTE, "enemy_frames.tres")
	fallos += _generar("res://assets/sprites/lancero", COMBATIENTE, "lancero_frames.tres")
	fallos += _generar("res://assets/sprites/espadachin", COMBATIENTE, "espadachin_frames.tres")
	fallos += _generar("res://assets/sprites/bruto", BRUTO, "bruto_frames.tres")
	fallos += _generar("res://assets/sprites/demonio", DEMONIO, "demonio_frames.tres")
	fallos += _generar("res://assets/sprites/fx", EFECTOS, "fx_frames.tres")
	quit(1 if fallos > 0 else 0)


func _generar(carpeta: String, animaciones: Dictionary, salida: String) -> int:
	var fallos := 0
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	for nombre: String in animaciones:
		var datos: Array = animaciones[nombre]
		var ruta := "%s/%s" % [carpeta, datos[0]]
		var textura: Texture2D = load(ruta)
		if textura == null:
			push_error("No se pudo cargar %s" % ruta)
			fallos += 1
			continue

		var lado := textura.get_height()
		if lado == 0 or textura.get_width() % lado != 0:
			push_error("%s no es una tira de cuadros cuadrados" % ruta)
			fallos += 1
			continue

		var cantidad := int(textura.get_width() / float(lado))
		var desde := 0
		var hasta := cantidad - 1
		if datos.size() >= 5:
			desde = clampi(datos[3], 0, cantidad - 1)
			hasta = clampi(datos[4], desde, cantidad - 1)

		frames.add_animation(nombre)
		frames.set_animation_speed(nombre, datos[1])
		frames.set_animation_loop(nombre, datos[2])

		for i in range(desde, hasta + 1):
			var atlas := AtlasTexture.new()
			atlas.atlas = textura
			atlas.region = Rect2(i * lado, 0, lado, lado)
			frames.add_frame(nombre, atlas)

		print("  %-14s %2d frames de %d px" % [nombre, hasta - desde + 1, lado])

	var destino := "%s/%s" % [carpeta, salida]
	var err := ResourceSaver.save(frames, destino)
	if err != OK:
		fallos += 1
	print("%s -> %s" % [destino, "OK" if err == OK else "ERROR %d" % err])
	return fallos
