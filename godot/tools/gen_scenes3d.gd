extends SceneTree
## Genera las escenas y los recursos del prototipo.

const ANCHO := 30.0
const PROFUNDIDAD := 10.0
## El personaje mide ~68 px de arte y queremos que mida 2 m en el mundo.
const PIXEL_SIZE := 2.0 / 68.0
const RUTA_GRILLA := "res://assets/texturas/grilla.png"
const DIR_HABILIDADES := "res://resources/habilidades3d"
const DIR_SOLDADOS := "res://resources/soldados"
const RUTA_TEMA := "res://resources/ui/tema.tres"


func _initialize() -> void:
	_crear_textura_grilla()
	_crear_habilidades()
	_crear_tipos()
	_crear_healer()
	_crear_unidad()
	_crear_emergente()
	_crear_hud()
	_crear_battle()
	quit()


## Textura de una celda de 1 m: sin una referencia repetida en el piso, en 3D
## no se percibe ni el avance ni la profundidad.
func _crear_textura_grilla() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://assets/texturas"))

	var lado := 64
	var imagen := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var base := Color("343a4d")
	var linea := Color("3e455c")
	imagen.fill(base)
	for i in lado:
		imagen.set_pixel(i, 0, linea)
		imagen.set_pixel(0, i, linea)
	imagen.save_png(ProjectSettings.globalize_path(RUTA_GRILLA))
	print("%s -> OK" % RUTA_GRILLA)


## Mismas habilidades que en 2D; solo cambian los valores que estan en
## unidades de mundo (radios y fuerzas), que ahora se expresan en metros.
func _crear_habilidades() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_HABILIDADES))

	var curar := HabilidadCurar.new()
	curar.nombre = "Curar"
	curar.tecla = "LMB"
	curar.accion = &"select"
	curar.icono = _icono("curar")
	curar.costo = 25.0
	curar.enfriamiento = 0.6
	curar.objetivo = Habilidad.Objetivo.ALIADO
	curar.color = Color("5fbf5f")
	curar.cantidad = 35.0
	_guardar_recurso(curar, "curar.tres")

	var estabilizar := HabilidadEstabilizar.new()
	estabilizar.nombre = "Estabilizar"
	estabilizar.tecla = "RMB"
	estabilizar.accion = &"cancel"
	estabilizar.icono = _icono("estabilizar")
	estabilizar.costo = 10.0
	estabilizar.enfriamiento = 1.2
	estabilizar.objetivo = Habilidad.Objetivo.ALIADO
	estabilizar.color = Color("d2503c")
	_guardar_recurso(estabilizar, "estabilizar.tres")

	var oleada := HabilidadOleada.new()
	oleada.nombre = "Oleada"
	oleada.tecla = "1"
	oleada.accion = &"habilidad_1"
	oleada.icono = _icono("oleada")
	oleada.costo = 45.0
	oleada.enfriamiento = 14.0
	oleada.objetivo = Habilidad.Objetivo.AREA
	oleada.color = Color("4a9fd4")
	oleada.cantidad = 18.0
	oleada.radio = 5.0
	_guardar_recurso(oleada, "oleada.tres")

	var bendicion := HabilidadBendicion.new()
	bendicion.nombre = "Bendicion"
	bendicion.tecla = "2"
	bendicion.accion = &"habilidad_2"
	bendicion.icono = _icono("bendicion")
	bendicion.costo = 35.0
	bendicion.enfriamiento = 16.0
	bendicion.objetivo = Habilidad.Objetivo.ALIADO
	bendicion.color = Color("6fd3c7")
	bendicion.duracion = 8.0
	bendicion.reduccion_dano = 0.35
	bendicion.bonus_cadencia = 0.30
	_guardar_recurso(bendicion, "bendicion.tres")

	var impulso := HabilidadImpulso.new()
	impulso.nombre = "Impulso"
	impulso.tecla = "Shift"
	impulso.accion = &"dash"
	impulso.icono = _icono("impulso")
	impulso.costo = 12.0
	impulso.enfriamiento = 4.0
	impulso.objetivo = Habilidad.Objetivo.PROPIA
	impulso.color = Color("e0c060")
	impulso.fuerza = 9.5
	impulso.duracion = 0.22
	_guardar_recurso(impulso, "impulso.tres")

	var reanimar := HabilidadReanimar.new()
	reanimar.nombre = "Reanimar"
	reanimar.tecla = "3"
	reanimar.accion = &"habilidad_3"
	reanimar.icono = _icono("reanimar")
	reanimar.costo = 40.0
	reanimar.enfriamiento = 6.0
	reanimar.objetivo = Habilidad.Objetivo.ALIADO
	reanimar.color = Color("b07fd9")
	_guardar_recurso(reanimar, "reanimar.tres")


