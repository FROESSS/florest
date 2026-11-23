class_name Room
extends Node2D
## Sala construída a partir dos dados do capítulo: chão/paredes, colisões, objetos, luzes e navegação.

const T := 16

var id: String = ""
var spec: Dictionary = {}
var size_tiles: Vector2i = Vector2i(20, 14)
var nav: RoomNav
var objects: Array[Interactable] = []
var barriers: Array[Dictionary] = []     # {id, node, body, spec}
var y_layer: Node2D
var wall_body: StaticBody2D
var base_solid := PackedByteArray()
var base_opaque := PackedByteArray()
var flicker_lights: Array[Dictionary] = []
var modulate_node: CanvasModulate
var enemies: Array[Node] = []
var holes: Array = []                    # {tile: Vector2i, node: Sprite2D, body: StaticBody2D}
var _t := 0.0

const MAX_HOLES := 8                     # limite por sala (evita excesso de entidades)
const MAX_HOLES_TOTAL := 24

func build(room_id: String) -> void:
	id = room_id
	spec = NarrativeManager.rooms_db[room_id]
	var sz: Array = spec.get("size", [20, 14])
	size_tiles = Vector2i(sz[0], sz[1])
	var w := size_tiles.x
	var h := size_tiles.y
	# --- paredes ---
	var wall := PackedByteArray()
	wall.resize(w * h)
	for y in h:
		for x in w:
			if y <= 1 or y == h - 1 or x == 0 or x == w - 1:
				wall[y * w + x] = 1
	for b in spec.get("blocks", []):
		for yy in range(int(b[1]), int(b[1]) + int(b[3])):
			for xx in range(int(b[0]), int(b[0]) + int(b[2])):
				if xx >= 0 and yy >= 0 and xx < w and yy < h:
					wall[yy * w + xx] = 1
	var floor_sprite := Sprite2D.new()
	floor_sprite.centered = false
	floor_sprite.z_index = -10
	floor_sprite.texture = TileArt.build_room(id, str(spec.get("theme", "orfanato")), wall, w, h, float(spec.get("decals", 0.12)))
	add_child(floor_sprite)
	wall_body = StaticBody2D.new()
	wall_body.collision_layer = 1
	wall_body.collision_mask = 0
	add_child(wall_body)
	for y in h:
		var x := 0
		while x < w:
			if wall[y * w + x] == 1:
				var x0 := x
				while x < w and wall[y * w + x] == 1:
					x += 1
				var cs := CollisionShape2D.new()
				var rs := RectangleShape2D.new()
				rs.size = Vector2((x - x0) * T, T)
				cs.shape = rs
				cs.position = Vector2(x0 * T + rs.size.x / 2.0, y * T + T / 2.0)
				wall_body.add_child(cs)
			else:
				x += 1
	nav = RoomNav.new(w, h)
	for y in h:
		for x in w:
			if wall[y * w + x] == 1:
				nav.set_cell(Vector2i(x, y), true, true)
	base_solid = nav.solid.duplicate()
	base_opaque = nav.opaque.duplicate()
	y_layer = Node2D.new()
	y_layer.y_sort_enabled = true
	add_child(y_layer)
	# --- objetos ---
	for o in spec.get("objects", []):
		var it := Interactable.new()
		y_layer.add_child(it)
		it.setup(id, o)
		objects.append(it)
	# --- barreiras dinâmicas ---
	for b in spec.get("barriers", []):
		_make_barrier(b)
	# --- luzes ---
	var amb: float = float(spec.get("ambient", 0.22))
	modulate_node = CanvasModulate.new()
	var tint := Color(spec.get("tint", "#ffffff"))
	modulate_node.color = Color(amb * tint.r, amb * tint.g, amb * tint.b * 1.1, 1.0)
	add_child(modulate_node)
	var count := 0
	for l in spec.get("lights", []):
		if count >= 8:
			break
		count += 1
		_make_light(l)
	for hd in GameManager.world_state.get("holes", {}).get(id, []):
		_spawn_hole_visual(Vector2i(int(hd["tile"][0]), int(hd["tile"][1])))
	refresh_dynamic()

