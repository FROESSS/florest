class_name PixelArt
extends RefCounted
## Arte procedural original: personagens, criaturas e texturas de luz (pixel art gerada em código).

static var _frames_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}

const OUTLINE := Color("0c0b0e")

# ---------- Utilitários ----------

static func new_image(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

static func tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

static func rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	if w <= 0 or h <= 0:
		return
	var r := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, col)

static func px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)

static func outline(img: Image, col: Color = OUTLINE) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a < 0.1:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.5:
						img.set_pixel(x, y, col)
						break

static func ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				px(img, x, y, col)

static func darker(c: Color, f: float = 0.7) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)

static func lighter(c: Color, f: float = 1.25) -> Color:
	return Color(minf(c.r * f, 1.0), minf(c.g * f, 1.0), minf(c.b * f, 1.0), c.a)

static func hash2(x: int, y: int, seed_v: int = 0) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (seed_v * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))

# ---------- Personagens ----------

const STYLES := {
	"elias": {
		"skin": "e0b08c", "hair": "2a1c18", "shirt": "3f72b8", "pants": "4b4d5c", "shoes": "2a2630",
		"leg_h": 7, "torso_h": 7, "torso_w": 8, "arm_len": 6, "sleeve": 0, "hair_long": false,
	},
	"clara": {
		"skin": "ecd6c8", "hair": "1c1618", "shirt": "d9d6c6", "pants": "d9d6c6", "shoes": "b9b4a4",
		"leg_h": 7, "torso_h": 7, "torso_w": 8, "arm_len": 6, "sleeve": 3, "hair_long": true, "skirt": 8,
	},
	"caretaker": {
		"skin": "86927f", "hair": "0e0c10", "shirt": "403a40", "pants": "2b272c", "shoes": "1a171a",
		"leg_h": 11, "torso_h": 11, "torso_w": 6, "arm_len": 14, "sleeve": 14, "hair_long": true, "skirt": 7,
		"hunch": 2, "head_dx": 2, "strands": true, "glow_eyes": true, "arm_w": 2, "twitch": true,
	},
	"kid_a": {
		"skin": "dcc0a8", "hair": "5b3a24", "shirt": "9a7a3c", "pants": "55503f", "shoes": "2a2630",
		"leg_h": 6, "torso_h": 6, "torso_w": 8, "arm_len": 5, "sleeve": 2, "hair_long": false,
	},
	"kid_b": {
		"skin": "c9a58b", "hair": "161012", "shirt": "7a4a58", "pants": "3d3d4a", "shoes": "2a2630",
		"leg_h": 6, "torso_h": 6, "torso_w": 8, "arm_len": 5, "sleeve": 2, "hair_long": true,
	},
	"kid_c": {
		"skin": "e4cdb8", "hair": "b49a60", "shirt": "58705a", "pants": "4a4636", "shoes": "2a2630",
		"leg_h": 6, "torso_h": 6, "torso_w": 8, "arm_len": 5, "sleeve": 2, "hair_long": false,
	},
}

static func _style(name: String) -> Dictionary:
	var base: Dictionary = {
		"leg_h": 7, "torso_h": 7, "torso_w": 8, "arm_len": 6, "sleeve": 0, "hair_long": false, "skirt": 0,
		"hunch": 0, "head_dx": 0, "strands": false, "glow_eyes": false, "arm_w": 2, "twitch": false,
	}
	var st: Dictionary = STYLES.get(name, STYLES["elias"])
	for k in st:
		base[k] = st[k]
	for k in ["skin", "hair", "shirt", "pants", "shoes"]:
		base[k] = Color(base[k])
	return base

static func _pose(anim: String, fr: int) -> Dictionary:
	var p := {"dip": 0, "stride": 0, "lift_l": 0, "lift_r": 0, "arm": 0, "lean": 0, "reach": 0, "crouch": 0}
	match anim:
		"idle":
			p.dip = fr % 2
		"walk":
			match fr % 4:
				0: p.stride = 2; p.arm = -2; p.lift_l = 1
				1: p.dip = 1
				2: p.stride = -2; p.arm = 2; p.lift_r = 1
				3: p.dip = 1
		"run":
			match fr % 4:
				0: p.stride = 3; p.arm = -3; p.lift_l = 2; p.lean = 1
				1: p.dip = 1; p.lift_l = 1; p.lift_r = 1; p.lean = 1
				2: p.stride = -3; p.arm = 3; p.lift_r = 2; p.lean = 1
				3: p.dip = 1; p.lift_l = 1; p.lift_r = 1; p.lean = 1
		"interact":
			p.reach = 1 + (fr % 2)
		"hide":
			p.crouch = 3
			p.dip = 2
		"hit":
			p.dip = 2
			p.lean = -1
			p.arm = 2
	return p

