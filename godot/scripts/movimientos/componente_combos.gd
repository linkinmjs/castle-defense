class_name ComponenteCombos
extends Node
## Corre los movimientos del healer: decide cual sale con cada boton, cuenta
## el combo, lleva los relojes y avisa por senales.
##
## El jugador tiene tres botones (ligera, pesada, salto) y ninguno apunta: a
## quien le llega cada movimiento lo decide Apuntado mirando lo que el healer
## tiene enfrente. Lo que el jugador elige es el orden, y este componente es el
## que recuerda que vino antes.
##
## Todos los relojes corren en _physics_process, al paso del healer: una
## ventana de 0.7 s tiene que durar lo mismo a 30 que a 144 fps, y las pruebas
## tienen que poder medirla en ticks.
##
## No depende de un healer en particular. Lo que sepa hacer de mas (animar un
## movimiento, mostrar la carga de una plegaria) se le pregunta con has_method,
## el corte por dano sale de su senal vida_cambio y el aterrizaje se descubre
## mirando esta_en_el_aire() en cada tick.

signal movimiento_usado(mov: Movimiento, objetivo: Node3D, efectivo: float)
signal movimiento_fallo(mov: Movimiento, motivo: String)
## cuenta 0 = el combo se corto (y el nombre llega vacio).
signal combo_cambio(cuenta: int, nombre: String)
## Por que se corto: &"dano", &"vacio", &"tiempo" o &"remate". Le sirve al HUD
## para festejar un remate y no un golpe recibido.
signal combo_cortado(motivo: StringName)
## Texto corto de como salio lo que conecto ("+18", "Reanimado"). Con
## movimiento_usado se sabe que salio; con esto, que mostrar.
signal aviso(texto: String)
signal loadout_cambio

const LIGERA := &"ligera"
const PESADA := &"pesada"
## Segundos para encadenar el siguiente movimiento despues de conectar uno.
const VENTANA := 0.7
## Solo importa el final de la secuencia (la previa mas larga es de dos pasos):
## sin tope, un combo largo acumularia historia que nadie lee.
const MAX_SECUENCIA := 8
## Motivo de movimiento_fallo para un golpe al aire. Es el unico fallo que no
## es un rechazo: el HUD lo muestra mas bajo y la telemetria lo cuenta aparte.
const EN_VACIO := "En vacio"

@export var movimientos: Array[Movimiento] = []

var _healer: Node3D
## Segundos de enfriamiento que le quedan a cada movimiento, por nombre.
var _enfriamientos: Dictionary[String, float] = {}
## Segundos que le quedan bloqueados a cada boton.
var _recuperacion: Dictionary[StringName, float] = {}
var _secuencia: Array[StringName] = []
var _ventana: float = 0.0
var _cuenta: int = 0
var _ultimo_objetivo: Unidad3D = null
var _wind_up_mov: Movimiento = null
var _wind_up_restante: float = 0.0
var _pendiente_aterrizaje: Movimiento = null
var _en_el_aire_antes: bool = false
var _impulso_mov: MovimientoImpulso = null
var _impulso_restante: float = 0.0
var _impulso_curo: bool = false
var _vida_previa: float = 0.0


func _ready() -> void:
	_healer = get_parent() as Node3D
	if _healer == null:
		push_error("ComponenteCombos tiene que colgar del healer")
		set_physics_process(false)
		return
	if _healer.has_signal(&"vida_cambio"):
		_healer.connect(&"vida_cambio", _on_vida_cambio)
	var vida: Variant = _healer.get(&"vida")
	_vida_previa = float(vida) if vida != null else 0.0
	_en_el_aire_antes = _esta_en_el_aire()


func _physics_process(delta: float) -> void:
	if _healer == null:
		return
	_descontar(_enfriamientos, delta)
	_descontar(_recuperacion, delta)
	if not _healer_en_pie():
		# Tirado en el suelo, el healer no termina de rezar ni cae curando: lo
		# que estaba a medio salir se pierde sin cobrar. El combo ya lo corto el
		# golpe que lo tiro.
		_cancelar_en_curso()
	_avanzar_ventana(delta)
	_avanzar_wind_up(delta)
	_avanzar_aterrizaje()
	_avanzar_impulso(delta)


# --- API ---------------------------------------------------------------------