## Cada tipo le crea un problema distinto al healer: el escudero es el mejor
## paciente pero esta en primera linea; el lancero depende de tener a alguien
## adelante; el espadachin se mete solo en problemas.
func _crear_tipos() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_SOLDADOS))

	var escudero := TipoSoldado.new()
	escudero.nombre = "Escudero"
	escudero.frames = load("res://assets/sprites/soldier/soldier_frames.tres")
	escudero.vida_maxima = 110.0
	escudero.dano = 9.0
	escudero.cadencia = 1.4
	escudero.alcance = 1.3
	escudero.velocidad = 0.9
	escudero.reduccion_dano = 0.25
	_guardar_tipo(escudero, "escudero.tres")

	var lancero := TipoSoldado.new()
	lancero.nombre = "Lancero"
	lancero.frames = load("res://assets/sprites/lancero/lancero_frames.tres")
	lancero.vida_maxima = 70.0
	lancero.dano = 13.0
	lancero.cadencia = 1.1
	lancero.alcance = 2.2
	lancero.velocidad = 1.0
	lancero.retirada_bajo = 0.3
	_guardar_tipo(lancero, "lancero.tres")

	var espadachin := TipoSoldado.new()
	espadachin.nombre = "Espadachin"
	espadachin.frames = load("res://assets/sprites/espadachin/espadachin_frames.tres")
	espadachin.vida_maxima = 65.0
	espadachin.dano = 16.0
	espadachin.cadencia = 0.8
	espadachin.alcance = 1.3
	espadachin.velocidad = 1.3
	espadachin.oportunista = true
	_guardar_tipo(espadachin, "espadachin.tres")

	var zombie := TipoSoldado.new()
	zombie.nombre = "Zombi"
	zombie.frames = load("res://assets/sprites/enemy/enemy_frames.tres")
	zombie.vida_maxima = 75.0
	zombie.dano = 12.0
	zombie.cadencia = 1.0
	zombie.alcance = 1.3
	zombie.velocidad = 0.95
	_guardar_tipo(zombie, "zombie.tres")


func _guardar_tipo(recurso: Resource, archivo: String) -> void:
	var ruta := "%s/%s" % [DIR_SOLDADOS, archivo]
	var err := ResourceSaver.save(recurso, ruta)
	print("%s -> %s" % [ruta, "OK" if err == OK else "ERROR %d" % err])


## El icono es opcional: si todavia no se corrio extraer_ui.gd, la habilidad se
## guarda sin el y el slot cae al nombre en texto.
func _icono(nombre: String) -> Texture2D:
	var ruta := "res://assets/ui/habilidades/%s.png" % nombre
	return load(ruta) if ResourceLoader.exists(ruta) else null


func _guardar_recurso(recurso: Resource, archivo: String) -> void:
	var ruta := "%s/%s" % [DIR_HABILIDADES, archivo]
	var err := ResourceSaver.save(recurso, ruta)
	print("%s -> %s" % [ruta, "OK" if err == OK else "ERROR %d" % err])


func _crear_healer() -> void:
	var healer := CharacterBody3D.new()
	healer.name = "Healer"
	healer.set_script(load("res://scripts/3d/healer3d.gd"))

	var sprite := AnimatedSprite3D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = load("res://assets/sprites/healer/healer_frames.tres")
	sprite.animation = "idle"
	sprite.autoplay = "idle"
	sprite.pixel_size = PIXEL_SIZE
	# El frame tiene los pies apoyados abajo: subirlo media altura deja el
	# origen del nodo a ras del suelo.
	sprite.offset = Vector2(0, 64)
	# Encara siempre a la camara pero sin inclinarse: es un recorte parado.
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Sin alpha_cut el recorte no proyecta sombra y se pelea con el z-buffer.
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite.modulate = Color(1.0, 0.88, 0.55)
	healer.add_child(sprite)
	sprite.owner = healer

	var colision := CollisionShape3D.new()
	colision.name = "CollisionShape3D"
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.32
	capsula.height = 1.7
	colision.shape = capsula
	colision.position = Vector3(0, 0.85, 0)
	healer.add_child(colision)
	colision.owner = healer

	var habilidades := Node.new()
	habilidades.name = "Habilidades"
	habilidades.set_script(load("res://scripts/abilities/componente_habilidades.gd"))
	var lista: Array[Habilidad] = [
		load(DIR_HABILIDADES + "/curar.tres"),
		load(DIR_HABILIDADES + "/estabilizar.tres"),
		load(DIR_HABILIDADES + "/oleada.tres"),
		load(DIR_HABILIDADES + "/bendicion.tres"),
		load(DIR_HABILIDADES + "/impulso.tres"),
		load(DIR_HABILIDADES + "/reanimar.tres"),
	]
	habilidades.set("habilidades", lista)
	healer.add_child(habilidades)
	habilidades.owner = healer

	_guardar(healer, "res://scenes/3d/healer3d.tscn")


