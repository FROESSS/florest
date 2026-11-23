class_name ArtFX
extends RefCounted
## Passes de acabamento visual (pixel art procedural): zonas de piso, deterioração das paredes,
## crescimento orgânico, teias, vigas/canos e objetos soltos. Tudo determinístico por sala.

const T := 16

static func _rng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r

static func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var o := img.get_pixel(x, y)
	img.set_pixel(x, y, o.lerp(Color(c.r, c.g, c.b, 1.0), c.a))

static func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(int(cy - r) - 1, int(cy + r) + 2):
		for x in range(int(cx - r) - 1, int(cx + r) + 2):
			if Vector2(x - cx, y - cy).length() <= r:
				_blend(img, x, y, c)

# ---------- Zonas de piso (tabuleiro, carpete, concreto, madeira escura) ----------

static func floor_zones(img: Image, zones: Array, wall: PackedByteArray, w: int, seed_v: int) -> void:
	for z in zones:
		var r: Array = z["rect"]
		var kind := str(z.get("kind", "checker"))
		for ty in range(int(r[1]), int(r[1]) + int(r[3])):
			for tx in range(int(r[0]), int(r[0]) + int(r[2])):
				if wall[ty * w + tx] == 1:
					continue
				_zone_tile(img, tx, ty, kind, z, seed_v)

static func _zone_tile(img: Image, tx: int, ty: int, kind: String, z: Dictionary, seed_v: int) -> void:
	var x0 := tx * T
	var y0 := ty * T
	var a := Color(z.get("a", "#bdbfb0"))
	var b := Color(z.get("b", "#2c2d33"))
	for y in T:
		for x in T:
			var c := a
			var hv := PixelArt.hash2(x0 + x, y0 + y, seed_v)
			match kind:
				"checker":
					c = a if ((x / 8) + (y / 8) + tx + ty) % 2 == 0 else b
					if hv % 9 == 0:
						c = TileArtShade.shade(c, 0.85)
				"carpet":
					c = a if (x + y) % 4 != 0 else TileArtShade.shade(a, 0.86)
					if hv % 11 == 0:
						c = TileArtShade.shade(c, 0.8)
				"concrete":
					c = a
					if hv % 7 == 0:
						c = TileArtShade.shade(a, 0.84)
					elif hv % 13 == 0:
						c = TileArtShade.shade(a, 1.1)
				_:
					c = a if (y / 4) % 2 == 0 else TileArtShade.shade(a, 0.9)
					if hv % 17 == 0:
						c = TileArtShade.shade(c, 0.7)
			img.set_pixel(x0 + x, y0 + y, c)
	if kind == "concrete":
		img.fill_rect(Rect2i(x0, y0 + T - 1, T, 1), TileArtShade.shade(a, 0.7))
	# sombra da parede continua nas zonas
	if ty > 0 and img.get_pixel(x0 + 2, y0 - 1).a > 0.0:
		pass

# ---------- Deterioração das paredes ----------

static func wall_decay(img: Image, wall: PackedByteArray, w: int, h: int, theme_name: String, seed_v: int) -> void:
	var rng := _rng(seed_v + 77)
	for ty in h - 1:
		for tx in w:
			if wall[ty * w + tx] != 1 or wall[(ty + 1) * w + tx] != 0:
				continue
			var x0 := tx * T
			var y0 := ty * T
			# manchas de infiltração (vertical, translúcidas)
			if rng.randf() < 0.45:
				var sx := x0 + rng.randi_range(1, 14)
				var len := rng.randi_range(5, 14)
				for k in len:
					_blend(img, sx, y0 + k, Color(0.05, 0.04, 0.03, 0.30 - k * 0.012))
					if k % 3 == 0:
						_blend(img, sx + 1, y0 + k, Color(0.05, 0.04, 0.03, 0.12))
			# reboco caído (revela tijolo escuro)
			if rng.randf() < 0.3 and theme_name != "lab":
				var px := x0 + rng.randi_range(2, 9)
				var py := y0 + rng.randi_range(1, 7)
				var ww := rng.randi_range(3, 6)
				var hh := rng.randi_range(2, 4)
				for yy in hh:
					for xx in ww:
						if (xx + yy) % 4 != 3:
							_blend(img, px + xx, py + yy, Color(0.18, 0.13, 0.1, 0.8))
				for xx in ww:
					_blend(img, px + xx, py + hh, Color(0.9, 0.85, 0.75, 0.25))
			# rachadura
			if rng.randf() < 0.22:
				var cx := x0 + rng.randi_range(3, 12)
				var cy := y0
				for k in rng.randi_range(6, 13):
					_blend(img, cx, cy + k, Color(0.03, 0.03, 0.03, 0.85))
					cx += rng.randi_range(-1, 1)
			# lab: riscos de ferrugem/sujeira
			if theme_name == "lab" and rng.randf() < 0.4:
				for k in rng.randi_range(3, 9):
					_blend(img, x0 + rng.randi_range(0, 15), y0 + k, Color(0.4, 0.2, 0.1, 0.25))

