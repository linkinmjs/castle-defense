extends SceneTree
## Genera las escenas y los recursos del prototipo.
##
## El HUD sale de gen_hud.gd y los movimientos del healer de gen_movimientos.gd;
## los dos se corren antes que este, que los usa tal como quedaron guardados.

const ANCHO := 30.0
const PROFUNDIDAD := 10.0
## El personaje mide ~68 px de arte y queremos que mida 2 m en el mundo.
const PIXEL_SIZE := 2.0 / 68.0
const DIR_MOVIMIENTOS := "res://resources/movimientos"
const DIR_SOLDADOS := "res://resources/soldados"
const RUTA_HUD := "res://scenes/ui/hud.tscn"
## Lo que el healer trae equipado de fabrica, en el orden en que se lee la
## tabla: primero lo que sale sin combo, despues lo que lo continua, al final
## lo del aire. El orden solo desempata, y en la tabla no hay empates.
const MOVIMIENTOS: Array[String] = [
	"toque", "vendaje", "plegaria", "bendicion", "oleada", "reanimar", "impulso", "caida",
]


func _initialize() -> void:
	for archivo in MOVIMIENTOS:
		if not ResourceLoader.exists(_ruta_movimiento(archivo)):
			print("Falta %s. Correr primero:" % _ruta_movimiento(archivo))
			print("  --script res://tools/gen_movimientos.gd")
			quit(1)
			return

	_crear_tipos()
	_crear_healer()
	_crear_unidad()
	_crear_emergente()
	_crear_marca_telegrafo()
	_crear_battle()
	quit()


## Cada tipo le crea un problema distinto al healer: el escudero es el mejor
## paciente pero esta en primera linea; el lancero depende de tener a alguien
## adelante; el espadachin se mete solo en problemas. Del otro lado, el bruto
## avisa donde va a pegar y obliga a decidir antes de que caiga, y el demonio
## hace lo mismo con media linea adentro.
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

	# Pega poco pero muy fuerte, y se ve venir: carga el golpe con una marca en
	# el suelo. El healer elige entre saltarlo, bendecir al que lo va a recibir
	# o curar despues. Pega a ras del suelo y en un circulo chico.
	var bruto := TipoSoldado.new()
	bruto.nombre = "Bruto"
	bruto.frames = load("res://assets/sprites/bruto/bruto_frames.tres")
	bruto.vida_maxima = 260.0
	bruto.dano = 34.0
	bruto.cadencia = 2.6
	bruto.alcance = 1.6
	bruto.velocidad = 0.7
	bruto.telegrafiado = 1.2
	bruto.barrido = true
	bruto.radio_golpe = 1.2
	# Hoja de 40 px con el oso ocupando 31: sin esto se veria de un metro.
	bruto.lado_frame = 40
	bruto.alto_util_px = 31.0
	bruto.altura_metros = 2.2
	bruto.radio_colision = 0.5
	bruto.altura_barra = 2.4
	_guardar_tipo(bruto, "bruto.tres")

	# El jefe del ultimo nivel: grande, con dos golpes anunciados que pegan en
	# un area que abarca media linea. El segundo pega mas.
	var demonio := TipoSoldado.new()
	demonio.nombre = "Demonio"
	demonio.frames = load("res://assets/sprites/demonio/demonio_frames.tres")
	demonio.vida_maxima = 700.0
	demonio.dano = 24.0
	demonio.cadencia = 3.0
	demonio.alcance = 2.6
	demonio.velocidad = 0.8
	demonio.telegrafiado = 1.4
	demonio.barrido = false
	demonio.radio_golpe = 1.8
	demonio.anim_ataque_2 = "attack2"
	demonio.factor_ataque_2 = 1.5
	demonio.lado_frame = 96
	demonio.alto_util_px = 52.0
	demonio.altura_metros = 3.2
	demonio.radio_colision = 0.7
	demonio.altura_barra = 3.5
	demonio.es_jefe = true
	_guardar_tipo(demonio, "demonio.tres")


func _guardar_tipo(recurso: Resource, archivo: String) -> void:
	var ruta := "%s/%s" % [DIR_SOLDADOS, archivo]
	var err := ResourceSaver.save(recurso, ruta)
	print("%s -> %s" % [ruta, "OK" if err == OK else "ERROR %d" % err])


