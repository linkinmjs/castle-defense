class_name MovimientoArea
extends Movimiento
## Cura a varios a la vez: Plegaria (la caja grande de adelante), Oleada
## (todos alrededor, remate del combo) y Caida sanadora (alrededor, al tocar el
## suelo). Ninguna hace dano: el healer no ataca.

enum Forma {
	CAJA_FRONTAL,  ## los de la caja pesada
	ALREDEDOR,     ## los que esten a `radio` metros, en cualquier direccion
}

@export var cantidad: float = 30.0
@export var forma: Forma = Forma.ALREDEDOR
## Metros, solo para ALREDEDOR.
@export var radio: float = 4.0
## Enemigos a esta distancia quedan aturdidos, si saben estarlo. 0 = no aturde.
@export var aturde_radio: float = 0.0
@export var aturde_segundos: float = 0.0


func alcanzados(healer: Node3D) -> Array[Unidad3D]:
	if forma == Forma.CAJA_FRONTAL:
		return Apuntado.objetivos_pesada(healer)
	return Apuntado.aliados_alrededor(healer, radio)


## Enemigos que quedarian aturdidos. Las unidades saben aturdirse
## (Unidad3D.aturdir); se pregunta por el metodo y no por el tipo para que un
## enemigo que no sepa se saltee sin romper nada.
func aturdibles(healer: Node3D) -> Array[Unidad3D]:
	var lista: Array[Unidad3D] = []
	if aturde_radio <= 0.0 or aturde_segundos <= 0.0:
		return lista
	for enemigo in Apuntado.enemigos_alrededor(healer, aturde_radio):
		if enemigo.has_method(&"aturdir"):
			lista.append(enemigo)
	return lista


func motivo_bloqueo(healer: Node3D) -> String:
	# En el aire todavia no se sabe donde va a caer: el que se resuelve al
	# aterrizar se revisa al tocar el suelo, no al apretar.
	if al_aterrizar and healer.esta_en_el_aire():
		return ""
	if alcanzados(healer).is_empty() and aturdibles(healer).is_empty():
		return SIN_OBJETIVO
	return ""


func ejecutar(healer: Node3D) -> Dictionary:
	var lista := alcanzados(healer)
	var aturdidos := aturdibles(healer)
	if lista.is_empty() and aturdidos.is_empty():
		return _resultado(false)

	var total := 0.0
	var curados := 0
	var destellos := 0
	if al_aterrizar:
		# El golpe contra el suelo se ve en el healer; el resto, en quien sube.
		healer.lanzar_efecto(healer, efecto, color)
		destellos += 1
	for unidad in lista:
		var entro := unidad.curar(cantidad)
		total += entro
		if entro > 0.0:
			curados += 1
		if destellos < MAX_EFECTOS:
			healer.lanzar_efecto(unidad, efecto, color)
			destellos += 1
	for enemigo in aturdidos:
		enemigo.call(&"aturdir", aturde_segundos)

	return _resultado(true, null, total, _texto(curados, total, aturdidos.size()))


func previsualizar(_healer: Node3D, objetivo: Unidad3D) -> String:
	if objetivo == null or objetivo.esta_derribada():
		return ""
	if al_aterrizar:
		return "%s (al aterrizar): %s" % [nombre, _texto_previa(objetivo, cantidad)]
	return "%s: %s" % [nombre, _texto_previa(objetivo, cantidad)]


## "Plegaria: +80 en 2 soldados". Si nadie necesitaba la cura se dice: el
## desperdicio es justamente lo que el jugador tiene que aprender a ver.
func _texto(curados: int, total: float, aturdidos: int) -> String:
	var partes := PackedStringArray()
	if curados > 0:
		partes.append("+%d en %d %s" % [
			roundi(total), curados, "soldado" if curados == 1 else "soldados"])
	if aturdidos > 0:
		partes.append("%d %s" % [aturdidos, "aturdido" if aturdidos == 1 else "aturdidos"])
	if partes.is_empty():
		return "%s: nadie lo necesitaba" % nombre
	return "%s: %s" % [nombre, ", ".join(partes)]