func _make_barrier(b: Dictionary) -> void:
	var r: Array = b["rect"]
	var node := Node2D.new()
	var sp := Sprite2D.new()
	sp.centered = false
	var pw := int(r[2]) * T
	var ph := int(r[3]) * T
	sp.texture = TileArt.prop(str(b.get("kind", "tissue")), pw, ph, str(b.get("variant", "")))
	node.add_child(sp)
	node.position = Vector2(int(r[0]) * T, int(r[1]) * T)
	node.z_index = 0
	y_layer.add_child(node)
	node.y_sort_enabled = false
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(pw, ph)
	cs.shape = rs
	cs.position = Vector2(pw / 2.0, ph / 2.0)
	body.add_child(cs)
	node.add_child(body)
	barriers.append({"id": b.get("id", "b"), "node": node, "body": body, "spec": b})

func _make_light(l: Dictionary) -> void:
	var pl := PointLight2D.new()
	pl.texture = PixelArt.light_radial(128)
	var radius: float = float(l.get("radius", 80))
	pl.texture_scale = radius / 64.0
	pl.color = Color(l.get("color", "#ffe0a0"))
	pl.energy = float(l.get("energy", 0.9))
	if l.has("tile"):
		pl.position = Vector2(l["tile"][0] * T + T / 2.0, l["tile"][1] * T + T / 2.0)
	else:
		pl.position = Vector2(l["px"][0], l["px"][1])
	add_child(pl)
	if l.get("flicker", false):
		flicker_lights.append({"node": pl, "base": pl.energy, "phase": randf() * 10.0})

func _process(delta: float) -> void:
	_t += delta
	var calm: bool = SettingsManager.reduce_flashes
	for f in flicker_lights:
		var n: PointLight2D = f["node"]
		if calm:
			n.energy = f["base"] * (0.92 + 0.08 * sin(_t * 1.5 + f["phase"]))
		else:
			var s := sin(_t * 17.0 + f["phase"]) * sin(_t * 5.3 + f["phase"] * 2.0)
			n.energy = f["base"] * (0.75 + 0.25 * s) * (0.35 if fmod(_t * 0.7 + f["phase"], 7.0) < 0.12 else 1.0)
	for b in barriers:
		var node: Node2D = b["node"]
		if node.visible:
			node.modulate = Color(1, 1, 1).lerp(Color(1.12, 0.9, 0.9), 0.5 + 0.5 * sin(_t * 2.2 + node.position.x))

## Reavalia visibilidade de objetos e barreiras quando as flags mudam.
func refresh_dynamic() -> void:
	nav.solid = base_solid.duplicate()
	nav.opaque = base_opaque.duplicate()
	for o in objects:
		o.refresh()
		if o.visible and o.is_solid:
			_mark_rect(o.rect, false)
	for b in barriers:
		var removed_if: Dictionary = b["spec"].get("removed_if", {})
		var active := removed_if.is_empty() or not NarrativeManager.check(removed_if)
		var vis_if: Dictionary = b["spec"].get("visible_if", {})
		if not vis_if.is_empty() and not NarrativeManager.check(vis_if):
			active = false
		var node: Node2D = b["node"]
		node.visible = active
		(b["body"].get_child(0) as CollisionShape2D).set_deferred("disabled", not active)
		if active:
			var r: Array = b["spec"]["rect"]
			_mark_rect(Rect2(int(r[0]) * T, int(r[1]) * T, int(r[2]) * T, int(r[3]) * T), true)
	for h in holes:
		nav.set_cell(h["tile"], true, false)
	nav.rebuild()

func _mark_rect(r: Rect2, opaque: bool) -> void:
	var c0 := nav.cell_of(r.position + Vector2(1, 1))
	var c1 := nav.cell_of(r.end - Vector2(1, 1))
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			nav.set_cell(Vector2i(x, y), true, opaque)

