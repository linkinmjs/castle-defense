extends SceneTree
## Genera las escenas y los recursos del prototipo.

const ANCHO := 30.0
const PROFUNDIDAD := 10.0
## El personaje mide ~68 px de arte y queremos que mida 2 m en el mundo.
const PIXEL_SIZE := 2.0 / 68.0
const RUTA_GRILLA := "res://assets/texturas/grilla.png"
const DIR_HABILIDADES := "res://resources/habilidades3d"


func _initialize() -> void:
	_crear_textura_grilla()
	_crear_habilidades()
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
	curar.costo = 25.0
	curar.enfriamiento = 0.6
	curar.objetivo = Habilidad.Objetivo.ALIADO
	curar.color = Color("5fbf5f")
	curar.cantidad = 35.0
	_guardar_recurso(curar, "curar.tres")

	var estabilizar := HabilidadEstabilizar.new()
	estabilizar.nombre = "Estabilizar"
	estabilizar.tecla = "RMB"
	estabilizar.costo = 10.0
	estabilizar.enfriamiento = 1.2
	estabilizar.objetivo = Habilidad.Objetivo.ALIADO
	estabilizar.color = Color("d2503c")
	_guardar_recurso(estabilizar, "estabilizar.tres")

	var oleada := HabilidadOleada.new()
	oleada.nombre = "Oleada"
	oleada.tecla = "1"
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
	impulso.costo = 12.0
	impulso.enfriamiento = 4.0
	impulso.objetivo = Habilidad.Objetivo.PROPIA
	impulso.color = Color("e0c060")
	impulso.fuerza = 9.5
	impulso.duracion = 0.22
	_guardar_recurso(impulso, "impulso.tres")


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

	var raiz := Control.new()
	raiz.name = "Raiz"
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Todo el HUD ignora el mouse: los clicks tienen que llegar al campo.
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(raiz)
	raiz.owner = hud

	var contadores := _etiqueta("Contadores", 20, Color(0.88, 0.9, 1.0))
	contadores.set_anchors_preset(Control.PRESET_TOP_LEFT)
	contadores.position = Vector2(24, 16)
	raiz.add_child(contadores)
	contadores.owner = hud
	contadores.unique_name_in_owner = true

	var aviso := _etiqueta("Aviso", 22, Color(1.0, 0.92, 0.6))
	aviso.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	aviso.position = Vector2(24, -196)
	raiz.add_child(aviso)
	aviso.owner = hud
	aviso.unique_name_in_owner = true

	var slots := Control.new()
	slots.name = "Slots"
	slots.set_script(load("res://scripts/slots_habilidades.gd"))
	slots.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	slots.position = Vector2(24, -166)
	slots.size = Vector2(560, 62)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(slots)
	slots.owner = hud
	slots.unique_name_in_owner = true

	_barra(raiz, hud, "BarraVida", "TextoVida", -88)
	_barra(raiz, hud, "BarraMana", "TextoMana", -62)

	var ayuda := _etiqueta("Ayuda", 15, Color(0.7, 0.75, 0.85))
	ayuda.text = "WASD mover     Shift impulso     Espacio saltar     Click sobre un aliado para actuar"
	ayuda.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ayuda.position = Vector2(24, -34)
	raiz.add_child(ayuda)
	ayuda.owner = hud

	_guardar(hud, "res://scenes/ui/hud.tscn")


func _barra(raiz: Control, hud: Node, nombre: String, nombre_texto: String, y: float) -> void:
	var barra := ProgressBar.new()
	barra.name = nombre
	barra.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	barra.position = Vector2(24, y)
	barra.size = Vector2(280, 18)
	barra.show_percentage = false
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(barra)
	barra.owner = hud
	barra.unique_name_in_owner = true

	var texto := _etiqueta(nombre_texto, 16, Color(0.9, 0.9, 0.95))
	texto.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	texto.position = Vector2(314, y - 2)
	raiz.add_child(texto)
	texto.owner = hud
	texto.unique_name_in_owner = true


func _etiqueta(nombre: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.name = nombre
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	etiqueta.add_theme_constant_override("shadow_offset_x", 1)
	etiqueta.add_theme_constant_override("shadow_offset_y", 1)
	return etiqueta


func _crear_battle() -> void:
	var battle := Node3D.new()
	battle.name = "Battle3D"
	battle.set_script(load("res://scripts/3d/battle3d.gd"))
	battle.set("ancho_campo", ANCHO)
	battle.set("profundidad_campo", PROFUNDIDAD)

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
