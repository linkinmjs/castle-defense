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