func spawn_position(spawn_name: String) -> Vector2:
	var spawns: Dictionary = spec.get("spawns", {})
	var s: Array = spawns.get(spawn_name, spawns.values()[0] if not spawns.is_empty() else [3, 4])
	return Vector2(s[0] * T + T / 2.0, s[1] * T + T / 2.0 + 4.0)

func find_object(obj_id: String) -> Interactable:
	for o in objects:
		if str(o.spec.get("id", "")) == obj_id:
			return o
	return null

func pixel_size() -> Vector2:
	return Vector2(size_tiles.x * T, size_tiles.y * T)

# ---------- Buracos do Morador (persistentes) ----------

func _spawn_hole_visual(c: Vector2i) -> void:
	var sp := Sprite2D.new()
	sp.texture = TileArt.prop("hole", T, T)
	sp.centered = false
	sp.position = Vector2(c.x * T, c.y * T)
	sp.z_index = -1
	add_child(sp)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(T - 2, T - 2)
	cs.shape = rs
	cs.position = Vector2(c.x * T + T / 2.0, c.y * T + T / 2.0)
	body.add_child(cs)
	add_child(body)
	holes.append({"tile": c, "node": sp, "body": body})

func hole_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for h in holes:
		out.append(nav.center_of(h["tile"]))
	return out

func has_hole_at(c: Vector2i) -> bool:
	for h in holes:
		if h["tile"] == c:
			return true
	return false

func _total_holes() -> int:
	var n := 0
	for rid in GameManager.world_state.get("holes", {}):
		n += (GameManager.world_state["holes"][rid] as Array).size()
	return n

func _reachable_count(blocked: Vector2i) -> int:
	var first := nav.cell_of(spawn_position(spec["spawns"].keys()[0]))
	var seen := {}
	var queue: Array[Vector2i] = [first]
	seen[first] = true
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n == blocked or seen.has(n) or nav.is_solid_cell(n):
				continue
			seen[n] = true
			queue.append(n)
	return seen.size()

## Regras para criar um buraco: sem duplicar, com espaçamento, longe de portas/objetos/spawns,
## dentro dos limites e SEM cortar nenhuma rota (a conectividade da sala é preservada).
func can_add_hole(c: Vector2i) -> bool:
	if c.x < 1 or c.y < 2 or c.x > size_tiles.x - 2 or c.y > size_tiles.y - 2:
		return false
	if nav.is_solid_cell(c) or has_hole_at(c):
		return false
	if holes.size() >= MAX_HOLES or _total_holes() >= MAX_HOLES_TOTAL:
		return false
	for h in holes:
		if maxi(absi(h["tile"].x - c.x), absi(h["tile"].y - c.y)) < 2:
			return false
	for e in spec.get("enemies", []):
		for v in e.get("vents", []):
			if maxi(absi(int(v[0]) - c.x), absi(int(v[1]) - c.y)) < 2:
				return false
	for s in spec.get("spawns", {}).values():
		if maxi(absi(int(s[0]) - c.x), absi(int(s[1]) - c.y)) < 2:
			return false
	for r in spec.get("recovery", []):
		if maxi(absi(int(r[0]) - c.x), absi(int(r[1]) - c.y)) < 2:
			return false
	for o in objects:
		if o.visible and o.rect.grow(float(T)).has_point(nav.center_of(c)):
			return false
	var before := _reachable_count(Vector2i(-99, -99))
	return _reachable_count(c) == before - 1

func add_hole(c: Vector2i) -> bool:
	if not can_add_hole(c):
		return false
	var wh: Dictionary = GameManager.world_state.get("holes", {})
	var arr: Array = wh.get(id, [])
	arr.append({"tile": [c.x, c.y]})
	wh[id] = arr
	GameManager.world_state["holes"] = wh
	_spawn_hole_visual(c)
	refresh_dynamic()
	return true