static func character_image(style_name: String, dir: String, anim: String, fr: int) -> Image:
	var st := _style(style_name)
	if anim == "hit" and fr == 1:
		var standing := character_image(style_name, dir, "idle", 0)
		standing.rotate_90(CLOCKWISE)
		var img := new_image(32, 32)
		img.blend_rect(standing, Rect2i(0, 0, 32, 32), Vector2i(5, 8))
		return img
	var img2 := new_image(32, 32)
	var p := _pose(anim, fr)
	var twitch := 0
	if st.twitch:
		twitch = [0, 1, -1, 2][(fr + (1 if anim == "idle" else 0)) % 4] if anim != "hit" else 0
	match dir:
		"left": _draw_side(img2, st, p, twitch, anim)
		"right":
			_draw_side(img2, st, p, twitch, anim)
			img2.flip_x()
		"up": _draw_front(img2, st, p, twitch, true)
		_: _draw_front(img2, st, p, twitch, false)
	outline(img2)
	return img2

static func _draw_front(img: Image, st: Dictionary, p: Dictionary, twitch: int, back: bool) -> void:
	var cx := 16
	var leg_h: int = st.leg_h - p.crouch
	var tw: int = st.torso_w
	var feet_y := 30
	var leg_top: int = feet_y - leg_h + 1
	var torso_top: int = leg_top - int(st.torso_h) + int(p.dip) + int(st.hunch)
	var head_top: int = torso_top - 8
	var legw := 3 if tw >= 8 else 2
	var lx: int = cx - tw / 2
	var rx: int = cx + tw / 2 - legw
	var pants: Color = st.pants
	var ll: int = leg_h - int(p.lift_l)
	var rl: int = leg_h - int(p.lift_r)
	rect(img, lx, leg_top, legw, ll, pants)
	rect(img, rx, leg_top, legw, rl, darker(pants, 0.85))
	rect(img, lx, leg_top + ll - 2, legw, 2, st.shoes)
	rect(img, rx, leg_top + rl - 2, legw, 2, st.shoes)
	var shirt: Color = st.shirt
	var arm_len: int = st.arm_len
	var aw: int = st.arm_w
	var al_y: int = torso_top + 1 + int(p.arm)
	var ar_y: int = torso_top + 1 - int(p.arm)
	if p.reach > 0:
		ar_y = torso_top - int(p.reach) * 2
	_arm(img, lx - aw, al_y, aw, arm_len, st, p)
	_arm(img, lx + tw, ar_y, aw, arm_len, st, p)
	rect(img, cx - tw / 2, torso_top, tw, st.torso_h, shirt)
	rect(img, cx + tw / 2 - 1, torso_top, 1, st.torso_h, darker(shirt, 0.8))
	if st.skirt > 0:
		var top_y: int = torso_top + int(st.torso_h) - 2
		for i in int(st.skirt):
			var extra := 1 + i / 3
			rect(img, cx - tw / 2 - extra, top_y + i, tw + extra * 2, 1, shirt if i % 3 != 2 else darker(shirt, 0.85))
		if st.glow_eyes:   # barra rasgada
			for i in range(0, tw + 6, 2):
				px(img, cx - tw / 2 - 3 + i, top_y + int(st.skirt), darker(shirt, 0.7))
	# cabeça
	var hx: int = cx - 4 + int(st.head_dx) + twitch + int(p.lean)
	rect(img, hx, head_top, 8, 8, st.skin)
	var hair: Color = st.hair
	if back:
		rect(img, hx, head_top, 8, 7, hair)
		rect(img, hx + 1, head_top + 7, 6, 1, hair)
	else:
		rect(img, hx, head_top, 8, 3, hair)
		rect(img, hx, head_top + 3, 1, 2, hair)
		rect(img, hx + 7, head_top + 3, 1, 2, hair)
		var eye := Color("17121a")
		if st.glow_eyes:
			eye = Color("f2f0e0")
		px(img, hx + 2, head_top + 4, eye)
		px(img, hx + 5, head_top + 4, eye)
		if st.glow_eyes:
			px(img, hx + 2, head_top + 5, Color("17121a"))
			px(img, hx + 5, head_top + 5, Color("17121a"))
		if st.strands:
			for sx in [1, 3, 4, 6]:
				rect(img, hx + sx, head_top + 3, 1, 5, hair)
	if st.hair_long:
		var drop: int = 9 if st.strands else 6
		rect(img, hx - 1, head_top + 2, 1, drop, hair)
		rect(img, hx + 8, head_top + 2, 1, drop, hair)

static func _arm(img: Image, x: int, y: int, w: int, length: int, st: Dictionary, p: Dictionary) -> void:
	var sleeve: int = st.sleeve
	var skin: Color = st.skin
	if sleeve >= length:
		rect(img, x, y, w, length - 1, st.shirt)
		rect(img, x, y + length - 1, w, 1, skin)
		if st.glow_eyes:
			rect(img, x - 1, y + length - 1, w + 2, 2, skin)
	else:
		rect(img, x, y, w, length, skin)
		if sleeve > 0:
			rect(img, x, y, w, sleeve, st.shirt)