func _crear_unidad() -> void:
	var unidad := CharacterBody3D.new()
	unidad.name = "Unidad"
	unidad.set_script(load("res://scripts/3d/unidad3d.gd"))
	unidad.collision_layer = 4
	unidad.collision_mask = 12

	var sprite := AnimatedSprite3D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = load("res://assets/sprites/soldier/soldier_frames.tres")
	sprite.animation = "idle"
	sprite.autoplay = "idle"
	sprite.pixel_size = PIXEL_SIZE
	sprite.offset = Vector2(0, 64)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	unidad.add_child(sprite)
	sprite.owner = unidad

	var colision := CollisionShape3D.new()
	colision.name = "CollisionShape3D"
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.32
	capsula.height = 1.7
	colision.shape = capsula
	colision.position = Vector3(0, 0.85, 0)
	unidad.add_child(colision)
	colision.owner = unidad

	_guardar(unidad, "res://scenes/3d/unidad3d.tscn")


## Aviso en el suelo: un disco chato, sin luz ni sombra, que la batalla
## escala mientras late.
func _crear_emergente() -> void:
	var raiz := Node3D.new()
	raiz.name = "Emergente"
	raiz.set_script(load("res://scripts/3d/emergente3d.gd"))

	var marca := MeshInstance3D.new()
	marca.name = "Marca"
	var disco := CylinderMesh.new()
	disco.top_radius = 0.75
	disco.bottom_radius = 0.75
	disco.height = 0.04
	marca.mesh = disco
	marca.position = Vector3(0, 0.02, 0)
	marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.72, 0.12, 0.1, 0.7)
	marca.material_override = material
	raiz.add_child(marca)
	marca.owner = raiz

	_guardar(raiz, "res://scenes/3d/emergente3d.tscn")


func _crear_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/hud.gd"))
	# Explicito: el menu de pausa va en la 10 y tiene que quedar por encima.
	hud.layer = 1

	var raiz := Control.new()
	raiz.name = "Raiz"
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Todo el HUD ignora el mouse: los clicks tienen que llegar al campo.
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = load(RUTA_TEMA)
	hud.add_child(raiz)
	raiz.owner = hud

	_hud_superior(raiz, hud)
	_hud_centro(raiz, hud)
	_hud_inferior(raiz, hud)
	_hud_tarjeta(raiz, hud)

	_guardar(hud, "res://scenes/ui/hud.tscn")


## Arriba: los conteos a la izquierda y el frente al centro.
func _hud_superior(raiz: Control, hud: Node) -> void:
	var contadores := _etiqueta("Contadores", &"Subtitulo")
	contadores.set_anchors_preset(Control.PRESET_TOP_LEFT)
	contadores.position = Vector2(24, 16)
	_colgar(raiz, contadores, hud, true)

	var frente := Control.new()
	frente.name = "Frente"
	frente.set_script(load("res://scripts/indicador_frente.gd"))
	frente.set_anchors_preset(Control.PRESET_CENTER_TOP)
	frente.position = Vector2(-200, 14)
	frente.size = Vector2(400, 26)
	frente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(raiz, frente, hud, true)

	# Titulo del encuentro y que enseña, debajo del indicador de frente.
	var encabezado := _etiqueta("Encabezado", &"Subtitulo")
	encabezado.set_anchors_preset(Control.PRESET_CENTER_TOP)
	encabezado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	encabezado.position = Vector2(-320, 46)
	encabezado.size = Vector2(640, 52)
	_colgar(raiz, encabezado, hud, true)


## El centro se usa solo al terminar: el cartel y, debajo, el informe.
func _hud_centro(raiz: Control, hud: Node) -> void:
	var centro := CenterContainer.new()
	centro.name = "Centro"
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(raiz, centro, hud)

	var columna := VBoxContainer.new()
	columna.name = "ColumnaCentro"
	columna.add_theme_constant_override("separation", 12)
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(centro, columna, hud)

	var desenlace := _etiqueta("Desenlace", &"Titulo")
	desenlace.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desenlace.add_theme_font_size_override("font_size", 48)
	desenlace.visible = false
	_colgar(columna, desenlace, hud, true)

	var resumen := PanelContainer.new()
	resumen.name = "Resumen"
	resumen.set_script(load("res://scripts/resumen_encuentro.gd"))
	resumen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resumen.visible = false
	_colgar(columna, resumen, hud, true)


