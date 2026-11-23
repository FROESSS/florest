class_name Interactable
extends Node2D
## Objeto interativo orientado a dados (móveis, itens, portas, esconderijos, NPCs).

const T := 16
const FLAT_KINDS := ["door", "labdoor", "window", "drawing", "poster", "panel", "blackboard", "mirror",
	"elevator", "hatch", "rug", "vent", "trap"]
const SOLID_KINDS := ["bed", "hospital_bed", "wardrobe", "desk", "reception", "drawers", "dresser", "toybox",
	"table", "bench", "crib", "schooldesk", "pillar", "stairs", "capsule", "surgery", "locker", "cabinet",
	"terminal", "console", "reactor", "boiler", "fridge", "shelf", "statue", "crate", "box", "cocoon"]

var spec: Dictionary = {}
var room_id: String = ""
var uid: String = ""
var rect: Rect2 = Rect2()
var sprite: Sprite2D = null
var anim: AnimatedSprite2D = null
var body: StaticBody2D = null
var is_solid: bool = false
var follow: bool = false
var _t: float = 0.0
var _hint: Sprite2D = null

func setup(p_room_id: String, p_spec: Dictionary) -> void:
	room_id = p_room_id
	spec = p_spec
	uid = "%s:%s" % [room_id, str(spec.get("id", "?"))]
	var tile: Array = spec.get("tile", [0, 0])
	var size: Array = spec.get("size", [1, 1])
	rect = Rect2(tile[0] * T, tile[1] * T, size[0] * T, size[1] * T)
	var kind: String = str(spec.get("kind", "box"))
	position = Vector2(rect.position.x + rect.size.x / 2.0, rect.end.y)
	var variant: String = str(spec.get("variant", ""))
	if kind == "npc":
		anim = AnimatedSprite2D.new()
		anim.sprite_frames = PixelArt.character_frames(str(spec.get("style", "kid_a")))
		anim.offset = Vector2(0, -15)
		anim.play("idle_" + str(spec.get("facing", "down")))
		add_child(anim)
		position = rect.get_center() + Vector2(0, 6)
		follow = bool(spec.get("follow", false))
		if spec.get("ghost", false):
			anim.modulate = Color(0.8, 0.85, 1.0, 0.75)
		is_solid = false
	else:
		var px_size: Array = spec.get("px", [int(rect.size.x), int(rect.size.y)])
		var pw: int = int(px_size[0])
		var ph: int = int(px_size[1])
		sprite = Sprite2D.new()
		sprite.texture = TileArt.prop(kind, pw, ph, variant)
		sprite.centered = false
		if pw < rect.size.x or ph < rect.size.y:
			sprite.position = Vector2(-pw / 2.0, -ph - (rect.size.y - ph) / 2.0)
		else:
			sprite.position = Vector2(-pw / 2.0, -ph)
		add_child(sprite)
		if kind in FLAT_KINDS or bool(spec.get("flat", false)):
			z_index = -1
		is_solid = bool(spec.get("solid", kind in SOLID_KINDS))
	if is_solid:
		body = StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = rect.size
		cs.shape = rs
		cs.position = rect.get_center() - position
		body.add_child(cs)
		add_child(body)
	if spec.get("important", false) and kind != "npc":
		_hint = Sprite2D.new()
		var himg := PixelArt.new_image(5, 5)
		for p in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2), Vector2i(4, 2), Vector2i(2, 4), Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 3)]:
			himg.set_pixel(p.x, p.y, Color("f2e6a8"))
		_hint.texture = PixelArt.tex(himg)
		_hint.position = Vector2(0, -rect.size.y - 6)
		add_child(_hint)

func _process(delta: float) -> void:
	_t += delta
	if _hint != null:
		_hint.visible = visible
		_hint.modulate.a = 0.45 + 0.4 * sin(_t * 3.0)
	if follow and visible and GameManager.player != null and not get_tree().paused:
		_follow_player(delta)

func _follow_player(delta: float) -> void:
	var pl: Node2D = GameManager.player
	var target: Vector2 = pl.position + Vector2(-pl.facing.x * 18.0, -pl.facing.y * 12.0 + 4.0)
	var d := position.distance_to(target)
	if d > 140.0:
		position = target
		return
	if d > 6.0:
		var dir := (target - position).normalized()
		position += dir * minf(d, (60.0 + d * 1.6) * delta)
		var dn := "right" if absf(dir.x) > absf(dir.y) and dir.x > 0 else ("left" if absf(dir.x) > absf(dir.y) else ("down" if dir.y > 0 else "up"))
		var an := "walk_" + dn
		if anim.animation != an:
			anim.play(an)
	else:
		var idle := "idle_" + anim.animation.get_slice("_", 1)
		if anim.animation != idle:
			anim.play(idle)
	rect.position = position - rect.size / 2.0

func is_available() -> bool:
	var vis: Dictionary = spec.get("visible_if", {})
	if not vis.is_empty() and not NarrativeManager.check(vis):
		return false
	var hide_cond: Dictionary = spec.get("hide_if", {})
	if not hide_cond.is_empty() and NarrativeManager.check(hide_cond):
		return false
	if bool(spec.get("vanish_when_done", false)) and NarrativeManager.has_flag("done_" + uid):
		return false
	return true

func refresh() -> void:
	var av := is_available()
	visible = av
	if body != null:
		for c in body.get_children():
			if c is CollisionShape2D:
				c.set_deferred("disabled", not av)

func prompt() -> String:
	var verb: String = str(spec.get("prompt", "Examinar"))
	var nm: String = str(spec.get("name", ""))
	if nm == "":
		return verb
	return "%s: %s" % [verb, nm]

func is_hide_spot() -> bool:
	return bool(spec.get("hide", false))

func hide_position() -> Vector2:
	return rect.get_center() + Vector2(0, rect.size.y * 0.2)

func exit_position() -> Vector2:
	var off: Array = spec.get("exit_offset", [0, 14])
	return Vector2(rect.get_center().x + off[0], rect.end.y + off[1])

func center() -> Vector2:
	return rect.get_center()
