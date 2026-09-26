extends Control
## Pantalla de inicio.
##
## Es la escena principal del proyecto, asi que tambien es donde se aplican las
## preferencias guardadas: es lo primero que corre al abrir el juego.
##
## Detras del panel va el atardecer del campo de batalla, vivo: las capas se
## corren a distinta velocidad, las lejanas mas despacio, como si la camara
## anduviera de costado. Es el mismo arte del campo, asi el menu ya dice donde
## se va a jugar.

## Se emite ademas de cambiar de escena, para poder probar el boton sin que la
## prueba termine cargando la batalla entera.
signal jugar_pedido(indice: int)

## Pixeles de pantalla por segundo de cada capa. Muy despacio: es un fondo, no
## una persecucion, y las lejanas casi no se mueven.
const VELOCIDADES: Dictionary[StringName, float] = {
	&"Montanas": 3.0,
	&"Castillo": 6.0,
	&"Arboles": 12.0,
}
## Los renglones de la tabla de controles: el nombre y la clave en
## Jugadores.etiquetas().
const CONTROLES: Array[Array] = [
	["Mover", "mover"],
	["Ligera", "ligera"],
	["Pesada", "pesada"],
	["Saltar", "saltar"],
]
const PIE_CONTROLES := "Pausa: Esc / Start · Al terminar: R / Back repite, Enter / Start sigue"

@onready var _botonera: Control = %Botonera
@onready var _lecciones: Control = %Lecciones
@onready var _controles: Control = %Controles
@onready var _opciones: Control = %Opciones
## Las capas que se corren, con su velocidad.
@onready var _capas: Array[TextureRect] = [%Montanas, %Castillo, %Arboles]

## Segundos desde que se abrio el menu: de aca sale cuanto se corrio cada capa.
var _tiempo: float = 0.0


func _ready() -> void:
	Opciones.cargar()
	Opciones.aplicar()

	%Jugar.pressed.connect(jugar.bind(0, Navegacion.RUTA_NIVELES))
	%Jugadores.pressed.connect(_alternar_jugadores)
	_mostrar_jugadores()
	%Lecciones_boton.pressed.connect(_mostrar_lecciones)
	%Controles_boton.pressed.connect(_mostrar_controles)
	%Opciones_boton.pressed.connect(_mostrar_opciones)
	%Salir.pressed.connect(func() -> void: Navegacion.salir(get_tree()))
	%VolverLecciones.pressed.connect(_mostrar_botonera)
	%VolverControles.pressed.connect(_mostrar_botonera)
	_opciones.cerrado.connect(_mostrar_botonera)

	# En el navegador no se puede cerrar la pestania desde el juego.
	%Salir.visible = not Navegacion.en_web()

	_armar_lecciones()
	_armar_controles()
	_mostrar_botonera()
	%Jugar.grab_focus()


## El parallax. Cada capa se corre a su velocidad y vuelve a empezar al
## completar una repeticion de su hoja, que empalma en X: no se nota el salto.
## El corrimiento va en pixeles enteros, o los pixeles de la hoja saldrian de
## uno y de dos de ancho segun el cuadro.
func _process(delta: float) -> void:
	_tiempo += delta
	for capa in _capas:
		var ancho := float(capa.texture.get_width())
		var periodo := ancho * capa.scale.x
		var corrimiento := floorf(fposmod(_tiempo * VELOCIDADES.get(capa.name, 0.0), periodo))
		capa.offset_left = -corrimiento
		capa.offset_right = ancho - corrimiento


## "Jugar" arranca los niveles; cada leccion, la serie de lecciones. La ruta va
## siempre explicita: sin ella Navegacion deja la serie que ya estaba anotada,
## y volver de los niveles a una leccion terminaria en un nivel.
func jugar(indice: int, ruta_campana: String = Navegacion.RUTA_LECCIONES) -> void:
	jugar_pedido.emit(indice)
	Navegacion.jugar(get_tree(), indice, ruta_campana)


## Cuanto se corrio esa capa, en pixeles de pantalla. Para las pruebas.
func corrimiento_capa(nombre: StringName) -> float:
	for capa in _capas:
		if capa.name == nombre:
			return -capa.offset_left
	return 0.0


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

	if not ResourceLoader.exists(Navegacion.RUTA_LECCIONES):
		return
	var campana: Campana = load(Navegacion.RUTA_LECCIONES)

	for i in campana.encuentros.size():
		var encuentro: Encuentro = campana.encuentros[i]
		if encuentro == null:
			continue

		var fila := VBoxContainer.new()
		fila.add_theme_constant_override("separation", 4)

		var boton := Button.new()
		boton.text = "%d. %s" % [i + 1, encuentro.titulo]
		boton.pressed.connect(jugar.bind(i))
		fila.add_child(boton)

		var pie := Label.new()
		pie.text = encuentro.objetivo_pedagogico
		# Sobre la madera clara el texto va oscuro: el chico del HUD es claro.
		pie.theme_type_variation = &"ChicoPanel"
		pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pie.custom_minimum_size.x = 360
		fila.add_child(pie)

		lista.add_child(fila)


## La tabla de controles: una columna por jugador, con el nombre del color de
## su marca (oscurecido, que va sobre la madera), y un renglon por accion.
## Sale de Jugadores.etiquetas(), igual que la leyenda del HUD.
func _armar_controles() -> void:
	var tabla: GridContainer = %TablaControles
	for hijo in tabla.get_children():
		hijo.queue_free()

	tabla.add_child(_celda(""))
	for jugador in range(1, Jugadores.MAXIMO + 1):
		var cabecera := _celda("Jugador %d" % jugador)
		cabecera.add_theme_color_override("font_color",
			OverlayUnidades.color_jugador(jugador).darkened(0.5))
		tabla.add_child(cabecera)

	for renglon in CONTROLES:
		tabla.add_child(_celda(renglon[0]))
		for jugador in range(1, Jugadores.MAXIMO + 1):
			var etiquetas := Jugadores.etiquetas(jugador)
			tabla.add_child(_celda(etiquetas.get(renglon[1], "")))

	(%PieControles as Label).text = PIE_CONTROLES


func _celda(texto: String) -> Label:
	var celda := Label.new()
	celda.text = texto
	celda.theme_type_variation = &"SobrePanel"
	return celda


func _mostrar_botonera() -> void:
	_botonera.visible = true
	_lecciones.visible = false
	_controles.visible = false
	_opciones.visible = false
	%Jugar.grab_focus()


func _mostrar_lecciones() -> void:
	_botonera.visible = false
	_lecciones.visible = true
	%VolverLecciones.grab_focus()


func _mostrar_controles() -> void:
	_botonera.visible = false
	_controles.visible = true
	%VolverControles.grab_focus()


func _mostrar_opciones() -> void:
	_botonera.visible = false
	_opciones.abrir()
