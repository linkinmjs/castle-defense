class_name MetaEncuentro
extends Resource
## Una condicion de exito secundaria, evaluada sobre el resumen del encuentro.
##
## No define si se gana o se pierde: nombra en que consiste jugarlo bien. Un
## encuentro se puede ganar con la mitad de la curacion desperdiciada, y la
## meta es lo que lo señala sin convertirlo en derrota.

enum Comparador { MENOR_QUE, MENOR_IGUAL, MAYOR_IGUAL, IGUAL }

## Clave del resumen que publica la telemetria.
@export var clave: StringName = &""
@export var comparador: Comparador = Comparador.MENOR_IGUAL
@export var valor: float = 0.0
## Como se enuncia en pantalla: "Menos del 15% de curacion desperdiciada".
@export var texto: String = ""


func cumplida(resumen: Dictionary) -> bool:
	if not resumen.has(clave):
		return false
	var obtenido: float = float(resumen[clave])
	match comparador:
		Comparador.MENOR_QUE:
			return obtenido < valor
		Comparador.MENOR_IGUAL:
			return obtenido <= valor
		Comparador.MAYOR_IGUAL:
			return obtenido >= valor
		Comparador.IGUAL:
			return is_equal_approx(obtenido, valor)
	return false