## Aprieta un boton (&"ligera" o &"pesada"). Devuelve true si el movimiento
## salio o quedo en marcha (cargando o esperando el suelo).
##
## Lo que pasa por apretar de mas (algo en curso, la recuperacion del boton) se
## ignora en silencio: avisarlo llenaria el HUD de ruido mientras el jugador
## aporrea. Lo que si le sirve saber (enfriamiento, mana, un rechazo, un golpe
## al aire) se avisa por movimiento_fallo.
func pulsar(entrada: StringName) -> bool:
	if _healer == null or not _healer_en_pie():
		return false
	if _wind_up_mov != null:
		return false
	var mov := resolver(entrada)
	if mov == null:
		return false
	if recuperacion_restante(entrada) > 0.0:
		return false
	if mov.al_aterrizar and _pendiente_aterrizaje != null:
		return false
	if enfriamiento_restante(mov) > 0.0:
		movimiento_fallo.emit(mov, "%s en enfriamiento" % mov.nombre)
		return false
	if not _validar(mov):
		return false

	if mov.wind_up > 0.0:
		_wind_up_mov = mov
		_wind_up_restante = mov.wind_up
		if _healer.has_method(&"iniciar_wind_up"):
			_healer.call(&"iniciar_wind_up", mov)
		return true
	if mov.al_aterrizar:
		_pendiente_aterrizaje = mov
		_en_el_aire_antes = _esta_en_el_aire()
		return true
	return _ejecutar(mov)


## El movimiento que saldria con ese boton ahora, sin ejecutarlo.
##
## Califican los equipados con esa entrada, el mismo estado en el aire que el
## healer, una secuencia previa que coincide con el final del combo en curso y,
## si lo piden, un derribado al frente. Gana el de mayor especificidad; a
## igualdad, el primero de la lista.
func resolver(entrada: StringName) -> Movimiento:
	if _healer == null:
		return null
	var en_el_aire := _esta_en_el_aire()
	var hay_derribado := Apuntado.derribado_al_frente(_healer) != null
	var mejor: Movimiento = null
	for mov in movimientos:
		if mov == null or mov.entrada != entrada or mov.en_el_aire != en_el_aire:
			continue
		if mov.requiere_derribado and not hay_derribado:
			continue
		if not _termina_en(mov.secuencia_previa):
			continue
		if mejor == null or mov.especificidad() > mejor.especificidad():
			mejor = mov
	return mejor


## Corta el combo: lo proximo que se apriete arranca de cero. El motivo es
## &"dano", &"vacio", &"tiempo" o &"remate".
func cortar_combo(motivo: StringName) -> void:
	var habia := _cuenta > 0 or not _secuencia.is_empty()
	_limpiar_combo()
	if habia:
		combo_cambio.emit(0, "")
		combo_cortado.emit(motivo)


## Reemplaza lo equipado y deja todo como recien empezado: sin enfriamientos,
## sin combo y sin nada a medio salir. Un encuentro puede entregar solo Toque
## al principio y sumar el resto despues.
func equipar(lista: Array[Movimiento]) -> void:
	var habia_combo := _cuenta > 0 or not _secuencia.is_empty()
	movimientos = lista.duplicate()
	_enfriamientos.clear()
	_recuperacion.clear()
	_limpiar_combo()
	_cancelar_en_curso()
	loadout_cambio.emit()
	if habia_combo:
		combo_cambio.emit(0, "")


## Buscar por nombre y no por posicion: el loadout cambia entre encuentros.
func movimiento_por_nombre(nombre: String) -> Movimiento:
	for mov in movimientos:
		if mov != null and mov.nombre == nombre:
			return mov
	return null


## Equipado, sin enfriamiento y con mana para pagarlo. No mira si hay objetivo
## ni la recuperacion del boton: es lo que el HUD necesita para pintarlo listo.
func disponible(nombre: String) -> bool:
	var mov := movimiento_por_nombre(nombre)
	return mov != null and enfriamiento_restante(mov) <= 0.0 and _mana() >= mov.costo


func enfriamiento_restante(mov: Movimiento) -> float:
	if mov == null:
		return 0.0
	return _enfriamientos.get(mov.nombre, 0.0)


## 0.0 = listo, 1.0 = recien usado. Para dibujar el HUD.
func fraccion_enfriamiento(mov: Movimiento) -> float:
	if mov == null or mov.enfriamiento <= 0.0:
		return 0.0
	return clampf(enfriamiento_restante(mov) / mov.enfriamiento, 0.0, 1.0)


func recuperacion_restante(entrada: StringName) -> float:
	return _recuperacion.get(entrada, 0.0)


func cuenta_combo() -> int:
	return _cuenta


## Los botones del combo en curso, del mas viejo al mas nuevo. Es una copia.
func secuencia() -> Array[StringName]:
	return _secuencia.duplicate()


