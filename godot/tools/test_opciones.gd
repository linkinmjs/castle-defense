extends SceneTree
## Preferencias de pantalla: que se guarden, que vuelvan y que no rompan nada
## cuando no hay ventana.

var _fallos := 0


func _initialize() -> void:
	# Se arranca de cero para no depender de lo que haya dejado una corrida
	# anterior ni del archivo real del usuario.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Opciones.RUTA))
	Opciones.pantalla_completa = false
	Opciones.indice_resolucion = 0

	print("--- ida y vuelta por el archivo ---")
	Opciones.pantalla_completa = true
	Opciones.indice_resolucion = 2
	Opciones.guardar()
	_ok("se escribio el archivo", FileAccess.file_exists(Opciones.RUTA))

	Opciones.pantalla_completa = false
	Opciones.indice_resolucion = 0
	Opciones.cargar()
	_ok("vuelve la pantalla completa", Opciones.pantalla_completa)
	_igual("y la resolucion", Opciones.indice_resolucion, 2)

	print("--- sin archivo quedan los valores por defecto ---")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Opciones.RUTA))
	Opciones.pantalla_completa = false
	Opciones.indice_resolucion = 1
	Opciones.cargar()
	_igual("no pisa lo que habia", Opciones.indice_resolucion, 1)

	print("--- la resolucion no se sale de la lista ---")
	Opciones.poner_resolucion(99)
	_igual("por arriba queda en la ultima",
		Opciones.indice_resolucion, Opciones.RESOLUCIONES.size() - 1)
	Opciones.poner_resolucion(-5)
	_igual("y por abajo en la primera", Opciones.indice_resolucion, 0)

	print("--- rotar da la vuelta ---")
	Opciones.poner_resolucion(0)
	Opciones.rotar_resolucion(-1)
	_igual("hacia atras desde la primera va a la ultima",
		Opciones.indice_resolucion, Opciones.RESOLUCIONES.size() - 1)
	Opciones.rotar_resolucion(1)
	_igual("y hacia adelante vuelve a la primera", Opciones.indice_resolucion, 0)

	print("--- la etiqueta dice la medida ---")
	_ok("con el formato esperado (%s)" % Opciones.etiqueta_resolucion(),
		Opciones.etiqueta_resolucion() == "1280 x 720")

	print("--- sin ventana no se toca nada ---")
	_ok("headless se reconoce", not Opciones.hay_pantalla())
	# Si aplicar() moviera la ventana en headless, esto reventaria.
	Opciones.aplicar()
	Opciones.poner_pantalla_completa(true)
	_ok("aplicar no rompe sin pantalla", true)
	_ok("y hay_ventana tambien es false", not Opciones.hay_ventana())

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Opciones.RUTA))

	print("")
	print("TODO OK" if _fallos == 0 else "FALLARON %d comprobaciones" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _ok(que: String, condicion: bool) -> void:
	if not condicion:
		_fallos += 1
	print("  [%s] %s" % ["OK" if condicion else "FALLA", que])


func _igual(que: String, obtenido: int, esperado: int) -> void:
	var ok := obtenido == esperado
	if not ok:
		_fallos += 1
	print("  [%s] %-46s obtenido=%d esperado=%d" % [
		"OK" if ok else "FALLA", que, obtenido, esperado])