func _ruta_movimiento(archivo: String) -> String:
	return "%s/%s.tres" % [DIR_MOVIMIENTOS, archivo]


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
	# El tinte del jugador 1, apenas un toque: el contorno dorado ya viene en
	# el sprite, y el tinte fuerte de antes lo ensuciaba. Va en los dos lados:
	# el healer pisa el modulate del sprite con tinte_jugador al arrancar, y el
	# modulate es lo que se ve en el editor.
	var tinte := Jugadores.tinte(1)
	sprite.modulate = tinte
	healer.set("tinte_jugador", tinte)
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

	# Todos los movimientos: un encuentro que quiera menos los recorta al
	# empezar, y uno que no diga nada juega con estos.
	var combos := ComponenteCombos.new()
	combos.name = "Combos"
	var lista: Array[Movimiento] = []
	for archivo in MOVIMIENTOS:
		lista.append(load(_ruta_movimiento(archivo)))
	combos.movimientos = lista
	healer.add_child(combos)
	combos.owner = healer

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


## Aviso de un golpe telegrafiado: el area del golpe, tenue y fija, y adentro un
## disco que crece hasta llenarla. Los dos miden 1 m de radio, asi la marca los
## escala directo al radio del golpe en metros.
func _crear_marca_telegrafo() -> void:
	var raiz := Node3D.new()
	raiz.name = "MarcaTelegrafo"
	raiz.set_script(load("res://scripts/3d/marca_telegrafo.gd"))

	var color := Color(0.95, 0.35, 0.15, 0.7)
	_agregar_disco(raiz, "Area", Color(color, 0.22), 0.02, 0)
	# Mas alto y dibujado despues: el que crece va siempre encima del area,
	# aunque las dos transparencias queden casi a la misma distancia.
	_agregar_disco(raiz, "Carga", color, 0.04, 1)

	_guardar(raiz, "res://scenes/3d/marca_telegrafo.tscn")


## Disco chato, sin luz ni sombra, como el del emergente.
func _agregar_disco(raiz: Node3D, nombre: String, color: Color, alto: float,
		prioridad: int) -> void:
	var disco := MeshInstance3D.new()
	disco.name = nombre
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 1.0
	cilindro.bottom_radius = 1.0
	cilindro.height = alto
	disco.mesh = cilindro
	disco.position = Vector3(0, alto * 0.5, 0)
	disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.render_priority = prioridad
	disco.material_override = material
	raiz.add_child(disco)
	disco.owner = raiz


func _crear_battle() -> void:
	var battle := Node3D.new()
	battle.name = "Battle3D"
	battle.set_script(load("res://scripts/3d/battle3d.gd"))
	battle.set("ancho_campo", ANCHO)
	battle.set("profundidad_campo", PROFUNDIDAD)

	_agregar_entorno(battle)
	_agregar_mundo(battle)

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

	# La camara lateral que sigue a los healers. No tiene _process propio: la
	# batalla la avanza desde el suyo y le pasa el campo en cada encuentro.
	var camara := CamaraBatalla.new()
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

	# El HUD lo genera gen_hud.gd. Si todavia no se corrio, el resto se genera
	# igual y queda el aviso; la batalla no arranca sin HUD, asi que despues
	# hay que correr gen_hud.gd y este de nuevo.
	if ResourceLoader.exists(RUTA_HUD):
		var escena_hud: PackedScene = load(RUTA_HUD)
		var hud := escena_hud.instantiate()
		hud.name = "HUD"
		battle.add_child(hud)
		hud.owner = battle
		hud.unique_name_in_owner = true
	else:
		push_warning("Falta %s: correr antes tools/gen_hud.gd" % RUTA_HUD)

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


