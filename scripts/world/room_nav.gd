class_name RoomNav
extends RefCounted
## Grade de navegação/colisão lógica da sala (A* em grade) e linha de visão.

const T := 16
var w: int
var h: int
var solid := PackedByteArray()
var opaque := PackedByteArray()
var astar := AStarGrid2D.new()

func _init(width: int, height: int) -> void:
	w = width
	h = height
	solid.resize(w * h)
	opaque.resize(w * h)

func set_cell(c: Vector2i, is_solid: bool, is_opaque: bool = false) -> void:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return
	if is_solid:
		solid[c.y * w + c.x] = 1
	if is_opaque:
		opaque[c.y * w + c.x] = 1

func rebuild() -> void:
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(T, T)
	astar.offset = Vector2(T / 2.0, T / 2.0)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in h:
		for x in w:
			astar.set_point_solid(Vector2i(x, y), solid[y * w + x] == 1)

func clear_dynamic(base_solid: PackedByteArray, base_opaque: PackedByteArray) -> void:
	solid = base_solid.duplicate()
	opaque = base_opaque.duplicate()

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))

func center_of(c: Vector2i) -> Vector2:
	return Vector2(c.x * T + T / 2.0, c.y * T + T / 2.0)

func is_solid_cell(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return true
	return solid[c.y * w + c.x] == 1

func is_opaque_cell(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return true
	return opaque[c.y * w + c.x] == 1

func is_free_point(p: Vector2) -> bool:
	return not is_solid_cell(cell_of(p))

func nearest_free_cell(c: Vector2i, max_r: int = 8) -> Vector2i:
	if not is_solid_cell(c):
		return c
	for r in range(1, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := Vector2i(c.x + dx, c.y + dy)
				if not is_solid_cell(n):
					return n
	return c

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := nearest_free_cell(cell_of(from))
	var b := nearest_free_cell(cell_of(to))
	if is_solid_cell(a) or is_solid_cell(b):
		return PackedVector2Array()
	return astar.get_point_path(a, b)

func has_los(a: Vector2, b: Vector2) -> bool:
	var d := a.distance_to(b)
	var steps := int(d / 4.0)
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / steps)
		if is_opaque_cell(cell_of(p)):
			return false
	return true

func reachable(from: Vector2, to: Vector2) -> bool:
	return not find_path(from, to).is_empty()
