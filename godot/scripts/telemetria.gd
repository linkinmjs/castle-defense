class_name Telemetria
extends Node
## Anota lo que pasa en un encuentro para poder compararlo con el intento
## siguiente.
##
## No sirve para puntuar al jugador sino para responder si esta aprendiendo a
## hacer triaje o solo reaccionando a cooldowns. Por eso mide conducta
## (a quien curo, cuanto tardo, que dejo sin atender) y no solo resultado.
##
## Es un Node sin nada de interfaz: escucha señales y publica un Dictionary.
## El HUD lo consume, nunca al reves, asi el modelo de combate sigue corriendo
## en las pruebas headless sin arrastrar la UI.

## Se cerro un encuentro y el resumen esta listo.
signal encuentro_cerrado(resumen: Dictionary)

## Cada cuanto se anota donde esta el frente.
const INTERVALO_FRENTE := 2.0

var _battle: Node
var _healer: Node
var _habilidades: ComponenteHabilidades

var _encuentro_id: StringName = &""
var _semilla: int = 0
var _duracion: float = 0.0
var _proxima_muestra: float = 0.0
var _abierto: bool = false
## Como termino. Se guarda al cerrar para que la observacion causal pueda
## distinguir "no perdiste a nadie" de "no perdiste a nadie pero perdiste".
var _victoria: bool = false

var _curacion_emitida: float = 0.0
var _curacion_efectiva: float = 0.0
var _mana_gastado: float = 0.0
var _segundos_mana_al_tope: float = 0.0

var _caidas: int = 0
var _reanimaciones: int = 0
var _muertes: int = 0
var _muertes_por_causa: Dictionary = {}

var _sangrados: int = 0
var _sangrados_estabilizados: int = 0
var _sangrados_sin_tratar: int = 0
var _tiempo_total_estabilizar: float = 0.0

var _usos_por_habilidad: Dictionary = {}
var _frente_muestras: Array[Vector2] = []
var _eventos: Array[Dictionary] = []


# --- Enganches ----------------------------------------------------------------

func observar_batalla(battle: Node) -> void:
	_battle = battle
	battle.encuentro_iniciado.connect(_on_encuentro_iniciado)
	battle.unidad_creada.connect(observar_unidad)
	battle.batalla_terminada.connect(_on_batalla_terminada)


func observar_healer(healer: Node) -> void:
	_healer = healer
	_habilidades = healer.get_node("Habilidades")
	_habilidades.habilidad_usada.connect(_on_habilidad_usada)
	healer.cayo.connect(func() -> void: registrar(&"healer_cayo"))


## Solo importan los aliados: los enemigos no son pacientes.
func observar_unidad(unidad: Unidad3D) -> void:
	if unidad.bando != Unidad3D.Bando.ALIADO:
		return
	unidad.curada.connect(_on_curada)
	unidad.derribada.connect(_on_derribada)
	unidad.murio.connect(_on_murio)
	unidad.reanimada.connect(func() -> void:
		_reanimaciones += 1
		registrar(&"reanimacion", {"unidad": unidad.nombre_unidad}))
	unidad.sangrado_iniciado.connect(func() -> void:
		_sangrados += 1
		registrar(&"sangrado", {"unidad": unidad.nombre_unidad}))
	unidad.sangrado_cortado.connect(func(segundos: float) -> void:
		_sangrados_estabilizados += 1
		_tiempo_total_estabilizar += segundos
		registrar(&"estabilizacion", {
			"unidad": unidad.nombre_unidad, "segundos": segundos,
		}))
	unidad.sangrado_expiro.connect(func(segundos: float) -> void:
		_sangrados_sin_tratar += 1
		registrar(&"sangrado_sin_tratar", {
			"unidad": unidad.nombre_unidad, "segundos": segundos,
		}))


## Con la fisica y no con el frame: la duracion y el tiempo con mana lleno
## tienen que medir el mismo encuentro que juega la batalla, y la batalla
## corre sus relojes a ese paso.
func _physics_process(delta: float) -> void:
	if not _abierto:
		return
	_duracion += delta

	if _healer != null and is_instance_valid(_healer) \
			and _healer.mana >= _healer.mana_maximo - 0.01:
		# Tiempo con el mana lleno: si es mucho, el jugador esta esperando en
		# vez de intervenir, y eso cambia que consejo tiene sentido darle.
		_segundos_mana_al_tope += delta

	if _battle != null and is_instance_valid(_battle) and _duracion >= _proxima_muestra:
		_proxima_muestra += INTERVALO_FRENTE
		_frente_muestras.append(Vector2(_duracion, _battle.frente_x()))


