class_name Opciones
extends RefCounted
## Preferencias de pantalla, guardadas entre sesiones.
##
## Estado estatico y no un autoload: son dos valores y un archivo. El precedente
## del proyecto es evitar singletons salvo que haga falta ciclo de vida propio.
##
## Todo lo que toca DisplayServer se cortocircuita en headless, asi que ninguna
## prueba mueve la ventana aunque llame a aplicar() sin querer.

const RUTA := "user://opciones.cfg"
const SECCION := "pantalla"

## En ventana; en pantalla completa manda la del monitor.
const RESOLUCIONES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

static var pantalla_completa: bool = false
static var indice_resolucion: int = 0


static func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) != OK:
		return  # primera vez: quedan los valores por defecto
	pantalla_completa = cfg.get_value(SECCION, "pantalla_completa", false)
	poner_resolucion(cfg.get_value(SECCION, "resolucion", 0))


static func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECCION, "pantalla_completa", pantalla_completa)
	cfg.set_value(SECCION, "resolucion", indice_resolucion)
	cfg.save(RUTA)


## Lleva la ventana al estado guardado.
static func aplicar() -> void:
	if not hay_pantalla():
		return

	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if pantalla_completa
		else DisplayServer.WINDOW_MODE_WINDOWED)

	if pantalla_completa or not hay_ventana():
		return

	var medida := RESOLUCIONES[indice_resolucion]
	DisplayServer.window_set_size(medida)
	# Recentrar: al achicar desde una resolucion mayor la ventana queda corrida
	# y puede terminar con la barra de titulo fuera de la pantalla.
	var pantalla := DisplayServer.screen_get_size()
	DisplayServer.window_set_position((pantalla - medida) / 2)


static func poner_pantalla_completa(valor: bool) -> void:
	pantalla_completa = valor
	aplicar()
	guardar()


static func poner_resolucion(indice: int) -> void:
	indice_resolucion = clampi(indice, 0, RESOLUCIONES.size() - 1)


## Cambia de resolucion en circulo y devuelve la nueva.
static func rotar_resolucion(paso: int) -> Vector2i:
	var total := RESOLUCIONES.size()
	poner_resolucion(posmod(indice_resolucion + paso, total))
	aplicar()
	guardar()
	return RESOLUCIONES[indice_resolucion]


static func etiqueta_resolucion() -> String:
	var r := RESOLUCIONES[indice_resolucion]
	return "%d x %d" % [r.x, r.y]


## Hay algo que mover: en headless no existe la ventana.
static func hay_pantalla() -> bool:
	return DisplayServer.get_name() != "headless"


## En web el tamanio del canvas lo decide la pagina, asi que elegir resolucion
## no tiene sentido y la fila se oculta en vez de mostrarse rota.
static func hay_ventana() -> bool:
	return hay_pantalla() and not OS.has_feature("web")
