class_name MovimientoImpulso
extends Movimiento
## Ligera en el aire: lanza al healer hacia donde mira. Es movilidad, asi que
## conecta aunque no haya nadie cerca (no redefine motivo_bloqueo). De paso cura
## una vez al primer herido que cruza; eso lo va chequeando ComponenteCombos
## mientras dura el envion, llamando a cruzar().

@export var fuerza: float = 9.5
@export var duracion: float = 0.22
## Vida para el primer aliado herido que el healer cruza. 0 = no cura.
@export var cura_al_cruzar: float = 12.0
## A menos de esta distancia (en el plano) cuenta como cruzarlo.
@export var radio_cruce: float = 0.9


func ejecutar(healer: Node3D) -> Dictionary:
	var frente := Vector3(Apuntado.direccion_frente(healer), 0.0, 0.0)
	healer.impulsar(frente, fuerza, duracion)
	return _resultado(true)


## Cura al aliado herido mas cercano que este a menos de radio_cruce, si hay.
##
## Solo a heridos: pasar rozando a un sano no deberia gastar la cura ni
## contarse como desperdicio, porque no fue una decision del jugador.
func cruzar(healer: Node3D) -> Dictionary:
	if cura_al_cruzar <= 0.0:
		return _resultado(false)
	var mejor: Unidad3D = null
	var mejor_distancia := INF
	for unidad in Apuntado.aliados_alrededor(healer, radio_cruce):
		if unidad.vida >= unidad.vida_maxima:
			continue
		var distancia := Apuntado.distancia_en_plano(healer, unidad)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = unidad
	if mejor == null:
		return _resultado(false)

	var entro := mejor.curar(cura_al_cruzar)
	healer.lanzar_efecto(mejor, efecto)
	return _resultado(true, mejor, entro, _texto_cura(cura_al_cruzar, entro))


func previsualizar(_healer: Node3D, objetivo: Unidad3D) -> String:
	if cura_al_cruzar <= 0.0 or objetivo == null or objetivo.esta_derribada() \
			or objetivo.vida >= objetivo.vida_maxima:
		return ""
	return "%s: %s al cruzarlo" % [nombre, _texto_previa(objetivo, cura_al_cruzar)]