# ---------- Vigas, canos e teias ----------

static func ceiling_fixtures(img: Image, wall: PackedByteArray, w: int, h: int, theme_name: String, seed_v: int) -> void:
	var rng := _rng(seed_v + 5)
	# canos horizontais ao longo da parede norte (lab/orgânico) ou vigas (orfanato)
	for tx in w:
		if wall[1 * w + tx] != 1 or wall[2 * w + tx] != 0:
			continue
		var x0 := tx * T
		var y0 := T
		if theme_name == "lab" or theme_name == "organico":
			var pc := Color("8c9096") if theme_name == "lab" else Color("7a2c3c")
			img.fill_rect(Rect2i(x0, y0 + 2, T, 3), pc)
			img.fill_rect(Rect2i(x0, y0 + 2, T, 1), TileArtShade.shade(pc, 1.3))
			img.fill_rect(Rect2i(x0, y0 + 4, T, 1), TileArtShade.shade(pc, 0.6))
			if tx % 4 == 0:
				img.fill_rect(Rect2i(x0 + 1, y0 + 1, 2, 5), TileArtShade.shade(pc, 0.75))
			if rng.randf() < 0.15 and theme_name == "organico":
				for k in 6:
					_blend(img, x0 + 8, y0 + 5 + k, Color(0.8, 0.2, 0.3, 0.7 - k * 0.1))
		elif tx % 5 == 2:
			img.fill_rect(Rect2i(x0, y0 + 1, 3, 4), Color("3a2a1c"))
			img.fill_rect(Rect2i(x0, y0 + 1, 3, 1), Color("5c4630"))
	# teias nos cantos internos superiores
	for ty in range(2, h - 1):
		for tx in range(1, w - 1):
			if wall[ty * w + tx] == 1:
				continue
			var up := wall[(ty - 1) * w + tx] == 1
			var left := wall[ty * w + tx - 1] == 1
			var right := wall[ty * w + tx + 1] == 1
			if up and (left or right) and rng.randf() < 0.8:
				_cobweb(img, tx * T + (0 if left else T), ty * T, 1 if left else -1)

static func _cobweb(img: Image, x: int, y: int, dir: int) -> void:
	var c := Color(0.85, 0.85, 0.8, 0.35)
	for k in 8:
		_blend(img, x + dir * k, y + 0, c)
		_blend(img, x, y + k, c)
		_blend(img, x + dir * (k * 6 / 8), y + k * 6 / 8, c)
	for r in [3, 5, 7]:
		for k in r:
			_blend(img, x + dir * (r - k), y + k, Color(0.85, 0.85, 0.8, 0.25))

# ---------- Crescimento orgânico (tentáculos/veias sobre piso e parede) ----------

static func overgrowth(img: Image, wall: PackedByteArray, w: int, h: int, density: float, seed_v: int) -> void:
	if density <= 0.0:
		return
	var rng := _rng(seed_v + 311)
	var starts: Array[Vector2] = []
	for ty in range(2, h - 1):
		for tx in range(1, w - 1):
			if wall[ty * w + tx] == 1:
				continue
			if wall[(ty - 1) * w + tx] == 1 or wall[ty * w + tx - 1] == 1 or wall[ty * w + tx + 1] == 1 or wall[(ty + 1) * w + tx] == 1:
				starts.append(Vector2(tx * T + 8, ty * T + 8))
	var n := int(starts.size() * density * 0.35)
	for i in n:
		var p: Vector2 = starts[rng.randi() % starts.size()] + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		_tentacle(img, wall, w, h, p, rng, rng.randi_range(28, 90))
	# massas pulsantes/bolhas
	for i in int(n * 0.4):
		var q: Vector2 = starts[rng.randi() % starts.size()]
		_disc(img, q.x + rng.randf_range(-5, 5), q.y + rng.randf_range(-5, 5), rng.randf_range(1.5, 3.5), Color(0.45, 0.12, 0.22, 0.85))
		_disc(img, q.x - 1, q.y - 1, 1.0, Color(0.85, 0.45, 0.55, 0.7))
	# veias subindo pelas paredes
	for ty in h - 1:
		for tx in w:
			if wall[ty * w + tx] == 1 and wall[(ty + 1) * w + tx] == 0 and rng.randf() < density * 0.5:
				var vx := tx * T + rng.randi_range(2, 13)
				for k in rng.randi_range(6, 15):
					_blend(img, vx, ty * T + T - 1 - k, Color(0.25, 0.06, 0.14, 0.9))
					_blend(img, vx + 1, ty * T + T - 1 - k, Color(0.6, 0.2, 0.32, 0.45))
					vx += rng.randi_range(-1, 1)

