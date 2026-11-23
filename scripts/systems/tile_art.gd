class_name TileArt
extends RefCounted
## Tiles de sala (chão/paredes com profundidade) e props, todos procedurais e originais.

const T := 16
static var _cache: Dictionary = {}

const THEMES := {
	"orfanato": {
		"floor_a": "4d4838", "floor_b": "443f31", "line": "2d2a20", "wall": "4e5b49", "wall_d": "394535",
		"cap": "171b16", "cap_edge": "2b3328", "trim": "6a6850", "moss": "5f7d4a", "kind": "wood",
	},
	"quarto": {
		"floor_a": "7a7566", "floor_b": "706b5d", "line": "514d42", "wall": "7889a0", "wall_d": "62718a",
		"cap": "1d2027", "cap_edge": "343a47", "trim": "b3a688", "moss": "6c8a7a", "kind": "wood",
	},
	"lab": {
		"floor_a": "b4b7ae", "floor_b": "a8aba2", "line": "868a82", "wall": "cdd0c4", "wall_d": "a5a99d",
		"cap": "3e403d", "cap_edge": "5c5e5a", "trim": "8e2f2f", "moss": "6e6a5a", "kind": "tile",
	},
	"organico": {
		"floor_a": "4a2028", "floor_b": "3f1a21", "line": "2a0e14", "wall": "7d3445", "wall_d": "5a2431",
		"cap": "100508", "cap_edge": "3a131c", "trim": "c06a7e", "moss": "8a2f3e", "kind": "flesh",
	},
	"memoria": {
		"floor_a": "5b574f", "floor_b": "54504a", "line": "3a3833", "wall": "6c675e", "wall_d": "524e47",
		"cap": "1a1917", "cap_edge": "34322e", "trim": "8a8578", "moss": "5f5b52", "kind": "wood",
	},
}

static func _col(theme: Dictionary, k: String) -> Color:
	return Color(theme[k])

static func shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a)

# ---------- Sala ----------