# --- Anotaciones --------------------------------------------------------------

func registrar(evento: StringName, datos: Dictionary = {}) -> void:
	if not _abierto:
		return
	var fila := datos.duplicate()
	fila["t"] = _duracion
	fila["evento"] = evento
	_eventos.append(fila)


func _on_encuentro_iniciado(encuentro: Encuentro, semilla: int, _indice: int) -> void:
	_reiniciar()
	_encuentro_id = encuentro.id if encuentro != null else &""
	_semilla = semilla
	_abierto = true


func _on_curada(solicitada: float, efectiva: float) -> void:
	_curacion_emitida += solicitada
	_curacion_efectiva += efectiva


func _on_habilidad_usada(habilidad: Habilidad, _aviso: String) -> void:
	_usos_por_habilidad[habilidad.nombre] = _usos_por_habilidad.get(habilidad.nombre, 0) + 1
	_mana_gastado += habilidad.costo
	registrar(&"habilidad", {"nombre": habilidad.nombre})


func _on_derribada(unidad: Unidad3D) -> void:
	_caidas += 1
	registrar(&"caida", {
		"unidad": unidad.nombre_unidad,
		"causa": unidad.causa_caida,
	})


## Al anotar una muerte se guarda ademas que tenia el jugador a mano. Es lo que
## despues permite decir "lo perdiste mientras Estabilizar estaba lista" en vez
## de solo "lo perdiste".
func _on_murio(unidad: Unidad3D) -> void:
	_muertes += 1
	var causa: StringName = unidad.causa_muerte
	_muertes_por_causa[causa] = _muertes_por_causa.get(causa, 0) + 1
	registrar(&"muerte", {
		"unidad": unidad.nombre_unidad,
		"causa": causa,
		"fuente": unidad.fuente_ultimo_dano,
		"curar_disponible": _disponible("Curar"),
		"estabilizar_disponible": _disponible("Estabilizar"),
		"reanimar_disponible": _disponible("Reanimar"),
	})


## Si la habilidad estaba equipada, sin enfriamiento y con mana para pagarla.
func _disponible(nombre: String) -> bool:
	if _habilidades == null or _healer == null or not is_instance_valid(_healer):
		return false
	var habilidad := _habilidades.habilidad_por_nombre(nombre)
	if habilidad == null:
		return false
	return _habilidades.enfriamiento_restante(habilidad) <= 0.0 \
		and _healer.mana >= habilidad.costo


func _on_batalla_terminada(victoria: bool) -> void:
	cerrar(victoria)


func cerrar(victoria: bool) -> void:
	if not _abierto:
		return
	_abierto = false
	_victoria = victoria
	encuentro_cerrado.emit(resumen(victoria))


func _reiniciar() -> void:
	_duracion = 0.0
	_proxima_muestra = 0.0
	_victoria = false
	_curacion_emitida = 0.0
	_curacion_efectiva = 0.0
	_mana_gastado = 0.0
	_segundos_mana_al_tope = 0.0
	_caidas = 0
	_reanimaciones = 0
	_muertes = 0
	_muertes_por_causa.clear()
	_sangrados = 0
	_sangrados_estabilizados = 0
	_sangrados_sin_tratar = 0
	_tiempo_total_estabilizar = 0.0
	_usos_por_habilidad.clear()
	_frente_muestras.clear()
	_eventos.clear()


# --- Salida -------------------------------------------------------------------

## Sin argumento usa el desenlace ya registrado, si el encuentro se cerro.
func resumen(victoria: bool = false) -> Dictionary:
	victoria = victoria or _victoria
	var desperdiciada := maxf(_curacion_emitida - _curacion_efectiva, 0.0)
	var promedio_estabilizar := 0.0
	if _sangrados_estabilizados > 0:
		promedio_estabilizar = _tiempo_total_estabilizar / _sangrados_estabilizados

	return {
		"encuentro_id": _encuentro_id,
		"semilla": _semilla,
		"duracion": _duracion,
		"victoria": victoria,

		"curacion_emitida": _curacion_emitida,
		"curacion_efectiva": _curacion_efectiva,
		"curacion_desperdiciada": desperdiciada,
		"fraccion_desperdiciada": desperdiciada / _curacion_emitida if _curacion_emitida > 0.0 else 0.0,

		"mana_gastado": _mana_gastado,
		"mana_sin_usar": _healer.mana if _healer != null and is_instance_valid(_healer) else 0.0,
		"segundos_mana_al_tope": _segundos_mana_al_tope,

		"caidas": _caidas,
		"reanimaciones": _reanimaciones,
		"muertes": _muertes,
		"muertes_por_causa": _muertes_por_causa.duplicate(),

		"sangrados": _sangrados,
		"sangrados_estabilizados": _sangrados_estabilizados,
		"sangrados_sin_tratar": _sangrados_sin_tratar,
		"tiempo_hasta_estabilizar": promedio_estabilizar,

		"usos_por_habilidad": _usos_por_habilidad.duplicate(),
		"frente_muestras": _frente_muestras.duplicate(),
	}


