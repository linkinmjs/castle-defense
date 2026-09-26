extends Control
## Pantalla de inicio.
##
## Es la escena principal del proyecto, asi que tambien es donde se aplican las
## preferencias guardadas: es lo primero que corre al abrir el juego.

## Se emite ademas de cambiar de escena, para poder probar el boton sin que la
## prueba termine cargando la batalla entera.
signal jugar_pedido(indice: int)

const RUTA_CAMPANA := "res://resources/encuentros/campana.tres"

@onready var _botonera: Control = %Botonera
@onready var _lecciones: Control = %Lecciones
@onready var _opciones: Control = %Opciones


func _ready() -> void:
	Opciones.cargar()
	Opciones.aplicar()

	%Jugar.pressed.connect(jugar.bind(0))
	%Jugadores.pressed.connect(_alternar_jugadores)
	_mostrar_jugadores()
	%Lecciones_boton.pressed.connect(_mostrar_lecciones)
	%Opciones_boton.pressed.connect(_mostrar_opciones)
	%Salir.pressed.connect(func() -> void: Navegacion.salir(get_tree()))
	%VolverLecciones.pressed.connect(_mostrar_botonera)
	_opciones.cerrado.connect(_mostrar_botonera)

	# En el navegador no se puede cerrar la pestania desde el juego.
	%Salir.visible = not Navegacion.en_web()

	_armar_lecciones()
	_mostrar_botonera()
	%Jugar.grab_focus()


func jugar(indice: int) -> void:
	jugar_pedido.emit(indice)
	Navegacion.jugar(get_tree(), indice)


## Uno o dos: cada toque pasa al otro. Queda anotado en el arbol, que es de
## donde lo lee la batalla al armarse (ver Jugadores).
func _alternar_jugadores() -> void:
	var cantidad := Jugadores.cantidad_pedida(get_tree()) % Jugadores.MAXIMO + 1
	Jugadores.pedir_cantidad(get_tree(), cantidad)
	_mostrar_jugadores()


## Lo que dice el boton sale de lo anotado, no de un contador propio: al volver
## de una partida de a dos, el menu arranca diciendo 2.
func _mostrar_jugadores() -> void:
	%Jugadores.text = "Jugadores: %d" % Jugadores.cantidad_pedida(get_tree())


## Una fila por encuentro, con su titulo y lo que enseña. Los textos ya estan
## escritos en los recursos de la campaña: no hay que inventar ninguno.
func _armar_lecciones() -> void:
	var lista: Control = %ListaLecciones
	for hijo in lista.get_children():
		hijo.queue_free()

	if not ResourceLoader.exists(RUTA_CAMPANA):
		return
	var campana: Campana = load(RUTA_CAMPANA)

	for i in campana.encuentros.size():
		var encuentro: Encuentro = campana.encuentros[i]
		if encuentro == null:
			continue

		var fila := VBoxContainer.new()
		fila.add_theme_constant_override("separation", 2)

		var boton := Button.new()
		boton.text = "%d. %s" % [i + 1, encuentro.titulo]
		boton.pressed.connect(jugar.bind(i))
		fila.add_child(boton)

		var pie := Label.new()
		pie.text = encuentro.objetivo_pedagogico
		pie.theme_type_variation = &"Chico"
		pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pie.custom_minimum_size.x = 360
		fila.add_child(pie)

		lista.add_child(fila)


func _mostrar_botonera() -> void:
	_botonera.visible = true
	_lecciones.visible = false
	_opciones.visible = false
	%Jugar.grab_focus()


func _mostrar_lecciones() -> void:
	_botonera.visible = false
	_lecciones.visible = true
	%VolverLecciones.grab_focus()


func _mostrar_opciones() -> void:
	_botonera.visible = false
	_opciones.abrir()
