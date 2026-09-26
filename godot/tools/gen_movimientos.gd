extends SceneTree
## Genera los movimientos del healer: que sale con cada boton y en que punto
## del combo.
##
## Estan escritos como codigo por la misma razon que los encuentros: lo que
## importa de la tabla es comparar filas entre si (quien gana con que
## secuencia), y eso se lee de corrido aca y no saltando entre recursos en el
## inspector. La resolucion la explica Movimiento.especificidad():
##
##   []    + L  -> Toque        [L]    + L -> Vendaje
##   []    + P  -> Plegaria     [L]    + P -> Bendicion
##   [L,L] + P  -> Oleada (remate)
##   P con un derribado al frente -> Reanimar, venga de donde venga
##   aire + L   -> Impulso      aire + P   -> Caida sanadora
##
## Los iconos salen de extraer_ui.gd. Si todavia no se extrajeron (o no se
## importaron), el movimiento se guarda sin icono y el HUD cae al nombre:
##   godot --headless --path godot --script res://tools/extraer_ui.gd
##   godot --headless --path godot --import
##   godot --headless --path godot --script res://tools/gen_movimientos.gd

const DIR := "res://resources/movimientos"
const DIR_ICONOS := "res://assets/ui/habilidades"

const LIGERA := &"ligera"
const PESADA := &"pesada"

## La pesada compromete el doble que la ligera: apretarla por las dudas cuesta.
const RECUPERACION_LIGERA := 0.3
const RECUPERACION_PESADA := 0.6

## Un color por familia, para que el HUD agrupe sin hacer leer: verde cura a
## uno, dorado cura a varios, turquesa protege, naranja levanta, celeste mueve.
const VERDE := Color("5fbf5f")
const DORADO := Color("e0b84a")
const TURQUESA := Color("6fd3c7")
const NARANJA := Color("e8873a")
const CELESTE := Color("7cc4f0")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_toque()
	_vendaje()
	_oleada()
	_bendicion()
	_plegaria()
	_reanimar()
	_impulso()
	_caida()
	print("movimientos generados")
	quit()


## La cura de todos los dias: barata, sin casi enfriamiento, a uno solo.
func _toque() -> void:
	var m := MovimientoCurar.new()
	_base(m, "Toque", LIGERA, 10.0, 0.35, VERDE,
		"Curas 18 al que tenes enfrente: primero al que sangra, despues al mas golpeado.")
	m.cantidad = 18.0
	_guardar(m, "toque")


## El segundo toque sobre el mismo paciente trata la causa.
func _vendaje() -> void:
	var m := MovimientoCurar.new()
	_base(m, "Vendaje", LIGERA, 10.0, 0.35, VERDE,
		"Segunda ligera sobre el mismo: le curas 18 y le cortas el sangrado.")
	m.secuencia_previa = [LIGERA] as Array[StringName]
	m.cantidad = 18.0
	m.corta_sangrado = true
	m.preferir_ultimo_objetivo = true
	_guardar(m, "vendaje")


## El remate: la unica cura grande que no se carga, a cambio de haber armado
## el combo entero.
func _oleada() -> void:
	var m := MovimientoArea.new()
	_base(m, "Oleada", PESADA, 35.0, 6.0, DORADO,
		"Remate de ligera, ligera, pesada: curas 30 a todos los que tenes a 4 m.")
	m.secuencia_previa = [LIGERA, LIGERA] as Array[StringName]
	m.termina_combo = true
	m.forma = MovimientoArea.Forma.ALREDEDOR
	m.cantidad = 30.0
	m.radio = 4.0
	_guardar(m, "oleada")


