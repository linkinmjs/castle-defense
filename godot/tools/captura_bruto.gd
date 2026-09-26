extends SceneTree
## Capturas del bruto y del jefe frente a la linea: la marca en el suelo
## mientras cargan y el campo justo despues de cada golpe. Sirven para ver la
## escala (bruto ~2.2 m, demonio ~3.2 m, pies en el suelo), el contorno rojo
## y que la marca se lee con la camara casi de costado.
## Correr SIN --headless: sin ventana no hay textura que guardar.

const BRUTO := preload("res://resources/soldados/bruto.tres")
const DEMONIO := preload("res://resources/soldados/demonio.tres")
const ESCUDERO := preload("res://resources/soldados/escudero.tres")
## Segundos que esperan quietos, para que la ventana y la camara se asienten
## antes del primer golpe.
const ESPERA := 1.5
## Cuanto despues de un golpe se saca la foto: la imagen que se guarda es la
## del ultimo frame dibujado, y la marca se libera recien al final del tick.
const DESPUES := 0.08

var _battle: Node
var _bruto: Unidad3D
var _demonio: Unidad3D
var _inicio_ms := 0
## Segundos (desde el inicio) en que empezo el golpe del bruto y en que cayo
## cada uno. -1 mientras no paso.
var _anuncio_bruto := -1.0
var _cayo_bruto := -1.0
var _cayo_demonio := -1.0
var _paso := 0


func _initialize() -> void:
	var encuentro := Encuentro.new()
	encuentro.titulo = "Bruto y jefe"
	encuentro.semilla = 3
	encuentro.condicion = Encuentro.Condicion.SOBREVIVIR
	encuentro.sangrado_habilitado = false
	# Atras de la linea y fuera de las dos marcas: la camara lo sigue a el.
	encuentro.healer_inicial = Vector2(10.5, 5.0)
	for z in [2.6, 4.2, 5.8, 7.4]:
		encuentro.grupos_iniciales.append(_grupo(Unidad3D.Bando.ALIADO, ESCUDERO, Vector3(12.0, 0, z)))
	# El bruto adelante, del lado de la camara, y el demonio al fondo: tan
	# grande que se ve igual, y asi las dos marcas no se pisan.
	encuentro.grupos_iniciales.append(_grupo(Unidad3D.Bando.ENEMIGO, BRUTO, Vector3(13.45, 0, 7.6)))
	encuentro.grupos_iniciales.append(_grupo(Unidad3D.Bando.ENEMIGO, DEMONIO, Vector3(14.4, 0, 3.0)))

	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	_battle.encuentro = encuentro
	_battle.unidad_creada.connect(_al_crear)
	root.add_child(_battle)
	_inicio_ms = Time.get_ticks_msec()
	print("t(s)   que                         -> captura")


func _process(_delta: float) -> bool:
	var t := (Time.get_ticks_msec() - _inicio_ms) / 1000.0
	match _paso:
		0:
			if t >= ESPERA:
				_bruto.set_physics_process(true)
				_demonio.set_physics_process(true)
				_medir()
				_paso += 1
		1:
			if _anuncio_bruto >= 0.0 and t >= _anuncio_bruto + 0.9:
				_foto(t, "las dos marcas cargando", "bruto_01_marcas.png")
		2:
			if _cayo_bruto >= 0.0 and t >= _cayo_bruto + DESPUES:
				_foto(t, "cayo el golpe del bruto", "bruto_02_golpe_bruto.png")
		3:
			if _cayo_demonio >= 0.0 and t >= _cayo_demonio + DESPUES:
				_foto(t, "cayo el golpe del demonio", "bruto_03_golpe_demonio.png")
				return true
	return false


## Quietos hasta que se asiente la ventana; la linea si puede ir acercandose.
func _al_crear(unidad: Unidad3D) -> void:
	if unidad.tipo == BRUTO:
		_bruto = unidad
		_bruto.golpe_anunciado.connect(func(_p: Vector3, _r: float, _s: float) -> void:
			if _anuncio_bruto < 0.0:
				_anuncio_bruto = _ahora())
		_bruto.golpe_cayo.connect(func(_p: Vector3, _n: int) -> void:
			if _cayo_bruto < 0.0:
				_cayo_bruto = _ahora())
	elif unidad.tipo == DEMONIO:
		_demonio = unidad
		_demonio.golpe_cayo.connect(func(_p: Vector3, _n: int) -> void:
			if _cayo_demonio < 0.0:
				_cayo_demonio = _ahora())
	else:
		return
	unidad.set_physics_process(false)


## Lo que mide cada uno en el mundo: el cuadro entero y la parte que ocupa el
## personaje, que es la que tiene que dar la altura del tipo.
func _medir() -> void:
	for unidad: Unidad3D in [_bruto, _demonio]:
		var sprite: AnimatedSprite3D = unidad._sprite
		var tipo := unidad.tipo
		print("%-8s pixel=%.4f  cuadro=%.2f m  personaje=%.2f m  pies y=%.2f  barra=%.1f m" % [
			tipo.nombre, sprite.pixel_size, tipo.lado_frame * sprite.pixel_size,
			tipo.alto_util_px * sprite.pixel_size, unidad.global_position.y,
			unidad.punto_cabeza().y])


func _foto(t: float, que: String, nombre: String) -> void:
	root.get_texture().get_image().save_png("user://" + nombre)
	print("%5.2f  %-27s -> %s" % [t, que, nombre])
	_paso += 1


func _ahora() -> float:
	return (Time.get_ticks_msec() - _inicio_ms) / 1000.0


func _grupo(bando: Unidad3D.Bando, tipo: TipoSoldado, pos: Vector3) -> GrupoUnidades:
	var grupo := GrupoUnidades.new()
	grupo.bando = bando
	grupo.tipo = tipo
	grupo.cantidad = 1
	grupo.x_min = pos.x
	grupo.x_max = pos.x
	grupo.z_min = pos.z
	grupo.z_max = pos.z
	return grupo