## Segundos que quedan para encadenar; 0 si no hay combo.
func ventana_restante() -> float:
	return _ventana


## El ultimo aliado que toco el combo en curso, o null.
func ultimo_objetivo() -> Unidad3D:
	if not is_instance_valid(_ultimo_objetivo) or not _ultimo_objetivo.esta_viva():
		return null
	return _ultimo_objetivo


func esta_en_wind_up() -> bool:
	return _wind_up_mov != null


## Lo que esta cargando o esperando el suelo, o null: para que el HUD muestre
## que esta por salir.
func movimiento_en_curso() -> Movimiento:
	return _wind_up_mov if _wind_up_mov != null else _pendiente_aterrizaje


## Cuanto le falta a lo que esta en curso, de 0 (recien apretado) a 1 (sale
## ya); 0 si no hay nada en curso. Es lo que llena la barra de carga del HUD.
##
## La plegaria se mide contra su wind_up. La caida no tiene un tiempo fijo:
## sale al tocar el suelo, asi que se mide sobre la parabola del salto con la
## velocidad vertical del healer, que baja a ritmo constante: subiendo a
## pleno es 0, en la cima 0.5 y al llegar al piso 1. Asi la barra se llena
## justo cuando la caida cura, sin guardar un reloj mas. Al healer se le
## pregunta por nombre, como en el resto del componente: sin esos datos, 0.
func progreso_en_curso() -> float:
	if _wind_up_mov != null:
		if _wind_up_mov.wind_up <= 0.0:
			return 1.0
		return clampf(1.0 - _wind_up_restante / _wind_up_mov.wind_up, 0.0, 1.0)
	if _pendiente_aterrizaje == null or _healer == null:
		return 0.0
	var velocidad: Variant = _healer.get(&"velocity")
	var gravedad: Variant = _healer.get(&"gravedad")
	var altura: Variant = _healer.get(&"altura_salto")
	if not (velocidad is Vector3) or gravedad == null or altura == null:
		return 0.0
	var inicial := sqrt(maxf(2.0 * float(gravedad) * float(altura), 0.0))
	if inicial <= 0.0:
		return 0.0
	return clampf((inicial - (velocidad as Vector3).y) / (2.0 * inicial), 0.0, 1.0)


# --- Ejecucion ---------------------------------------------------------------

## Mana y objetivo. Se revisan al apretar y otra vez al soltar un movimiento
## diferido, porque mientras cargaba el mundo siguio andando.
func _validar(mov: Movimiento) -> bool:
	if _mana() < mov.costo:
		movimiento_fallo.emit(mov, "Sin mana")
		return false
	var bloqueo := mov.motivo_bloqueo(_healer)
	if bloqueo == Movimiento.SIN_OBJETIVO:
		_errar(mov)
		return false
	if bloqueo != "":
		movimiento_fallo.emit(mov, bloqueo)
		return false
	return true


## Aplica el movimiento y, si conecto, lo cobra y lo suma al combo. El costo
## se cobra despues de ejecutar para que lo que no conecta no cueste nada.
func _ejecutar(mov: Movimiento) -> bool:
	var resultado := mov.ejecutar(_healer)
	if not resultado.get("conecto", false):
		# Algo cambio entre el chequeo y el golpe: cuenta como uno al aire.
		_errar(mov)
		return false

	_healer.gastar_mana(mov.costo)
	if mov.enfriamiento > 0.0:
		_enfriamientos[mov.nombre] = mov.enfriamiento
	if mov.recuperacion > 0.0:
		_recuperacion[mov.entrada] = mov.recuperacion
	_secuencia.append(mov.entrada)
	if _secuencia.size() > MAX_SECUENCIA:
		_secuencia.remove_at(0)
	_ventana = VENTANA
	_cuenta += 1
	var objetivo := resultado.get("objetivo") as Node3D
	if objetivo is Unidad3D:
		_ultimo_objetivo = objetivo as Unidad3D
	if mov is MovimientoImpulso:
		_seguir_impulso(mov as MovimientoImpulso)
	_animar(mov)

	movimiento_usado.emit(mov, objetivo, float(resultado.get("efectivo", 0.0)))
	var texto: String = resultado.get("aviso", "")
	if texto != "":
		aviso.emit(texto)
	combo_cambio.emit(_cuenta, mov.nombre)
	if mov.termina_combo:
		cortar_combo(&"remate")
	return true


## Golpe al aire: la animacion sale igual (el jugador tiene que ver que
## apreto), pero no cobra, no suma y corta el combo.
func _errar(mov: Movimiento) -> void:
	_animar(mov)
	cortar_combo(&"vacio")
	movimiento_fallo.emit(mov, EN_VACIO)


