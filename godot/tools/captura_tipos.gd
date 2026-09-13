extends SceneTree
## Capturas de la batalla con tipos mezclados, y conteo por bando para ver
## si el balance quedo razonable.

const MOMENTOS := [3.0, 10.0, 20.0]

var _inicio_ms := 0
var _siguiente := 0
var _battle: Node


func _initialize() -> void:
	_battle = load("res://scenes/3d/battle3d.tscn").instantiate()
	root.add_child(_battle)
	_inicio_ms = Time.get_ticks_msec()
	print("t(s)  aliados  enemigos  retirandose  frente")


func _process(_delta: float) -> bool:
	if _siguiente >= MOMENTOS.size():
		return true
	var t := (Time.get_ticks_msec() - _inicio_ms) / 1000.0
	if t < MOMENTOS[_siguiente]:
		return false

	var nombre := "tipos_%02d_%.0fs.png" % [_siguiente + 1, MOMENTOS[_siguiente]]
	root.get_texture().get_image().save_png("user://" + nombre)
	print("%4.0f  %7d  %8d  %11d  %6.1f   -> %s" % [
		t, _vivos("aliados"), _vivos("enemigos"), _retirandose(), _battle.frente_x(), nombre])
	_siguiente += 1
	return _siguiente >= MOMENTOS.size()


func _vivos(grupo: String) -> int:
	var total := 0
	for u in root.get_tree().get_nodes_in_group(grupo):
		if u.esta_viva() and not u.esta_derribada():
			total += 1
	return total


func _retirandose() -> int:
	var total := 0
	for u in root.get_tree().get_nodes_in_group("aliados"):
		if u.estado == Unidad3D.Estado.RETIRANDOSE:
			total += 1
	return total