static func _tentacle(img: Image, wall: PackedByteArray, w: int, h: int, start: Vector2, rng: RandomNumberGenerator, length: int) -> void:
	var p := start
	var ang := rng.randf() * TAU
	for i in length:
		var t := float(i) / length
		var width := lerpf(3.2, 0.8, t)
		ang += rng.randf_range(-0.4, 0.4)
		p += Vector2(cos(ang), sin(ang))
		var c := Vector2i(int(p.x) / T, int(p.y) / T)
		if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h or wall[c.y * w + c.x] == 1:
			break
		_disc(img, p.x, p.y, width * 0.5, Color(0.2, 0.05, 0.12, 0.95))
		_blend(img, int(p.x - 1), int(p.y - 1), Color(0.62, 0.22, 0.34, 0.55))
		if i % 9 == 4:
			_blend(img, int(p.x), int(p.y), Color(0.85, 0.5, 0.6, 0.6))
		if i > 14 and i % 17 == 0 and rng.randf() < 0.5:
			_tentacle(img, wall, w, h, p, rng, int((length - i) * 0.6))

# ---------- Objetos soltos no chão (assados na textura) ----------

static func clutter(img: Image, theme_name: String, wall: PackedByteArray, w: int, h: int, avoid: Array, seed_v: int, amount: float) -> void:
	var rng := _rng(seed_v + 901)
	var count := int(w * h * amount)
	for i in count:
		var tx := rng.randi_range(1, w - 2)
		var ty := rng.randi_range(2, h - 2)
		if wall[ty * w + tx] == 1:
			continue
		var pos := Vector2(tx * T + rng.randi_range(3, 12), ty * T + rng.randi_range(4, 12))
		var skip := false
		for r in avoid:
			if (r as Rect2).grow(10.0).has_point(pos):
				skip = true
				break
		if skip:
			continue
		var x := int(pos.x)
		var y := int(pos.y)
		match theme_name:
			"lab":
				if i % 3 == 0:
					_paper(img, x, y, rng)
				elif i % 3 == 1:
					_shards(img, x, y, rng)
				else:
					_cable(img, x, y, rng)
			"organico":
				if i % 2 == 0:
					_disc(img, x, y, 2.0, Color(0.62, 0.3, 0.38, 0.9))
					_blend(img, x - 1, y - 1, Color(0.95, 0.7, 0.75, 0.8))
				else:
					_bone(img, x, y, rng)
			_:
				match i % 4:
					0: _paper(img, x, y, rng)
					1: _crayon(img, x, y, rng)
					2: _can(img, x, y)
					_: _puddle(img, x, y, rng)

static func _paper(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	var c := Color(0.86, 0.82, 0.7, 0.95)
	var ww := rng.randi_range(4, 6)
	for yy in 4:
		for xx in ww:
			_blend(img, x + xx + (yy / 2), y + yy, c)
	_blend(img, x + 1, y + 1, Color(0.3, 0.28, 0.25, 0.8))
	_blend(img, x + 3, y + 2, Color(0.3, 0.28, 0.25, 0.8))

static func _crayon(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	var cols := [Color("c04040"), Color("e0b030"), Color("4060c0"), Color("40a060")]
	var c: Color = cols[rng.randi() % 4]
	for k in 4:
		_blend(img, x + k, y + (k / 3), c)
	_blend(img, x + 4, y + 1, Color(0.9, 0.9, 0.85, 0.9))

static func _can(img: Image, x: int, y: int) -> void:
	for yy in 3:
		for xx in 3:
			_blend(img, x + xx, y + yy, Color(0.55, 0.5, 0.45, 0.95))
	_blend(img, x, y, Color(0.8, 0.78, 0.7, 0.9))
	_blend(img, x + 3, y + 3, Color(0.1, 0.09, 0.08, 0.5))

static func _puddle(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	var r := rng.randf_range(2.5, 4.5)
	_disc(img, x, y, r, Color(0.08, 0.1, 0.14, 0.55))
	_blend(img, x - 1, y - 1, Color(0.6, 0.7, 0.8, 0.4))

static func _shards(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	for k in 4:
		_blend(img, x + rng.randi_range(0, 5), y + rng.randi_range(0, 4), Color(0.8, 0.9, 0.95, 0.85))

static func _cable(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	var cy := y
	for k in 9:
		_blend(img, x + k, cy, Color(0.1, 0.1, 0.12, 0.95))
		cy += rng.randi_range(-1, 1)
	_blend(img, x, y, Color(0.85, 0.7, 0.2, 0.9))

static func _bone(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	for k in 5:
		_blend(img, x + k, y + (k / 4), Color(0.86, 0.82, 0.7, 0.95))
	_blend(img, x - 1, y, Color(0.9, 0.86, 0.75, 0.95))
	_blend(img, x + 5, y + 1, Color(0.9, 0.86, 0.75, 0.95))
