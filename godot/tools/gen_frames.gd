extends SceneTree
## Genera los recursos SpriteFrames a partir de los spritesheets de CraftPix.
## Cada sheet es una tira horizontal de frames cuadrados.

const PERSONAJE := 128
const EFECTO := 72

# animacion: [archivo, fps, loop, (desde, hasta) opcional, indices de frame]
const HEALER := {
	"idle": ["idle.png", 8.0, true],
	"walk": ["walk.png", 10.0, true],
	"run": ["run.png", 12.0, true],
	"cast": ["cast.png", 12.0, false],
	"hurt": ["hurt.png", 12.0, false],
	"dead": ["dead.png", 10.0, false],
	# El sheet trae agachada y aterrizaje; para un salto fisico se usa solo
	# el tramo en el aire, que dura lo que el cuerpo tarda en subir y bajar.
	"jump": ["jump.png", 16.0, false, 5, 14],
}

const COMBATIENTE := {
	"idle": ["idle.png", 8.0, true],
	"walk": ["walk.png", 10.0, true],
	"run": ["run.png", 12.0, true],
	"attack": ["attack.png", 11.0, false],
	"hurt": ["hurt.png", 14.0, false],
	"dead": ["dead.png", 10.0, false],
}


const EFECTOS := {
	"heal": ["heal.png", 18.0, false],
	"shield": ["shield.png", 16.0, false],
}


func _initialize() -> void:
	_generar("res://assets/sprites/healer", HEALER, PERSONAJE, "healer_frames.tres")
	_generar("res://assets/sprites/soldier", COMBATIENTE, PERSONAJE, "soldier_frames.tres")
	_generar("res://assets/sprites/enemy", COMBATIENTE, PERSONAJE, "enemy_frames.tres")
	_generar("res://assets/sprites/fx", EFECTOS, EFECTO, "fx_frames.tres")
	quit()


func _generar(carpeta: String, animaciones: Dictionary, lado: int, salida: String) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	for nombre: String in animaciones:
		var datos: Array = animaciones[nombre]
		var ruta := "%s/%s" % [carpeta, datos[0]]
		var textura: Texture2D = load(ruta)
		if textura == null:
			push_error("No se pudo cargar %s" % ruta)
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

		print("  %-6s %2d frames" % [nombre, hasta - desde + 1])

	var destino := "%s/%s" % [carpeta, salida]
	var err := ResourceSaver.save(frames, destino)
	print("%s -> %s" % [destino, "OK" if err == OK else "ERROR %d" % err])