## Abajo a la izquierda: estado del healer, sus acciones y la ayuda.
func _hud_inferior(raiz: Control, hud: Node) -> void:
	var columna := VBoxContainer.new()
	columna.name = "Inferior"
	# Anclado abajo a la izquierda y creciendo hacia arriba: asi el bloque se
	# acomoda solo cuando un encuentro equipa mas o menos habilidades.
	columna.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	columna.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Offsets y no position: con position el contenedor arranca ahi y se apila
	# hacia abajo, saliendose de la pantalla. Fijando el borde de abajo, crece
	# hacia arriba y el bloque entero queda apoyado sobre el margen inferior.
	columna.offset_left = 24
	columna.offset_bottom = -20
	columna.add_theme_constant_override("separation", 6)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(raiz, columna, hud)

	var aviso := _etiqueta("Aviso", &"Aviso")
	_colgar(columna, aviso, hud, true)

	var slots := PanelContainer.new()
	slots.name = "Slots"
	slots.set_script(load("res://scripts/slots_habilidades.gd"))
	# Que mida lo que ocupan sus slots y no todo el ancho de la columna, que lo
	# fija el renglon de ayuda.
	slots.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(columna, slots, hud, true)

	_barra(columna, hud, "BarraVida", "TextoVida", &"BarraVida")
	_barra(columna, hud, "BarraMana", "TextoMana", &"BarraMana")

	var ayuda := _etiqueta("Ayuda", &"Chico")
	ayuda.text = "WASD mover     Espacio saltar     Click sobre un aliado para actuar     Esc pausa"
	_colgar(columna, ayuda, hud)


## La ficha del apuntado, abajo a la derecha: lejos de los slots y del centro,
## que es por donde pasa la linea de combate.
func _hud_tarjeta(raiz: Control, hud: Node) -> void:
	var tarjeta := PanelContainer.new()
	tarjeta.name = "Tarjeta"
	tarjeta.set_script(load("res://scripts/tarjeta_objetivo.gd"))
	tarjeta.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	tarjeta.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tarjeta.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tarjeta.offset_right = -24
	tarjeta.offset_bottom = -20
	tarjeta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(raiz, tarjeta, hud, true)


## Una barra con su numero al lado.
func _barra(columna: Control, hud: Node, nombre: String, nombre_texto: String,
		variacion: StringName) -> void:
	var fila := HBoxContainer.new()
	fila.name = nombre + "Fila"
	fila.add_theme_constant_override("separation", 10)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(columna, fila, hud)

	var barra := ProgressBar.new()
	barra.name = nombre
	barra.theme_type_variation = variacion
	barra.custom_minimum_size = Vector2(280, 18)
	barra.show_percentage = false
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colgar(fila, barra, hud, true)

	var texto := _etiqueta(nombre_texto, &"Chico")
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_colgar(fila, texto, hud, true)


## Los colores y tamanos ya no se repiten por nodo: los pone el tema, y la
## variacion dice para que sirve cada etiqueta.
func _etiqueta(nombre: String, variacion: StringName) -> Label:
	var etiqueta := Label.new()
	etiqueta.name = nombre
	etiqueta.theme_type_variation = variacion
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


func _colgar(padre: Node, nodo: Node, duenio: Node, unico: bool = false) -> void:
	padre.add_child(nodo)
	nodo.owner = duenio
	if unico:
		nodo.unique_name_in_owner = true