static func _draw_side(img: Image, st: Dictionary, p: Dictionary, twitch: int, anim: String) -> void:
	var cx := 16
	var leg_h: int = st.leg_h - p.crouch
	var tw: int = int(st.torso_w) - 2
	var feet_y := 30
	var leg_top: int = feet_y - leg_h + 1
	var torso_top: int = leg_top - int(st.torso_h) + int(p.dip) + int(st.hunch)
	var head_top: int = torso_top - 8
	var lean: int = -int(p.lean)
	var pants: Color = st.pants
	var s: int = p.stride
	var la: int = leg_h - int(p.lift_l)
	var lb: int = leg_h - int(p.lift_r)
	# perna de trás (mais escura) e da frente
	rect(img, cx - 1 + s, leg_top, 3, lb, darker(pants, 0.8))
	rect(img, cx - 1 + s, leg_top + lb - 2, 3, 2, st.shoes)
	rect(img, cx - 2 - s, leg_top, 3, la, pants)
	rect(img, cx - 2 - s, leg_top + la - 2, 3, 2, st.shoes)
	var shirt: Color = st.shirt
	var aw: int = st.arm_w
	# braço de trás
	var back_x: int = cx - 1 - int(p.arm)
	_arm(img, back_x, torso_top + 1, aw, st.arm_len, st, p)
	rect(img, cx - tw / 2 + lean, torso_top, tw, st.torso_h, shirt)
	rect(img, cx + tw / 2 - 1 + lean, torso_top, 1, st.torso_h, darker(shirt, 0.8))
	if st.skirt > 0:
		var top_y: int = torso_top + int(st.torso_h) - 2
		for i in int(st.skirt):
			var extra := i / 3
			rect(img, cx - tw / 2 - extra + lean, top_y + i, tw + extra * 2, 1, shirt if i % 3 != 2 else darker(shirt, 0.85))
	# braço da frente
	if p.reach > 0:
		rect(img, cx - 3 - int(p.reach) * 2, torso_top + 3, 3 + int(p.reach) * 2, aw, st.skin)
	else:
		_arm(img, cx - 1 + int(p.arm), torso_top + 1, aw, st.arm_len, st, p)
	# cabeça
	var hx: int = cx - 3 + int(st.head_dx) + twitch + lean - (1 if st.head_dx > 0 else 0)
	rect(img, hx, head_top, 7, 8, st.skin)
	var hair: Color = st.hair
	rect(img, hx, head_top, 7, 3, hair)
	rect(img, hx + 3, head_top + 3, 4, 3, hair)
	px(img, hx - 1, head_top + 4, st.skin)
	var eye := Color("17121a")
	if st.glow_eyes:
		eye = Color("f2f0e0")
	px(img, hx + 1, head_top + 4, eye)
	if st.hair_long:
		rect(img, hx + 3, head_top + 5, 4, 7 if st.strands else 5, hair)
	if st.strands:
		rect(img, hx, head_top + 3, 1, 4, hair)

# ---------- SpriteFrames ----------

static func character_frames(style_name: String) -> SpriteFrames:
	if _frames_cache.has(style_name):
		return _frames_cache[style_name]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var defs := {
		"idle": [2, 2.0, true], "walk": [4, 7.0, true], "run": [4, 11.0, true],
		"interact": [2, 5.0, false], "hide": [1, 1.0, false], "hit": [2, 3.0, false],
	}
	for dir in ["down", "up", "left", "right"]:
		for anim in defs:
			var n: int = defs[anim][0]
			var aname := "%s_%s" % [anim, dir]
			sf.add_animation(aname)
			sf.set_animation_speed(aname, defs[anim][1])
			sf.set_animation_loop(aname, defs[anim][2])
			for f in n:
				sf.add_frame(aname, tex(character_image(style_name, dir, anim, f)))
	_frames_cache[style_name] = sf
	return sf

# ---------- O Morador ----------