## Mismos numeros que la Bendicion de las habilidades: cambia como se llega,
## no que hace.
func _bendicion() -> void:
	var m := MovimientoBendicion.new()
	_base(m, "Bendicion", PESADA, 30.0, 8.0, TURQUESA,
		"Pesada despues de una ligera: bendecis al que tocaste, 35% menos de dano y mas ritmo por 8 s.")
	m.secuencia_previa = [LIGERA] as Array[StringName]
	m.efecto = "shield"
	m.duracion = 8.0
	m.reduccion = 0.35
	m.bonus = 0.30
	_guardar(m, "bendicion")


## La cura grande sin combo se paga con medio segundo quieto y expuesto.
func _plegaria() -> void:
	var m := MovimientoArea.new()
	_base(m, "Plegaria", PESADA, 30.0, 1.5, DORADO,
		"Pesada sola: rezas medio segundo y curas 40 a todos los que tenes adelante.")
	m.wind_up = 0.5
	m.forma = MovimientoArea.Forma.CAJA_FRONTAL
	m.cantidad = 40.0
	_guardar(m, "plegaria")


## Un cuerpo en el suelo manda sobre cualquier combo (ver especificidad).
func _reanimar() -> void:
	var m := MovimientoReanimar.new()
	_base(m, "Reanimar", PESADA, 40.0, 4.0, NARANJA,
		"Pesada con un caido adelante: lo levantas, venga de donde venga el combo.")
	m.requiere_derribado = true
	_guardar(m, "reanimar")


## Movilidad: siempre conecta. La cura al paso es un premio, no el objetivo.
func _impulso() -> void:
	var m := MovimientoImpulso.new()
	_base(m, "Impulso", LIGERA, 12.0, 2.5, CELESTE,
		"Ligera en el aire: te lanzas hacia adelante y curas 12 al primer herido que cruzas.")
	m.en_el_aire = true
	m.animacion = "jump"
	m.fuerza = 9.5
	m.duracion = 0.22
	m.cura_al_cruzar = 12.0
	_guardar(m, "impulso")


## Se aprieta en el aire y se resuelve al tocar el suelo. No hace dano: el
## aturdido es para frenar a los que estan encima, y solo pega a quien sepa
## aturdirse (hoy nadie).
func _caida() -> void:
	var m := MovimientoArea.new()
	_base(m, "Caida sanadora", PESADA, 30.0, 5.0, DORADO,
		"Pesada en el aire: al tocar el suelo curas 25 a todos los que tenes a 3 m.")
	m.en_el_aire = true
	m.al_aterrizar = true
	m.animacion = "jump"
	m.forma = MovimientoArea.Forma.ALREDEDOR
	m.cantidad = 25.0
	m.radio = 3.0
	m.aturde_radio = 2.0
	m.aturde_segundos = 0.5
	_guardar(m, "caida")


# --- Ayudantes ----------------------------------------------------------------

func _base(m: Movimiento, nombre: String, entrada: StringName, costo: float,
		enfriamiento: float, color: Color, descripcion: String) -> void:
	m.nombre = nombre
	m.entrada = entrada
	m.costo = costo
	m.enfriamiento = enfriamiento
	m.recuperacion = RECUPERACION_PESADA if entrada == PESADA else RECUPERACION_LIGERA
	m.color = color
	m.descripcion = descripcion


## El icono es opcional: sin extraer_ui.gd (o sin importar) el movimiento se
## guarda igual y el HUD muestra el nombre.
func _icono(archivo: String) -> Texture2D:
	var ruta := "%s/%s.png" % [DIR_ICONOS, archivo]
	return load(ruta) if ResourceLoader.exists(ruta) else null


func _guardar(m: Movimiento, archivo: String) -> void:
	m.icono = _icono(archivo)
	if m.icono == null:
		push_warning("sin icono para %s: correr extraer_ui.gd e importar" % archivo)
	var ruta := "%s/%s.tres" % [DIR, archivo]
	var error := ResourceSaver.save(m, ruta)
	if error != OK:
		push_error("no se pudo guardar %s (error %d)" % [ruta, error])
		return
	m.take_over_path(ruta)
	print("  %s" % ruta)