## Atardecer: el sol bajo y tibio viene de atras y de la izquierda, del lado del
## resplandor del cielo, y tira sombras largas hacia la derecha y hacia la
## camara. Los sprites y las capas del fondo no tienen luz propia (traen la
## suya pintada): lo que el sol cambia es el suelo y las sombras.
func _agregar_entorno(battle: Node3D) -> void:
	var entorno := WorldEnvironment.new()
	entorno.name = "Entorno"
	var env := Environment.new()
	# Detras de todo esta el quad del cielo. El color de fondo es el del
	# resplandor de abajo, por si alguna rendija lo deja asomar en el horizonte.
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e8a05a")
	# Con el sol de frente a la camara casi todo lo que se ve del suelo esta a
	# contraluz: el ambiente es el cielo lila que lo rellena.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("4a3a62")
	env.ambient_light_energy = 1.2
	# Los sprites y las capas no tienen luz: el tonemap es lo unico que les
	# cambia el color. Con white en 1 (el de fabrica), el filmic aclara todos
	# los medios (un 0.5 lineal sale 0.69) y los soldados se veian lavados; en
	# 3 los medios quedan casi como los pinto el arte y solo se aplastan las
	# luces altas.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 3.0
	env.tonemap_exposure = 1.05
	# Glow solo para lo que brilla de verdad (destellos y efectos): con el
	# umbral en 0.9 casi nada del arte llega. El bloom se suma parejo a toda
	# la pantalla y era lo que lavaba los sprites: queda apenas.
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	# Niebla por distancia a la camara, del color del monte: apenas toca las
	# esquinas del fondo del campo (un cuarto), oscurece el pasto de atras y lo
	# lleva del todo al color de los arboles donde el suelo se mete bajo su
	# capa, asi no queda la raya recta (con 0.85 quedaba un escalon). Las capas
	# del fondo no la ven: la perspectiva aerea ya la traen pintada.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("1c1730")
	env.fog_depth_begin = 16.0
	env.fog_depth_end = 26.0
	env.fog_density = 1.0
	entorno.environment = env
	battle.add_child(entorno)
	entorno.owner = battle

	var luz := DirectionalLight3D.new()
	luz.name = "Sol"
	# A 30 grados sobre el horizonte, desde atras a la izquierda: un soldado de
	# 2 m tira una sombra de 3.5 m, 3 hacia +X y 1.7 hacia la camara. Mas
	# hacia la camara la de la fila de adelante se saldria por abajo.
	luz.rotation_degrees = Vector3(-30, -120, 0)
	luz.light_energy = 0.8
	luz.light_color = Color("ffcf9a")
	luz.shadow_enabled = true
	# Negra del todo, la sombra se tragaba las piernas oscuras de los sprites.
	luz.shadow_opacity = 0.8
	# El campo entero queda a menos de 25 m de la camara: con el alcance por
	# defecto (100 m) la resolucion de la sombra se reparte en lo que no se ve.
	luz.directional_shadow_max_distance = 40.0
	battle.add_child(luz)
	luz.owner = battle


# --- Mundo --------------------------------------------------------------------

const DIR_FONDOS := "res://assets/fondos"


## El escenario: %Mundo con las capas del fondo, el suelo, el camino y las
## murallas. Aca se arma cada nodo con su textura y su material; donde va y
## cuanto mide cada uno lo decide Mundo.configurar(), que se llama al final
## con el campo de la escena para que quede armado tal como lo va a ver un
## encuentro de esas medidas.
func _agregar_mundo(battle: Node3D) -> void:
	var mundo := Mundo.new()
	mundo.name = "Mundo"
	battle.add_child(mundo)
	mundo.owner = battle
	mundo.unique_name_in_owner = true

	for nombre: StringName in Mundo.CAPAS:
		_agregar_capa(mundo, nombre, Mundo.CAPAS[nombre])
	_agregar_suelo(mundo)
	_agregar_camino(mundo)
	_agregar_muro(mundo, "MuroAliado")
	_agregar_muro(mundo, "MuroEnemigo")
	_agregar_porton(mundo)

	mundo.configurar(battle.get("ancho_campo"), battle.get("profundidad_campo"),
		battle.get("base_aliada_x"), battle.get("base_enemiga_x"))


## Una capa del fondo: un quad con el nodo en el borde de abajo, paralelo al
## plano de la camara, que repite la textura en X. Mide Mundo.ANCHO_CAPA, o
## una sola vuelta de la textura si la capa es "una_vuelta"; con "filas" solo
## muestra esas filas de abajo de la textura.
func _agregar_capa(mundo: Mundo, nombre: StringName, datos: Dictionary) -> void:
	var textura := _textura_fondo(String(datos["textura"]))
	var repeticion := float(datos["repeticion"])
	var quad := QuadMesh.new()
	var ancho := repeticion if datos.get("una_vuelta", false) else Mundo.ANCHO_CAPA
	quad.size = Vector2(ancho, float(datos["alto"]))
	quad.center_offset = Vector3(0, quad.size.y * 0.5, 0)

	var material := _material_recorte(textura)
	# La perspectiva aerea ya esta pintada: con niebla, las montanas quedarian
	# tres cuartos del color del monte.
	material.disable_fog = true
	material.uv1_scale = Vector3(ancho / repeticion, 1, 1)
	if datos.has("filas"):
		var parte := float(datos["filas"]) / textura.get_height()
		material.uv1_scale.y = parte
		material.uv1_offset.y = 1.0 - parte
	# configurar() le corre el uv1_offset.x en cada encuentro.
	material.resource_local_to_scene = true
	_agregar_parado(mundo, nombre, quad, material)


