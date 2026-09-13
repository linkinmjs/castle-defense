class_name Campana
extends Resource
## Los encuentros en el orden en que se juegan.
##
## El orden es el contenido: cada encuentro suma una variable sobre lo que el
## anterior ya dejo practicado.

@export var encuentros: Array[Encuentro] = []


func encuentro_en(indice: int) -> Encuentro:
	if indice < 0 or indice >= encuentros.size():
		return null
	return encuentros[indice]