func eventos() -> Array[Dictionary]:
	return _eventos.duplicate()


## Una sola observacion, la primera que aplica de una lista ordenada por lo que
## mas le conviene revisar al jugador.
##
## Una sola y no todas: un informe con seis consejos no se lee, y si se lee no
## deja claro por donde empezar. Habla de conducta, no de resultado, porque el
## objetivo es que salga con una hipotesis para el proximo intento.
func observacion_causal() -> String:
	var r := resumen()

	# 1. Lo mas caro: perder gente por una causa que se podia cortar.
	var por_sangrado := _muertes_evitables(&"sangrado", "estabilizar_disponible")
	if por_sangrado > 0:
		return "%s por sangrado mientras Estabilizar estaba lista. Cortar la causa frena el dano que todavia no ocurrio." % 			_contar(por_sangrado, "Perdiste un soldado", "Perdiste %d soldados")

	# 2. Dejar morir a alguien tirado teniendo con que levantarlo.
	var sin_atencion := _muertes_evitables(&"sin_atencion", "reanimar_disponible")
	if sin_atencion > 0:
		return "%s en el suelo con Reanimar disponible. Un derribado tiene una ventana corta y se agota sola." % 			_contar(sin_atencion, "Se te murio uno", "Se te murieron %d")

	# 3. Derribados que nadie fue a buscar, aunque no hubiera con que.
	var abandonados: int = _muertes_por_causa.get(&"sin_atencion", 0)
	if abandonados > 0:
		return "%s esperando que alguien llegara. Cuando alguien cae, el reloj corre." % 			_contar(abandonados, "Un soldado murio", "%d soldados murieron")

	# 4. Curar sin mirar a quien.
	if r["fraccion_desperdiciada"] > 0.25 and r["curacion_emitida"] > 60.0:
		return "Se desperdicio el %d%% de tu curacion: llegaste a soldados que ya estaban casi sanos." % 			(r["fraccion_desperdiciada"] * 100.0)

	# 5. Sangrados que se agotaron solos, sin muertos de por medio.
	if _sangrados_sin_tratar > 0:
		return "%s sin tratar. El sangrado sigue restando vida aunque el soldado aguante." % 			_contar(_sangrados_sin_tratar, "Quedo un sangrado", "Quedaron %d sangrados")

	# 6. Ganar sin haber hecho nada. El documento lo nombra como señal de
	# alarma: si el encuentro se resuelve solo, no enseño nada.
	if _usos_por_habilidad.is_empty() and r["duracion"] > 5.0:
		return "Terminaste el encuentro sin usar una sola habilidad. Si la linea se sostiene sola, todavia no hay una decision que tomar."

	# 7. Esperar en vez de intervenir.
	if r["duracion"] > 10.0 and _segundos_mana_al_tope > r["duracion"] * 0.3:
		return "Pasaste %.0f s con el mana lleno. Mana guardado no cura a nadie." % 			_segundos_mana_al_tope

	# 8. Nada que corregir: se nombra que salio bien, que tambien enseña.
	if r["victoria"]:
		if _sangrados_estabilizados > 0:
			return "Cortaste %d sangrados en %.1f s promedio y no perdiste a nadie por esa causa." % [
				_sangrados_estabilizados, r["tiempo_hasta_estabilizar"]]
		if _curacion_emitida > 0.0:
			return "Aprovechaste el %d%% de tu curacion." % 				((1.0 - r["fraccion_desperdiciada"]) * 100.0)
	return ""


## Muertes por esa causa que ocurrieron teniendo la herramienta a mano.
func _muertes_evitables(causa: StringName, herramienta: String) -> int:
	var total := 0
	for evento in _eventos:
		if evento.get("evento", &"") != &"muerte":
			continue
		if evento.get("causa", &"") == causa and evento.get(herramienta, false):
			total += 1
	return total


func _contar(cantidad: int, singular: String, plural: String) -> String:
	return singular if cantidad == 1 else plural % cantidad