func _crear_battle() -> void:
	var battle := Node3D.new()
	battle.name = "Battle3D"
	battle.set_script(load("res://scripts/3d/battle3d.gd"))
	battle.set("ancho_campo", ANCHO)
	battle.set("profundidad_campo", PROFUNDIDAD)
	var aliados: Array[TipoSoldado] = [
		load(DIR_SOLDADOS + "/escudero.tres"),
		load(DIR_SOLDADOS + "/lancero.tres"),
		load(DIR_SOLDADOS + "/espadachin.tres"),
	]
	var enemigos: Array[TipoSoldado] = [load(DIR_SOLDADOS + "/zombie.tres")]
	battle.set("tipos_aliados", aliados)
	battle.set("tipos_enemigos", enemigos)

	_agregar_entorno(battle)
	_agregar_suelo(battle)
	_agregar_base(battle, Vector3(1.0, 0, PROFUNDIDAD * 0.5), Color("4a7fd4"), "BaseAliada")
	_agregar_base(battle, Vector3(ANCHO - 1.0, 0, PROFUNDIDAD * 0.5), Color("c4553f"), "BaseEnemiga")

	var unidades := Node3D.new()
	unidades.name = "Unidades"
	battle.add_child(unidades)
	unidades.owner = battle
	unidades.unique_name_in_owner = true

	var escena_healer: PackedScene = load("res://scenes/3d/healer3d.tscn")
	var healer: Node3D = escena_healer.instantiate()
	healer.name = "Healer"
	healer.position = Vector3(ANCHO * 0.4, 0, PROFUNDIDAD * 0.5)
	unidades.add_child(healer)
	healer.owner = battle
	healer.unique_name_in_owner = true

	var camara := Camera3D.new()
	camara.name = "Camara"
	camara.fov = 42.0
	battle.add_child(camara)
	camara.owner = battle
	camara.unique_name_in_owner = true

	# Las barras de vida van en una capa 2D encima del mundo: se proyectan
	# desde la camara en vez de colgar carteles de cada soldado.
	var capa := CanvasLayer.new()
	capa.name = "CapaUnidades"
	battle.add_child(capa)
	capa.owner = battle

	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.set_script(load("res://scripts/3d/overlay_unidades.gd"))
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(overlay)
	overlay.owner = battle
	overlay.unique_name_in_owner = true

	var escena_hud: PackedScene = load("res://scenes/ui/hud.tscn")
	var hud := escena_hud.instantiate()
	hud.name = "HUD"
	battle.add_child(hud)
	hud.owner = battle
	hud.unique_name_in_owner = true

	# El menu de pausa va por encima del HUD y arranca invisible. Si todavia no
	# se genero (proyecto recien clonado, sin correr gen_ui), la batalla se
	# arma igual y simplemente no hay pausa.
	if ResourceLoader.exists("res://scenes/ui/menu_pausa.tscn"):
		var escena_pausa: PackedScene = load("res://scenes/ui/menu_pausa.tscn")
		var pausa := escena_pausa.instantiate()
		pausa.name = "MenuPausa"
		battle.add_child(pausa)
		pausa.owner = battle
		pausa.unique_name_in_owner = true

	_guardar(battle, "res://scenes/3d/battle3d.tscn")


func _agregar_entorno(battle: Node3D) -> void:
	var entorno := WorldEnvironment.new()
	entorno.name = "Entorno"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("161a27")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5a6180")
	env.ambient_light_energy = 0.9
	# Niebla suave: da sensacion de distancia y despega el fondo del frente.
	env.fog_enabled = true
	env.fog_light_color = Color("161a27")
	env.fog_density = 0.03
	entorno.environment = env
	battle.add_child(entorno)
	entorno.owner = battle

	var luz := DirectionalLight3D.new()
	luz.name = "Sol"
	luz.rotation_degrees = Vector3(-52, -130, 0)
	luz.light_energy = 1.1
	luz.light_color = Color("fff2d8")
	luz.shadow_enabled = true
	battle.add_child(luz)
	luz.owner = battle


func _agregar_suelo(battle: Node3D) -> void:
	var suelo := MeshInstance3D.new()
	suelo.name = "Suelo"
	var plano := PlaneMesh.new()
	plano.size = Vector2(ANCHO * 2.2, PROFUNDIDAD * 3.0)
	suelo.mesh = plano
	suelo.position = Vector3(ANCHO * 0.5, 0, PROFUNDIDAD * 0.5)

	var material := StandardMaterial3D.new()
	var textura: Texture2D = load(RUTA_GRILLA)
	material.albedo_texture = textura
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Una repeticion por metro: cada celda del piso mide 1 m.
	material.uv1_scale = Vector3(plano.size.x, plano.size.y, 1.0)
	material.roughness = 1.0
	suelo.material_override = material
	battle.add_child(suelo)
	suelo.owner = battle


func _agregar_base(battle: Node3D, pos: Vector3, color: Color, nombre: String) -> void:
	var base := MeshInstance3D.new()
	base.name = nombre
	var caja := BoxMesh.new()
	caja.size = Vector3(1.6, 4.0, 5.0)
	base.mesh = caja
	base.position = pos + Vector3(0, 2.0, 0)

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	base.material_override = material
	battle.add_child(base)
	base.owner = battle


func _guardar(nodo: Node, ruta: String) -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(ruta.get_base_dir()))
	var empaquetada := PackedScene.new()
	var err := empaquetada.pack(nodo)
	if err != OK:
		push_error("No se pudo empaquetar %s: %d" % [ruta, err])
		return
	err = ResourceSaver.save(empaquetada, ruta)
	print("%s -> %s" % [ruta, "OK" if err == OK else "ERROR %d" % err])
