class_name HabilidadBendicion
extends Habilidad
## Protege y acelera a un aliado por unos segundos. No cura nada: es la
## habilidad que se usa ANTES de que el soldado este por caer, no despues.

@export var duracion: float = 8.0
## Fraccion de dano que deja de recibir (0.35 = 35% menos).
@export var reduccion_dano: float = 0.35
## Fraccion que se le acorta el tiempo entre golpes.
@export var bonus_cadencia: float = 0.30


func motivo_bloqueo(healer: Node) -> String:
	var objetivo: Unidad = healer.objetivo_apuntado()
	if objetivo == null:
		return "Sin objetivo"
	if not healer.en_rango(objetivo):
		return "Fuera de alcance"
	if objetivo.esta_bendecida():
		return "Ya esta bendecido"
	return ""


func ejecutar(healer: Node) -> String:
	var objetivo: Unidad = healer.objetivo_apuntado()
	objetivo.bendecir(duracion, reduccion_dano, bonus_cadencia)
	healer.lanzar_efecto(objetivo, "shield")
	return "Bendicion: -%d%% dano por %ds" % [reduccion_dano * 100.0, duracion]