func _agregar_suelo(mundo: Mundo) -> void:
	var suelo := MeshInstance3D.new()
	suelo.name = "Suelo"
	var plano := PlaneMesh.new()
	plano.resource_local_to_scene = true
	suelo.mesh = plano
	# Recibe sombras pero no tira: debajo no hay nada, y con el sol rasante un
	# plano en el mapa de sombras solo agrega acne.
	suelo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	suelo.material_override = _material_piso(_textura_fondo("suelo"))
	mundo.add_child(suelo)
	suelo.owner = mundo.owner


## El camino es un plano apenas encima del suelo, con la misma luz y las mismas
## sombras. Recorte y no mezcla: asi se dibuja con lo opaco, sin ordenarse
## contra los sprites.
func _agregar_camino(mundo: Mundo) -> void:
	var camino := MeshInstance3D.new()
	camino.name = "Camino"
	var plano := PlaneMesh.new()
	plano.resource_local_to_scene = true
	camino.mesh = plano
	camino.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := _material_piso(_textura_fondo("camino"))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	camino.material_override = material
	mundo.add_child(camino)
	camino.owner = mundo.owner


## Piso mate, a la luz del sol. Con el especular de fabrica (0.5), mirando
## hacia el sol el pasto del fondo brillaba como mojado y aclaraba justo la
## union con los arboles.
func _material_piso(textura: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = textura
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	material.metallic = 0.0
	material.metallic_specular = 0.25
	# configurar() le cambia la escala de la textura en cada encuentro.
	material.resource_local_to_scene = true
	return material


## Las murallas y el porton miran a la camara con el sol atras: la cara que se
## ve esta a contraluz. Con los colores tal cual eran lo mas claro de la
## pantalla y le competian a los soldados; asi quedan del tono del castillo
## lejano, sin perder los sillares ni el arco.
const CONTRALUZ := Color(0.62, 0.6, 0.72)


## Una muralla: un solo quad que repite muro.png, estirado por configurar().
func _agregar_muro(mundo: Mundo, nombre: String) -> void:
	var textura := _textura_fondo("muro")
	var quad := _quad_a_escala(textura)
	quad.resource_local_to_scene = true
	var material := _material_recorte(textura)
	material.albedo_color = CONTRALUZ
	material.resource_local_to_scene = true
	_agregar_parado(mundo, nombre, quad, material)


func _agregar_porton(mundo: Mundo) -> void:
	var textura := _textura_fondo("porton")
	var material := _material_recorte(textura)
	material.albedo_color = CONTRALUZ
	# Un solo porton: no se repite.
	material.texture_repeat = false
	_agregar_parado(mundo, "Porton", _quad_a_escala(textura), material)


## Quad del tamano de la textura a la escala de los sprites, con el nodo en el
## borde de abajo.
func _quad_a_escala(textura: Texture2D) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(textura.get_width(), textura.get_height()) / Mundo.TEXELES_POR_METRO
	quad.center_offset = Vector3(0, quad.size.y * 0.5, 0)
	return quad


## Sin luz (los colores ya son los del atardecer), recorte duro y nearest: lo
## mismo que los sprites.
func _material_recorte(textura: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = textura
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material


## Parado como los fondos: rotado -15 grados en X, paralelo al plano de la
## camara, para que no se vea torcido. Sin sombra: el sol viene de atras y la
## silueta tiraria una franja de sombra sobre el campo.
func _agregar_parado(mundo: Mundo, nombre: String, quad: QuadMesh, material: Material) -> void:
	var nodo := MeshInstance3D.new()
	nodo.name = nombre
	nodo.mesh = quad
	nodo.material_override = material
	nodo.rotation_degrees = Vector3(-15, 0, 0)
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mundo.add_child(nodo)
	nodo.owner = mundo.owner


func _textura_fondo(nombre: String) -> Texture2D:
	return load("%s/%s.png" % [DIR_FONDOS, nombre])


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