static func build_room(room_id: String, theme_name: String, wall: PackedByteArray, w: int, h: int, decals: float, extra: Dictionary = {}) -> ImageTexture:
	var theme: Dictionary = THEMES.get(theme_name, THEMES["orfanato"])
	var img := Image.create(w * T, h * T, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	var seed_v: int = room_id.hash()
	for ty in h:
		for tx in w:
			var is_wall := wall[ty * w + tx] == 1
			if is_wall:
				var below_floor := ty + 1 < h and wall[(ty + 1) * w + tx] == 0
				if below_floor:
					_wall_front(img, tx, ty, theme, theme_name, seed_v)
				else:
					_wall_cap(img, tx, ty, theme, wall, w, h)
			else:
				_floor(img, tx, ty, theme, wall, w, h, seed_v)
	ArtFX.floor_zones(img, extra.get("zones", []), wall, w, seed_v)
	_shadow_pass(img, wall, w, h)
	ArtFX.wall_decay(img, wall, w, h, theme_name, seed_v)
	ArtFX.ceiling_fixtures(img, wall, w, h, theme_name, seed_v)
	_decals(img, theme_name, wall, w, h, decals, seed_v)
	ArtFX.clutter(img, theme_name, wall, w, h, extra.get("avoid", []), seed_v, float(extra.get("clutter", 0.05)))
	ArtFX.overgrowth(img, wall, w, h, float(extra.get("overgrowth", 0.0)), seed_v)
	return PixelArt.tex(img)

## Sombra suave da parede sobre o chão (inclusive sobre zonas de piso especiais).
static func _shadow_pass(img: Image, wall: PackedByteArray, w: int, h: int) -> void:
	for ty in range(1, h):
		for tx in w:
			if wall[ty * w + tx] == 0 and wall[(ty - 1) * w + tx] == 1:
				for r in 3:
					for x in T:
						var px := tx * T + x
						var py := ty * T + r
						var c := img.get_pixel(px, py)
						img.set_pixel(px, py, Color(c.r * 0.9, c.g * 0.9, c.b * 0.92, 1.0))

static func _floor(img: Image, tx: int, ty: int, theme: Dictionary, wall: PackedByteArray, w: int, h: int, seed_v: int) -> void:
	var x0 := tx * T
	var y0 := ty * T
	var hv: int = PixelArt.hash2(tx, ty, seed_v)
	var base := _col(theme, "floor_a") if hv % 2 == 0 else _col(theme, "floor_b")
	img.fill_rect(Rect2i(x0, y0, T, T), base)
	var line := _col(theme, "line")
	match theme["kind"]:
		"wood":
			for r in range(0, T, 4):
				img.fill_rect(Rect2i(x0, y0 + r, T, 1), line)
				var seam: int = PixelArt.hash2(tx, ty + r, seed_v) % T
				img.set_pixel(x0 + seam, y0 + r + 1, line)
				img.set_pixel(x0 + seam, y0 + r + 2, line)
			for i in 4:
				var p: int = PixelArt.hash2(tx * 7 + i, ty, seed_v + 3)
				img.set_pixel(x0 + p % T, y0 + (p / 16) % T, shade(base, 0.82))
		"tile":
			img.fill_rect(Rect2i(x0, y0, T, 1), line)
			img.fill_rect(Rect2i(x0, y0, 1, T), line)
			for i in 3:
				var p2: int = PixelArt.hash2(tx * 5 + i, ty, seed_v + 5)
				img.set_pixel(x0 + 1 + p2 % 14, y0 + 1 + (p2 / 16) % 14, shade(base, 0.9))
		"flesh":
			for i in 7:
				var p3: int = PixelArt.hash2(tx * 3 + i, ty * 2, seed_v + 9)
				var col := shade(base, 0.7) if i % 2 == 0 else shade(base, 1.35)
				img.set_pixel(x0 + p3 % T, y0 + (p3 / 16) % T, col)
			var vx: int = PixelArt.hash2(tx, ty, seed_v + 11) % 12
			for k in 6:
				img.set_pixel(x0 + clampi(vx + k / 2, 0, 15), y0 + 2 + k * 2, line)
	# sombra da parede sobre o chão
	if ty > 0 and wall[(ty - 1) * w + tx] == 1:
		for r in 3:
			for x in T:
				img.set_pixel(x0 + x, y0 + r, shade(img.get_pixel(x0 + x, y0 + r), [0.62, 0.78, 0.9][r]))
	if tx > 0 and wall[ty * w + tx - 1] == 1:
		for y in T:
			img.set_pixel(x0, y0 + y, shade(img.get_pixel(x0, y0 + y), 0.8))
	if tx + 1 < w and wall[ty * w + tx + 1] == 1:
		for y in T:
			img.set_pixel(x0 + T - 1, y0 + y, shade(img.get_pixel(x0 + T - 1, y0 + y), 0.85))

static func _wall_front(img: Image, tx: int, ty: int, theme: Dictionary, theme_name: String, seed_v: int) -> void:
	var x0 := tx * T
	var y0 := ty * T
	var base := _col(theme, "wall")
	var dark := _col(theme, "wall_d")
	img.fill_rect(Rect2i(x0, y0, T, T), base)
	match theme_name:
		"quarto":
			for x in range(0, T, 4):
				img.fill_rect(Rect2i(x0 + x, y0, 1, 10), shade(base, 1.08))
			img.fill_rect(Rect2i(x0, y0 + 10, T, 1), _col(theme, "trim"))
			img.fill_rect(Rect2i(x0, y0 + 11, T, 5), shade(_col(theme, "trim"), 0.82))
			img.fill_rect(Rect2i(x0, y0 + 15, T, 1), shade(_col(theme, "trim"), 0.55))
		"lab":
			img.fill_rect(Rect2i(x0, y0, 1, T), dark)
			img.fill_rect(Rect2i(x0, y0 + 7, T, 1), dark)
			img.fill_rect(Rect2i(x0, y0 + 11, T, 2), _col(theme, "trim"))
			img.fill_rect(Rect2i(x0, y0 + 14, T, 2), shade(base, 0.7))
		"organico":
			for i in 10:
				var p: int = PixelArt.hash2(tx * 3 + i, ty, seed_v + 2)
				img.set_pixel(x0 + p % T, y0 + (p / 16) % T, dark if i % 2 == 0 else _col(theme, "trim"))
			var vx: int = PixelArt.hash2(tx, ty, seed_v) % 12 + 2
			for k in 12:
				img.set_pixel(x0 + clampi(vx + (k % 3) - 1, 0, 15), y0 + k, _col(theme, "cap"))
			img.fill_rect(Rect2i(x0, y0 + 14, T, 2), dark)
		_:
			# alvenaria
			for r in range(0, T, 4):
				img.fill_rect(Rect2i(x0, y0 + r + 3, T, 1), dark)
				var off := 0 if (r / 4) % 2 == 0 else 4
				for k in range(off, T, 8):
					img.fill_rect(Rect2i(x0 + k, y0 + r, 1, 3), dark)
			img.fill_rect(Rect2i(x0, y0, T, 1), shade(base, 1.18))
			img.fill_rect(Rect2i(x0, y0 + 12, T, 4), shade(_col(theme, "trim"), 0.5))
			img.fill_rect(Rect2i(x0, y0 + 12, T, 1), shade(_col(theme, "trim"), 0.75))
			for i in 5:
				var p2: int = PixelArt.hash2(tx * 11 + i, ty, seed_v + 1)
				if p2 % 3 != 0:
					img.set_pixel(x0 + p2 % T, y0 + 8 + (p2 / 16) % 8, _col(theme, "moss"))

static func _wall_cap(img: Image, tx: int, ty: int, theme: Dictionary, wall: PackedByteArray, w: int, h: int) -> void:
	var x0 := tx * T
	var y0 := ty * T
	var cap := _col(theme, "cap")
	img.fill_rect(Rect2i(x0, y0, T, T), cap)
	var edge := _col(theme, "cap_edge")
	# borda clara voltada para áreas de chão
	if ty > 0 and wall[(ty - 1) * w + tx] == 0:
		img.fill_rect(Rect2i(x0, y0, T, 2), edge)
	if tx > 0 and wall[ty * w + tx - 1] == 0:
		img.fill_rect(Rect2i(x0, y0, 1, T), edge)
	if tx + 1 < w and wall[ty * w + tx + 1] == 0:
		img.fill_rect(Rect2i(x0 + T - 1, y0, 1, T), edge)

static func _decals(img: Image, theme_name: String, wall: PackedByteArray, w: int, h: int, density: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var count := int(w * h * density)
	for i in count:
		var tx := rng.randi_range(1, w - 2)
		var ty := rng.randi_range(2, h - 2)
		if wall[ty * w + tx] == 1:
			continue
		var x := tx * T + rng.randi_range(2, 12)
		var y := ty * T + rng.randi_range(3, 12)
		match theme_name:
			"lab":
				var blood := Color("5e1717")
				PixelArt.rect(img, x, y, rng.randi_range(2, 5), rng.randi_range(1, 3), blood)
				PixelArt.px(img, x + 1, y + 3, blood)
			"organico":
				PixelArt.ellipse(img, x, y, rng.randf_range(2.0, 4.0), rng.randf_range(1.5, 3.0), Color("6a2230"))
				PixelArt.px(img, x - 1, y - 1, Color("b05a6e"))
			_:
				if i % 3 == 0:
					var c := Color(0.1, 0.09, 0.07, 0.5)
					PixelArt.ellipse(img, x, y, rng.randf_range(2.0, 4.0), rng.randf_range(1.0, 2.5), c)
				else:
					var cr := Color(0.08, 0.07, 0.06, 1.0)
					var cx := x
					var cy := y
					for k in rng.randi_range(4, 8):
						PixelArt.px(img, cx, cy, cr)
						cx += rng.randi_range(0, 1)
						cy += rng.randi_range(0, 1)

# ---------- Props ----------

static func prop(kind: String, w: int, h: int, variant: String = "") -> ImageTexture:
	var key := "%s_%d_%d_%s" % [kind, w, h, variant]
	if _cache.has(key):
		return _cache[key]
	var img := PixelArt.new_image(maxi(w, 1), maxi(h, 1))
	_draw_prop(img, kind, w, h, variant)
	_detail(img, kind, w, h, variant)
	var no_outline := ["window", "drawing", "door", "poster", "panel", "blackboard", "mirror", "rug", "elevator", "labdoor", "vent", "hatch", "trap"]
	if kind not in no_outline:
		PixelArt.outline(img)
	var t := PixelArt.tex(img)
	_cache[key] = t
	return t

static func _box(img: Image, x: int, y: int, w: int, h: int, base: Color) -> void:
	PixelArt.rect(img, x, y, w, h, base)
	PixelArt.rect(img, x, y, w, 2, PixelArt.lighter(base, 1.28))
	PixelArt.rect(img, x, y, 1, h, PixelArt.lighter(base, 1.12))
	PixelArt.rect(img, x + w - 1, y, 1, h, PixelArt.darker(base, 0.75))
	PixelArt.rect(img, x, y + h - 2, w, 2, PixelArt.darker(base, 0.7))

const WOOD := Color("6c4b31")
const WOOD_D := Color("45301f")
const METAL := Color("7d838b")
const METAL_D := Color("4f545b")

static func _draw_prop(img: Image, kind: String, w: int, h: int, variant: String) -> void:
	match kind:
		"bed", "hospital_bed":
			var cloth := Color("5d7aa6") if kind == "bed" else Color("d5d8d0")
			var vertical := h >= w
			_box(img, 0, 0, w, h, WOOD_D if kind == "bed" else METAL)
			if vertical:
				_box(img, 1, 3, w - 2, h - 5, Color("c9c1ac") if kind == "bed" else Color("e6e8e2"))
				PixelArt.rect(img, 2, 4, w - 4, 6, Color("e8e2d2"))
				PixelArt.rect(img, 1, h / 2, w - 2, h / 2 - 3, cloth)
				PixelArt.rect(img, 1, h / 2, w - 2, 1, PixelArt.lighter(cloth, 1.25))
			else:
				_box(img, 3, 1, w - 5, h - 2, Color("c9c1ac"))
				PixelArt.rect(img, 4, 2, 6, h - 4, Color("e8e2d2"))
				PixelArt.rect(img, w / 2, 1, w / 2 - 3, h - 2, cloth)
		"wardrobe":
			_box(img, 0, 0, w, h, WOOD)
			PixelArt.rect(img, 2, 2, w - 4, h - 4, PixelArt.darker(WOOD, 0.85))
			PixelArt.rect(img, w / 2, 2, 1, h - 4, WOOD_D)
			PixelArt.rect(img, w / 2 - 3, h / 2, 1, 3, Color("d2b26a"))
			PixelArt.rect(img, w / 2 + 2, h / 2, 1, 3, Color("d2b26a"))
		"desk", "reception":
			_box(img, 0, 0, w, h, WOOD)
			PixelArt.rect(img, 1, 1, w - 2, h / 2, PixelArt.lighter(WOOD, 1.2))
			PixelArt.rect(img, 3, 3, 5, 3, Color("e0dac6"))   # papel
			PixelArt.rect(img, w - 6, 3, 3, 4, Color("39342c"))
			PixelArt.rect(img, 2, h / 2 + 2, w - 4, 1, WOOD_D)
			PixelArt.rect(img, w / 2 - 1, h / 2 + 3, 3, 1, Color("d2b26a"))
		"drawers", "dresser":
			_box(img, 0, 0, w, h, WOOD)
			for r in range(4, h - 3, 5):
				PixelArt.rect(img, 2, r, w - 4, 1, WOOD_D)
				PixelArt.rect(img, w / 2 - 1, r + 2, 3, 1, Color("d2b26a"))
		"toybox":
			_box(img, 0, 3, w, h - 3, Color("a04848"))
			PixelArt.rect(img, 0, 0, w, 4, Color("4a6fa5"))
			PixelArt.rect(img, 2, 5, 3, 3, Color("e6c36a"))
			PixelArt.rect(img, w - 6, 6, 3, 3, Color("5d9a6a"))
		"window":
			PixelArt.rect(img, 0, 0, w, h, Color("3c3a32"))
			PixelArt.rect(img, 2, 2, w - 4, h - 4, Color("1c2638"))
			PixelArt.rect(img, 3, 3, w - 6, 4, Color("2a3a56"))
			PixelArt.rect(img, w / 2, 2, 1, h - 4, Color("3c3a32"))
			PixelArt.rect(img, 2, h / 2, w - 4, 1, Color("3c3a32"))
			PixelArt.ellipse(img, w * 0.7, 5, 2, 2, Color("c9cdb8"))
		"door", "labdoor":
			var door := Color("5a3d28") if kind == "door" else Color("8c9096")
			if variant == "organic":
				door = Color("6a2230")
			PixelArt.rect(img, 1, 0, w - 2, h, PixelArt.darker(door, 0.55))
			PixelArt.rect(img, 2, 1, w - 4, h - 1, door)
			PixelArt.rect(img, 3, 2, w - 6, 5, PixelArt.lighter(door, 1.12))
			PixelArt.rect(img, 3, 8, w - 6, 6, PixelArt.lighter(door, 1.05))
			PixelArt.rect(img, w - 5, h / 2, 2, 2, Color("d2b26a"))
			if kind == "labdoor":
				PixelArt.rect(img, 2, 1, w - 4, 1, Color("8e2f2f"))
		"drawing":
			PixelArt.rect(img, 2, 1, w - 4, h - 3, Color("d8cfb6"))
			PixelArt.rect(img, 2, 1, w - 4, 1, Color("ece4cc"))
			var parts := variant.split(":")
			var icon := parts[0] if parts.size() > 0 else "sun"
			var n := int(parts[1]) if parts.size() > 1 else 1
			var spots := [Vector2i(4, 3), Vector2i(9, 3), Vector2i(4, 8), Vector2i(9, 8)]
			for i in mini(n, 4):
				var s: Vector2i = spots[i]
				match icon:
					"sun":
						PixelArt.rect(img, s.x, s.y, 3, 3, Color("e0b030"))
						PixelArt.px(img, s.x + 1, s.y - 1, Color("e0b030"))
						PixelArt.px(img, s.x - 1, s.y + 1, Color("e0b030"))
					"house":
						PixelArt.rect(img, s.x, s.y + 1, 3, 3, Color("a04848"))
						PixelArt.px(img, s.x + 1, s.y, Color("5a3d28"))
					"tree":
						PixelArt.rect(img, s.x + 1, s.y + 2, 1, 2, Color("5a3d28"))
						PixelArt.rect(img, s.x, s.y, 3, 2, Color("4f8a4f"))
					"star":
						PixelArt.px(img, s.x + 1, s.y, Color("3a5aa0"))
						PixelArt.rect(img, s.x, s.y + 1, 3, 1, Color("3a5aa0"))
						PixelArt.px(img, s.x + 1, s.y + 2, Color("3a5aa0"))
					"spiral":
						PixelArt.rect(img, s.x, s.y, 4, 4, Color("5a2a2a"))
						PixelArt.rect(img, s.x + 1, s.y + 1, 2, 2, Color("d8cfb6"))
						PixelArt.px(img, s.x + 2, s.y + 2, Color("5a2a2a"))
					_:
						PixelArt.rect(img, s.x, s.y, 3, 3, Color("6a6a6a"))
		"poster":
			PixelArt.rect(img, 1, 1, w - 2, h - 3, Color("c9b98a"))
			PixelArt.rect(img, 3, 3, w - 6, 3, Color("7a4a3a"))
			PixelArt.rect(img, 3, 8, w - 6, 1, Color("5a5a4a"))
		"medkit":
			PixelArt.rect(img, 0, 1, w, h - 1, Color("e6e6e0"))
			PixelArt.rect(img, 0, 1, w, 1, Color("ffffff"))
			PixelArt.rect(img, w / 2 - 1, 2, 2, h - 3, Color("b02828"))
			PixelArt.rect(img, w / 2 - 3, h / 2, 6, 2, Color("b02828"))
			PixelArt.rect(img, w / 2 - 2, 0, 4, 1, Color("8a8a84"))
		"roundtable":
			var cloth := Color("b03a6a") if variant == "pink" else Color("8a8a7a")
			PixelArt.ellipse(img, w / 2.0, h / 2.0 + 1.0, w / 2.0 - 0.5, h / 2.0 - 2.0, PixelArt.darker(cloth, 0.6))
			PixelArt.ellipse(img, w / 2.0, h / 2.0 - 1.0, w / 2.0 - 1.0, h / 2.0 - 3.0, cloth)
			PixelArt.ellipse(img, w / 2.0 - 2.0, h / 2.0 - 3.0, w / 4.0, h / 6.0, PixelArt.lighter(cloth, 1.25))
			for k in range(3, w - 3, 4):
				PixelArt.px(img, k, h - 4, PixelArt.darker(cloth, 0.5))
		"counter":
			_box(img, 0, 3, w, h - 3, Color("8a8a80"))
			PixelArt.rect(img, 0, 0, w, 4, Color("c9c9be"))
			PixelArt.rect(img, 0, 3, w, 1, Color("5a5a54"))
			for x in range(3, w - 3, 6):
				PixelArt.rect(img, x, h - 7, 4, 4, Color("6a6a62"))
				PixelArt.px(img, x + 2, h - 6, Color("d2b26a"))
		"stove":
			_box(img, 0, 2, w, h - 2, Color("d0d0c4"))
			PixelArt.rect(img, 2, 3, w - 4, 4, Color("2a2a2a"))
			for x in [4, w - 6]:
				PixelArt.ellipse(img, x + 1, 5, 2, 2, Color("5a1a1a"))
			PixelArt.rect(img, 2, h - 8, w - 4, 5, Color("3a3a3a"))
			PixelArt.rect(img, 3, h - 7, w - 6, 3, Color("6a5a3a"))
		"plant":
			PixelArt.rect(img, w / 2 - 3, h - 5, 6, 5, Color("6a4030"))
			PixelArt.rect(img, w / 2 - 3, h - 5, 6, 1, Color("8a5a40"))
			for k in 6:
				var dx := (k - 3) * 2
				PixelArt.rect(img, w / 2 + dx / 2, h - 8 - k * 2, 1, 4 + k, Color("4a3a24"))
				PixelArt.px(img, w / 2 + dx, h - 9 - k * 2, Color("6a5a30"))
		"hole":
			PixelArt.ellipse(img, w / 2.0, h / 2.0, w / 2.0 - 0.5, h / 2.0 - 1.5, Color("6e2434"))
			PixelArt.ellipse(img, w / 2.0, h / 2.0 + 0.5, w / 2.0 - 2.5, h / 2.0 - 3.0, Color("0a0204"))
			PixelArt.px(img, 3, 4, Color("c06a7e"))
			PixelArt.px(img, w - 4, 5, Color("c06a7e"))
			PixelArt.rect(img, 5, h - 4, 2, 2, Color("8a2f3e"))
			PixelArt.rect(img, w - 7, h - 5, 2, 3, Color("8a2f3e"))
		"trap":
			PixelArt.rect(img, 1, 2, w - 2, h - 4, Color("120c08"))
			for i in 4:
				PixelArt.rect(img, 1 + i * 4, 1 + (i % 2) * 2, 3, h / 2 - (i % 2), Color("6a4a2c"))
				PixelArt.rect(img, 2 + i * 4, h - 5 + (i % 2), 3, 4 - (i % 2), Color("5a3c22"))
			PixelArt.px(img, 5, 8, Color("c0a070"))
			PixelArt.px(img, 10, 7, Color("c0a070"))
		"bear":
			PixelArt.ellipse(img, 4, 5, 3, 3, Color("9a6a3e"))
			PixelArt.ellipse(img, 4, 2, 2, 2, Color("b07c4a"))
			PixelArt.px(img, 2, 0, Color("9a6a3e"))
			PixelArt.px(img, 6, 0, Color("9a6a3e"))
			PixelArt.px(img, 3, 2, Color("17121a"))
			PixelArt.px(img, 5, 2, Color("17121a"))
		"note", "paper":
			PixelArt.rect(img, 0, 1, w, h - 1, Color("e0d8bc"))
			PixelArt.rect(img, 1, 3, w - 2, 1, Color("6a6458"))
			PixelArt.rect(img, 1, 5, w - 3, 1, Color("6a6458"))
		"photo":
			PixelArt.rect(img, 0, 0, w, h, Color("d8d2c0"))
			PixelArt.rect(img, 1, 1, w - 2, h - 3, Color("5c564a"))
			PixelArt.px(img, 3, 3, Color("b8b09a"))
			PixelArt.px(img, 5, 3, Color("b8b09a"))
		"key":
			PixelArt.ellipse(img, 2, 2, 2, 2, Color("d2b26a"))
			PixelArt.rect(img, 3, 3, w - 3, 1, Color("d2b26a"))
			PixelArt.px(img, w - 2, 4, Color("d2b26a"))
		"battery":
			PixelArt.rect(img, 0, 1, w, h - 1, Color("4a7a4a"))
			PixelArt.rect(img, w / 2 - 1, 0, 2, 1, Color("c0c0c0"))
			PixelArt.rect(img, 1, 3, w - 2, 1, Color("e0d060"))
		"musicbox":
			_box(img, 0, 2, w, h - 2, Color("7a4a3a"))
			PixelArt.rect(img, 1, 0, w - 2, 3, Color("9a6a4a"))
			PixelArt.px(img, w - 3, h / 2, Color("d2b26a"))
		"bucket":
			_box(img, 1, 3, w - 2, h - 3, METAL)
			PixelArt.rect(img, 1, 2, w - 2, 1, METAL_D)
			PixelArt.rect(img, 2, 0, w - 4, 1, METAL_D)
		"lamp":
			PixelArt.rect(img, w / 2, 5, 1, h - 7, METAL_D)
			PixelArt.rect(img, w / 2 - 3, h - 2, 7, 2, METAL_D)
			PixelArt.rect(img, w / 2 - 3, 1, 7, 4, Color("d9b86a"))
			PixelArt.rect(img, w / 2 - 2, 4, 5, 1, Color("fff0b0"))
		"chair":
			_box(img, 1, h / 2, w - 2, h / 2, WOOD)
			PixelArt.rect(img, 1, 0, w - 2, h / 2, WOOD_D)
		"table":
			_box(img, 0, 0, w, h, WOOD)
			PixelArt.rect(img, 1, 1, w - 2, h - 5, PixelArt.lighter(WOOD, 1.18))
		"bench":
			_box(img, 0, 2, w, h - 2, WOOD)
			PixelArt.rect(img, 0, 0, w, 2, WOOD_D)
		"crib":
			_box(img, 0, 0, w, h, Color("b9b19a"))
			PixelArt.rect(img, 2, 3, w - 4, h - 6, Color("6f6a5a"))
			for x in range(2, w - 2, 3):
				PixelArt.rect(img, x, 1, 1, h - 3, Color("e0dac6"))
		"blackboard":
			PixelArt.rect(img, 0, 0, w, h, Color("5a3d28"))
			PixelArt.rect(img, 1, 1, w - 2, h - 3, Color("203428"))
			PixelArt.rect(img, 3, 3, w - 10, 1, Color("c9d0c0"))
			PixelArt.rect(img, 3, 6, w - 14, 1, Color("c9d0c0"))
			PixelArt.rect(img, 3, 9, 5, 1, Color("c9d0c0"))
		"schooldesk":
			_box(img, 0, 0, w, h, WOOD)
			PixelArt.rect(img, 2, 2, w - 4, 3, PixelArt.lighter(WOOD, 1.2))
		"pillar":
			_box(img, 1, 0, w - 2, h, Color("6e6a5c"))
			PixelArt.rect(img, 0, 0, w, 3, Color("8a8570"))
			PixelArt.rect(img, 0, h - 3, w, 3, Color("8a8570"))
		"stairs":
			for i in range(0, h, 3):
				PixelArt.rect(img, 0, i, w, 2, Color("6a6652") if (i / 3) % 2 == 0 else Color("524f40"))
				PixelArt.rect(img, 0, i + 2, w, 1, Color("2a2820"))
		"hatch":
			PixelArt.rect(img, 0, 0, w, h, Color("2a2218"))
			PixelArt.rect(img, 1, 1, w - 2, h - 2, Color("5a4228"))
			for x in range(3, w - 2, 4):
				PixelArt.rect(img, x, 1, 1, h - 2, Color("3a2a18"))
			PixelArt.ellipse(img, w / 2, h / 2, 2, 2, Color("b8b8b0"))
			PixelArt.ellipse(img, w / 2, h / 2, 1, 1, Color("2a2218"))
		"panel":
			PixelArt.rect(img, 1, 1, w - 2, h - 2, METAL_D)
			PixelArt.rect(img, 2, 2, w - 4, h - 4, METAL)
			for i in 4:
				PixelArt.rect(img, 3 + i * 3, 4, 2, 5, Color("2c2f33"))
				PixelArt.rect(img, 3 + i * 3, 4 + (i % 2) * 3, 2, 2, Color("d9d070"))
			PixelArt.rect(img, 2, h - 5, w - 4, 2, Color("d2a020"))
		"terminal", "console":
			_box(img, 0, h / 3, w, h - h / 3, METAL_D)
			PixelArt.rect(img, 2, 1, w - 4, h / 2, Color("202428"))
			PixelArt.rect(img, 3, 2, w - 6, h / 2 - 2, Color("2c6a48"))
			PixelArt.rect(img, 4, 3, w - 10, 1, Color("8affc0"))
			PixelArt.rect(img, 4, 5, w - 12, 1, Color("8affc0"))
			PixelArt.rect(img, 2, h - 5, w - 4, 2, Color("33373c"))
		"capsule":
			_box(img, 1, h - 6, w - 2, 6, METAL_D)
			PixelArt.rect(img, 2, 2, w - 4, h - 8, Color("5a8a80"))
			PixelArt.rect(img, 3, 3, w - 6, h - 10, Color("8ab8a8"))
			PixelArt.rect(img, 3, 3, 1, h - 10, Color("d8f0e8"))
			PixelArt.rect(img, 1, 0, w - 2, 3, METAL)
			if variant == "broken":
				PixelArt.rect(img, 5, 5, 1, 8, Color("1c1c1c"))
				PixelArt.rect(img, 6, 12, 3, 1, Color("1c1c1c"))
		"surgery":
			_box(img, 0, 0, w, h, Color("aeb4b2"))
			PixelArt.rect(img, 2, 2, w - 4, h - 4, Color("d5dad8"))
			PixelArt.rect(img, 0, h / 3, w, 2, Color("5a4a3a"))
			PixelArt.rect(img, 0, h * 2 / 3, w, 2, Color("5a4a3a"))
			PixelArt.rect(img, 4, h - 8, 3, 3, Color("8e2f2f"))
		"locker", "cabinet":
			_box(img, 0, 0, w, h, Color("6a7a80") if kind == "locker" else METAL)
			PixelArt.rect(img, w / 2, 2, 1, h - 4, METAL_D)
			for r in range(3, h - 4, 6):
				PixelArt.rect(img, 2, r, w / 2 - 3, 1, METAL_D)
			PixelArt.rect(img, w / 2 - 2, h / 2, 1, 3, Color("c0c0b0"))
		"vent":
			PixelArt.ellipse(img, w / 2.0, h / 2.0, w / 2.0 - 1, h / 2.0 - 1, Color("6a2230"))
			PixelArt.ellipse(img, w / 2.0, h / 2.0, w / 2.0 - 4, h / 2.0 - 4, Color("120406"))
			PixelArt.px(img, 3, 3, Color("c06a7e"))
		"tissue":
			PixelArt.rect(img, 0, 0, w, h, Color("7a2c3c"))
			var rng := RandomNumberGenerator.new()
			rng.seed = w * 131 + h
			for i in (w * h) / 6:
				var x := rng.randi_range(0, w - 1)
				var y := rng.randi_range(0, h - 1)
				img.set_pixel(x, y, Color("c06a7e") if i % 3 == 0 else Color("3a1018"))
			for i in maxi(w / 6, 2):
				var vx := rng.randi_range(2, w - 3)
				for k in range(0, h):
					PixelArt.px(img, vx + int(sin(k * 0.8 + i) * 1.5), k, Color("2a0a12"))
			PixelArt.rect(img, 0, h - 3, w, 3, Color("4a1420"))
			PixelArt.rect(img, 0, 0, w, 2, Color("a04558"))
		"cocoon":
			PixelArt.ellipse(img, w / 2.0, h / 2.0, w / 2.0 - 1, h / 2.0 - 1, Color("a66a74"))
			PixelArt.ellipse(img, w / 2.0 - 1, h / 2.0 - 2, w / 4.0, h / 4.0, Color("d9a0a8"))
			PixelArt.rect(img, w / 2, 3, 1, h - 6, Color("5a2030"))
		"elevator":
			PixelArt.rect(img, 0, 0, w, h, METAL_D)
			PixelArt.rect(img, 2, 2, w / 2 - 2, h - 2, METAL)
			PixelArt.rect(img, w / 2, 2, w / 2 - 2, h - 2, PixelArt.darker(METAL, 0.92))
			PixelArt.rect(img, w / 2, 2, 1, h - 2, METAL_D)
			PixelArt.rect(img, w / 2 - 2, 0, 4, 2, Color("8e2f2f"))
		"reactor", "boiler":
			_box(img, 0, 6, w, h - 6, METAL_D)
			PixelArt.rect(img, 3, 8, w - 6, h - 14, Color("3a1a1a") if kind == "reactor" else Color("5a3a2a"))
			PixelArt.ellipse(img, w / 2.0, h / 2.0 + 2, w / 4.0, h / 5.0, Color("c03030") if kind == "reactor" else Color("c07030"))
			PixelArt.rect(img, w / 2 - 2, 0, 4, 7, METAL)
			PixelArt.rect(img, 2, h - 5, w - 4, 2, Color("8e2f2f"))
		"fridge":
			_box(img, 0, 0, w, h, Color("c8cac2"))
			PixelArt.rect(img, 1, h / 3, w - 2, 1, METAL_D)
			PixelArt.rect(img, w - 4, 3, 1, 5, METAL_D)
		"mirror":
			PixelArt.rect(img, 2, 1, w - 4, h - 3, Color("4a4036"))
			PixelArt.rect(img, 3, 2, w - 6, h - 5, Color("9ab0b8"))
			PixelArt.rect(img, 4, 3, 2, 5, Color("d0e0e4"))
		"rug":
			PixelArt.rect(img, 0, 0, w, h, Color("6a3a3a"))
			PixelArt.rect(img, 2, 2, w - 4, h - 4, Color("8a5a4a"))
			PixelArt.rect(img, 4, 4, w - 8, h - 8, Color("6a3a3a"))
		"crate", "box":
			_box(img, 0, 0, w, h, Color("7d6240"))
			PixelArt.rect(img, 0, h / 2, w, 1, Color("4a3a24"))
		"shelf":
			_box(img, 0, 0, w, h, WOOD)
			for r in range(4, h - 2, 6):
				PixelArt.rect(img, 1, r, w - 2, 1, WOOD_D)
				for x in range(2, w - 4, 4):
					PixelArt.rect(img, x, r - 3, 3, 3, [Color("a04848"), Color("4a6fa5"), Color("c9b070")][(x / 4) % 3])
		"statue":
			PixelArt.ellipse(img, w / 2.0, h - 4.0, w / 2.0 - 1, 3, Color("5a574c"))
			PixelArt.rect(img, w / 2 - 2, 4, 4, h - 8, Color("8a8676"))
			PixelArt.ellipse(img, w / 2.0, 4, 3, 3, Color("a29e8a"))
		_:
			_box(img, 0, 0, w, h, Color("6a6a6a"))

## Acabamento comum a todos os props: sujeira, desgaste, brilho de borda e detalhes por tipo.
static func _detail(img: Image, kind: String, w: int, h: int, variant: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = (kind + variant).hash() + w * 31 + h
	var metal := kind in ["panel", "terminal", "console", "capsule", "locker", "cabinet", "boiler", "reactor", "bucket", "elevator", "labdoor", "surgery", "fridge", "stove"]
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var hv := PixelArt.hash2(x, y, w + h)
			if hv % 23 == 0:
				img.set_pixel(x, y, PixelArt.darker(c, 0.8))            # sujeira
			elif hv % 41 == 0:
				img.set_pixel(x, y, PixelArt.lighter(c, 1.2))           # lascas/brilhos
			if metal and hv % 29 == 1 and y > 1:
				img.set_pixel(x, y, Color(c.r * 0.85 + 0.12, c.g * 0.7 + 0.04, c.b * 0.55, c.a))   # ferrugem
			if y >= h - 2 and kind not in ["rug", "drawing", "poster", "window", "door", "labdoor", "panel", "elevator", "blackboard", "mirror", "hole", "trap", "vent", "hatch"]:
				img.set_pixel(x, y, PixelArt.darker(img.get_pixel(x, y), 0.88))   # oclusão no chão
	match kind:
		"door", "labdoor":
			PixelArt.rect(img, 4, 3, 3, 2, Color(0.82, 0.78, 0.6, 0.9))    # plaquinha
			for k in 3:
				PixelArt.px(img, 3 + rng.randi_range(0, w - 7), 2 + rng.randi_range(0, h - 4), Color(0.1, 0.07, 0.05))
			if variant == "organic":
				for k in h - 3:
					PixelArt.px(img, 5 + int(sin(k * 0.7) * 2), 1 + k, Color("3a1018"))
		"window":
			PixelArt.rect(img, 0, 0, 3, h, Color("4a2a30"))                  # cortina rasgada
			PixelArt.rect(img, w - 3, 0, 3, h - 3, Color("4a2a30"))
			for k in 3:
				PixelArt.px(img, 1, h - 1 - k, Color(0, 0, 0, 0))
			PixelArt.rect(img, w / 2 - 1, 4, 1, 3, Color(0.9, 0.9, 1.0, 0.5))
		"bed", "hospital_bed":
			for k in range(3, h - 4, 4):
				PixelArt.rect(img, 2, k, w - 4, 1, Color(0, 0, 0, 0.22))     # dobras
			PixelArt.rect(img, 3, 3, 2, 2, Color(0.55, 0.15, 0.15, 0.7))     # mancha
		"wardrobe":
			PixelArt.rect(img, 1, 1, w - 2, 1, PixelArt.lighter(WOOD, 1.4))
			PixelArt.px(img, w / 2 - 1, h / 2 + 4, Color("120c08"))
			for k in 4:
				PixelArt.px(img, w / 2 + 2 + k / 2, 4 + k * 2, Color("120c08")) # rachadura
		"capsule":
			for k in 4:
				PixelArt.px(img, 4 + (k * 3) % (w - 8), 6 + (k * 5) % (maxi(h - 16, 3)), Color(0.9, 1.0, 0.95, 0.8))  # bolhas
			PixelArt.rect(img, w / 2 - 1, 0, 1, 3, Color("1a1a1a"))          # cabos
			PixelArt.rect(img, w / 2 + 2, 0, 1, 4, Color("8e2f2f"))
		"console", "terminal":
			for k in 4:
				PixelArt.px(img, 2 + k * 3, h - 4, [Color("e04040"), Color("40e060"), Color("e0c040"), Color("40a0e0")][k])
			for k in range(2, w - 3, 2):
				PixelArt.px(img, k, h - 6, Color(0.7, 0.7, 0.72))
		"boiler", "reactor":
			for k in range(2, w - 2, 4):
				PixelArt.px(img, k, 8, Color(0.7, 0.7, 0.72))
				PixelArt.px(img, k, h - 5, Color(0.7, 0.7, 0.72))
		"locker", "cabinet":
			for k in 3:
				PixelArt.rect(img, 3, 3 + k * 2, w / 2 - 4, 1, Color(0.05, 0.05, 0.06))   # frestas
			PixelArt.rect(img, w - 6, h / 2 - 3, 4, 3, Color(0.85, 0.82, 0.7))             # etiqueta
		"desk", "reception":
			PixelArt.rect(img, 2, 2, 2, 2, Color(0.12, 0.1, 0.25, 0.8))                    # mancha de tinta
		"bucket":
			PixelArt.rect(img, 3, 5, w - 6, 1, Color(0.35, 0.2, 0.1, 0.8))
