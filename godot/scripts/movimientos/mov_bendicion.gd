class_name MovimientoBendicion
extends Movimiento
## Protege y acelera a un aliado por unos segundos. No cura: se usa antes de
## que el soldado este por caer. En el combo sale despues de una ligera y cae
## sobre el que esa ligera toco: primero se lo atiende, despues se lo cubre.

@export var duracion: float = 8.0
## Fraccion de dano que deja de recibir (0.35 = 35% menos).
@export var reduccion: float = 0.35
## Fraccion que se le acorta el tiempo entre golpes.
@export var bonus: float = 0.30


## El ultimo que toco el combo si sigue al frente; si no, el que tocaria la
## ligera. A diferencia de la cura, no exige que este herido: proteger a un
## sano antes de que lo golpeen es el uso bueno.
func elegir_objetivo(healer: Node3D) -> Unidad3D:
	var ultimo := _ultimo_tocado(healer)
	if ultimo != null and Apuntado.esta_al_frente(healer, ultimo):
		return ultimo
	return Apuntado.objetivo_ligera(healer)


func motivo_bloqueo(healer: Node3D) -> String:
	var unidad := elegir_objetivo(healer)
	if unidad == null:
		return SIN_OBJETIVO
	if unidad.esta_bendecida():
		return "Ya bendecido"
	return ""


func ejecutar(healer: Node3D) -> Dictionary:
	var unidad := elegir_objetivo(healer)
	if unidad == null or unidad.esta_bendecida():
		return _resultado(false)
	unidad.bendecir(duracion, reduccion, bonus)
	healer.lanzar_efecto(unidad, efecto)
	return _resultado(true, unidad, 0.0, "Bendecido")


func previsualizar(_healer: Node3D, objetivo: Unidad3D) -> String:
	if objetivo == null or objetivo.esta_derribada():
		return ""
	if objetivo.esta_bendecida():
		return "%s: ya la tiene" % nombre
	return "%s: -%d%% dano por %ds" % [nombre, roundi(reduccion * 100.0), roundi(duracion)]
