class_name MovimientoCurar
extends Movimiento
## Cura a un aliado de la caja frontal: Toque y Vendaje.
##
## Vendaje es el mismo gesto un paso mas adentro del combo: sigue sobre el
## paciente que ya se estaba atendiendo y ademas le corta el sangrado. Curar
## sin cortar solo compra tiempo; el segundo toque trata la causa.

@export var cantidad: float = 18.0
## Ademas de curar, corta el sangrado.
@export var corta_sangrado: bool = false
## Sigue sobre el ultimo aliado que toco el combo mientras este al frente y
## herido, aunque aparezca otro peor.
@export var preferir_ultimo_objetivo: bool = false


func elegir_objetivo(healer: Node3D) -> Unidad3D:
	var preferido: Unidad3D = _ultimo_tocado(healer) if preferir_ultimo_objetivo else null
	return Apuntado.objetivo_ligera(healer, preferido)


func motivo_bloqueo(healer: Node3D) -> String:
	return SIN_OBJETIVO if elegir_objetivo(healer) == null else ""


func ejecutar(healer: Node3D) -> Dictionary:
	var unidad := elegir_objetivo(healer)
	if unidad == null:
		return _resultado(false)

	var cortado := corta_sangrado and unidad.estabilizar()
	var entro := unidad.curar(cantidad)
	healer.lanzar_efecto(unidad, efecto, color)
	if cortado:
		# El nombre del movimiento, un renglon arriba de lo que entro. Si ahi
		# ya esta lo desperdiciado, mostrar_numero lo sube otro.
		unidad.mostrar_numero(nombre.to_upper(), color, 0.8, 1)
	# Cortar el sangrado es lo que el jugador tiene que ver primero: la vida
	# que entro ya la muestra la barra.
	var texto := "%s: sangrado cortado" % nombre if cortado else _texto_cura(cantidad, entro)
	return _resultado(true, unidad, entro, texto)


func previsualizar(_healer: Node3D, objetivo: Unidad3D) -> String:
	if objetivo == null or objetivo.esta_derribada():
		return ""
	var cura := _texto_previa(objetivo, cantidad)
	if corta_sangrado and objetivo.sangrado_restante > 0.0:
		return "%s: corta el sangrado, %s" % [nombre, cura]
	return "%s: %s" % [nombre, cura]