## Suelta un movimiento que estaba cargando o esperando el suelo.
func _lanzar_diferido(mov: Movimiento) -> void:
	if _healer_en_pie() and _validar(mov):
		_ejecutar(mov)


func _seguir_impulso(impulso: MovimientoImpulso) -> void:
	if impulso.cura_al_cruzar <= 0.0:
		return
	_impulso_mov = impulso
	_impulso_restante = impulso.duracion
	_impulso_curo = false


# --- Relojes -----------------------------------------------------------------

func _avanzar_ventana(delta: float) -> void:
	# Con algo cargando, la ventana no corre: el jugador apreto a tiempo, y
	# cortarle el combo porque la plegaria tarda seria castigar el wind-up dos
	# veces.
	if _ventana <= 0.0 or movimiento_en_curso() != null:
		return
	_ventana -= delta
	if _ventana <= 0.0:
		cortar_combo(&"tiempo")


func _avanzar_wind_up(delta: float) -> void:
	if _wind_up_mov == null:
		return
	_wind_up_restante -= delta
	if _wind_up_restante > 0.0:
		return
	var mov := _wind_up_mov
	_wind_up_mov = null
	_wind_up_restante = 0.0
	_lanzar_diferido(mov)


## El healer no avisa cuando toca el suelo: se lo descubre comparando con el
## tick anterior.
func _avanzar_aterrizaje() -> void:
	var en_el_aire := _esta_en_el_aire()
	var aterrizo := _en_el_aire_antes and not en_el_aire
	_en_el_aire_antes = en_el_aire
	if not aterrizo or _pendiente_aterrizaje == null:
		return
	var mov := _pendiente_aterrizaje
	_pendiente_aterrizaje = null
	_lanzar_diferido(mov)


## Mientras dura el envion, cura una sola vez al primer herido que cruza. Corre
## despues del healer en el mismo tick, asi que mide la posicion ya movida.
func _avanzar_impulso(delta: float) -> void:
	if _impulso_mov == null:
		return
	if not _impulso_curo:
		var resultado := _impulso_mov.cruzar(_healer)
		if resultado.get("conecto", false):
			_impulso_curo = true
			var objetivo := resultado.get("objetivo") as Unidad3D
			if objetivo != null:
				_ultimo_objetivo = objetivo
			var texto: String = resultado.get("aviso", "")
			if texto != "":
				aviso.emit(texto)
	_impulso_restante -= delta
	if _impulso_restante <= 0.0 or _impulso_curo:
		_impulso_mov = null


static func _descontar(relojes: Dictionary, delta: float) -> void:
	for clave: Variant in relojes.keys():
		relojes[clave] -= delta
		if relojes[clave] <= 0.0:
			relojes.erase(clave)


# --- Estado ------------------------------------------------------------------

func _limpiar_combo() -> void:
	_secuencia.clear()
	_cuenta = 0
	_ventana = 0.0
	_ultimo_objetivo = null


func _cancelar_en_curso() -> void:
	_wind_up_mov = null
	_wind_up_restante = 0.0
	_pendiente_aterrizaje = null
	_impulso_mov = null
	_impulso_restante = 0.0


## Si la secuencia en curso termina con `previa`.
func _termina_en(previa: Array[StringName]) -> bool:
	var desde := _secuencia.size() - previa.size()
	if desde < 0:
		return false
	for i in previa.size():
		if _secuencia[desde + i] != previa[i]:
			return false
	return true


# --- Healer (por duck typing) -------------------------------------------------

func _animar(mov: Movimiento) -> void:
	if _healer.has_method(&"animar_movimiento"):
		_healer.call(&"animar_movimiento", mov)


func _healer_en_pie() -> bool:
	return not _healer.has_method(&"esta_viva") or _healer.call(&"esta_viva")


func _esta_en_el_aire() -> bool:
	return _healer.has_method(&"esta_en_el_aire") and _healer.call(&"esta_en_el_aire")


func _mana() -> float:
	if _healer == null:
		return 0.0
	var mana: Variant = _healer.get(&"mana")
	return float(mana) if mana != null else 0.0


## Un golpe corta el combo: no se encadena mientras te pegan. El healer no
## avisa del golpe en si, asi que se lo detecta por la vida que baja.
func _on_vida_cambio(actual: float, _maximo: float) -> void:
	if actual < _vida_previa:
		cortar_combo(&"dano")
	_vida_previa = actual