static func resident_image(frame: int, anim: String, grow: float = 1.0) -> Image:
	var img := new_image(48, 48)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7041
	var pulse := sin(frame * PI / 2.0) * 1.2
	var sway := 0.0
	if anim == "walk":
		sway = [-2.0, 0.0, 2.0, 0.0][frame % 4]
	var flesh := Color("8a2f3e")
	var flesh_hi := Color("c2677a")
	var flesh_lo := Color("4a1420")
	var cx := 24.0 + sway
	var base_y := 44.0
	var h_scale := grow
	# massa principal
	ellipse(img, cx, base_y - 12 * h_scale, 12.0 + pulse, 13.0 * h_scale, flesh)
	ellipse(img, cx - 7, base_y - 9 * h_scale, 6.0, 9.0 * h_scale, flesh)
	ellipse(img, cx + 8, base_y - 15 * h_scale, 5.0 + pulse * 0.5, 7.0 * h_scale, flesh)
	# braço grande e braço curto (assimetria)
	rect(img, int(cx) - 17, int(base_y - 24 * h_scale), 5, int(20 * h_scale), flesh_lo)
	ellipse(img, cx - 15, base_y - 3 * h_scale, 4.0, 3.0, flesh)
	rect(img, int(cx) + 12, int(base_y - 30 * h_scale), 3, int(9 * h_scale), flesh_lo)
	# cabeça deslocada com cavidades
	if grow > 0.55:
		ellipse(img, cx + 3, base_y - 30 * h_scale, 5.0, 5.0, flesh_hi)
		px(img, int(cx) + 1, int(base_y - 31 * h_scale), Color("120406"))
		px(img, int(cx) + 4, int(base_y - 32 * h_scale), Color("120406"))
		px(img, int(cx) + 3, int(base_y - 29 * h_scale), Color("120406"))
	# boca/dentes no tronco
	var my := int(base_y - 11 * h_scale)
	rect(img, int(cx) - 6, my, 10, 2, Color("120406"))
	for i in range(0, 10, 2):
		px(img, int(cx) - 6 + i, my - 1, Color("e8dcc8"))
	# sombreamento e veias
	var src := img.duplicate() as Image
	for y in 48:
		for x in 48:
			if src.get_pixel(x, y).a > 0.5:
				var up_l: Color = src.get_pixel(maxi(x - 1, 0), maxi(y - 1, 0))
				var dn_r: Color = src.get_pixel(mini(x + 1, 47), mini(y + 1, 47))
				if up_l.a < 0.5:
					img.set_pixel(x, y, flesh_hi)
				elif dn_r.a < 0.5:
					img.set_pixel(x, y, flesh_lo)
				elif rng.randf() < 0.05:
					img.set_pixel(x, y, flesh_lo)
				elif rng.randf() < 0.025:
					img.set_pixel(x, y, flesh_hi)
	for v in 5:
		var vx := rng.randi_range(14, 34)
		var vy := rng.randi_range(int(base_y - 24 * h_scale), 40)
		for k in rng.randi_range(3, 7):
			px(img, vx + k / 2, vy + k, Color("2a0a12"))
	outline(img, Color("160508"))
	return img

static func resident_frames() -> SpriteFrames:
	if _frames_cache.has("resident"):
		return _frames_cache["resident"]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 2.0)
	for f in 2:
		sf.add_frame("idle", tex(resident_image(f, "idle")))
	sf.add_animation("walk")
	sf.set_animation_speed("walk", 5.0)
	for f in 4:
		sf.add_frame("walk", tex(resident_image(f, "walk")))
	sf.add_animation("emerge")
	sf.set_animation_speed("emerge", 3.0)
	sf.set_animation_loop("emerge", false)
	for g in [0.25, 0.5, 0.75, 1.0]:
		sf.add_frame("emerge", tex(resident_image(0, "idle", g)))
	_frames_cache["resident"] = sf
	return sf

# ---------- Luzes ----------

static func light_radial(size: int = 128) -> ImageTexture:
	var key := "lr%d" % size
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var v := clampf(1.0 - d, 0.0, 1.0)
			v = v * v * (3.0 - 2.0 * v)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	var t := tex(img)
	_tex_cache[key] = t
	return t

## Cone de lanterna apontando para +X, com o ápice no centro da textura.
static func light_cone(size: int = 256) -> ImageTexture:
	var key := "lc%d" % size
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	var half := deg_to_rad(34.0)
	for y in size:
		for x in size:
			var v2 := Vector2(x - c, y - c)
			var d := v2.length() / c
			var v := 0.0
			if d < 1.0:
				var ang := absf(v2.angle())
				var a_f := clampf(1.0 - ang / half, 0.0, 1.0)
				a_f = a_f * a_f * (3.0 - 2.0 * a_f)
				var r_f := clampf(1.0 - d, 0.0, 1.0)
				v = a_f * (0.35 + 0.65 * r_f)
				if d < 0.12:
					v = maxf(v, 0.5 * (1.0 - d / 0.12))
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	var t := tex(img)
	_tex_cache[key] = t
	return t

static func vignette() -> ImageTexture:
	if _tex_cache.has("vig"):
		return _tex_cache["vig"]
	var w := 160
	var h := 90
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := (x - w / 2.0) / (w / 2.0)
			var dy := (y - h / 2.0) / (h / 2.0)
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf((d - 0.55) / 0.75, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a * 0.85))
	var t := tex(img)
	_tex_cache["vig"] = t
	return t
