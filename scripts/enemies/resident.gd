class_name Resident
extends CharacterBody2D
## O Morador. Modo "hunter": domina uma zona contaminada, anuncia-se por sons/vibração/visual (aviso de 3 s)
## e emerge SEMPRE de aberturas planejadas, a pelo menos 130 px de Elias. Mais lento que a caminhada.
## Modo "blocker": bloqueia um caminho até ser atraído por um ruído planejado ("lure").

signal state_changed(state_name: String)

enum S { DORMANT, WARNING, EMERGE, STALK, RETREAT, BLOCK, LURED, GONE }
const NAMES := ["DORMANT", "WARNING", "EMERGE", "STALK", "RETREAT", "BLOCK", "LURED", "GONE"]

const MIN_SPAWN_DIST := 130.0
const WARNING_TIME := 3.0
const EMERGE_TIME := 1.2
const STALK_MAX := 16.0
const CAPTURE_DIST := 15.0

var room: Room
var player: Player
var cfg: Dictionary = {}
var mode: String = "hunter"
var state: int = S.DORMANT
var zone: Rect2 = Rect2()
var vents: Array[Vector2] = []
var vent_nodes: Array[Sprite2D] = []
var sprite: AnimatedSprite2D
var glow: PointLight2D
var warn_icon: Label
var path: PackedVector2Array = PackedVector2Array()
var path_i: int = 0
var timer: float = 0.0
var dormant_timer: float = 0.0
var threshold: float = 16.0
var out_of_zone: float = 0.0
var hidden_timer: float = 0.0
var active_vent: int = -1
var speed: float = 58.0
var enabled: bool = true
var done_flag: String = ""
var _rng := RandomNumberGenerator.new()
var _repath: float = 0.0
var _sound_t: float = 0.0
var _captured_sent: bool = false
var _hit_cd: float = 0.0
var block_body: StaticBody2D = null

func setup(p_room: Room, p_player: Player, p_cfg: Dictionary) -> void:
	room = p_room
	player = p_player
	cfg = p_cfg
	mode = str(cfg.get("mode", "hunter"))
	_rng.randomize()
	speed = float(cfg.get("speed", speed))
	done_flag = str(cfg.get("done_flag", ""))
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = PixelArt.resident_frames()
	sprite.offset = Vector2(0, -22)
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(10, 8)
	cs.shape = rs
	cs.position = Vector2(0, -4)
	add_child(cs)
	glow = PointLight2D.new()
	glow.texture = PixelArt.light_radial(128)
	glow.texture_scale = 0.6
	glow.energy = 0.45
	glow.color = Color("d05060")
	glow.position = Vector2(0, -16)
	add_child(glow)
	warn_icon = Label.new()
	warn_icon.text = "!"
	warn_icon.add_theme_font_size_override("font_size", 12)
	warn_icon.add_theme_color_override("font_outline_color", Color.BLACK)
	warn_icon.add_theme_constant_override("outline_size", 4)
	warn_icon.modulate = Color("ff6060")
	warn_icon.visible = false
	add_child(warn_icon)
	GameManager.noise_emitted.connect(_on_noise)
	if mode == "blocker":
		var t: Array = cfg.get("tile", [5, 5])
		position = room.nav.center_of(Vector2i(t[0], t[1]))
		if done_flag != "" and NarrativeManager.has_flag(done_flag):
			_enter(S.GONE)
			return
		block_body = StaticBody2D.new()
		block_body.collision_layer = 1
		var bcs := CollisionShape2D.new()
		var brs := RectangleShape2D.new()
		brs.size = Vector2(24, 14)
		bcs.shape = brs
		bcs.position = Vector2(0, -6)
		block_body.add_child(bcs)
		add_child(block_body)
		_enter(S.BLOCK)
	else:
		var z: Array = cfg.get("zone", [0, 0, 1, 1])
		zone = Rect2(z[0] * 16, z[1] * 16, z[2] * 16, z[3] * 16)
		for v in cfg.get("vents", []):
			var vp := room.nav.center_of(Vector2i(v[0], v[1]))
			vents.append(vp)
			var vs := Sprite2D.new()
			vs.texture = TileArt.prop("vent", 16, 16)
			vs.position = vp
			vs.z_index = -1
			room.add_child(vs)
			vent_nodes.append(vs)
		threshold = _delay()
		_enter(S.DORMANT)

func _exit_tree() -> void:
	if GameManager.noise_emitted.is_connected(_on_noise):
		GameManager.noise_emitted.disconnect(_on_noise)
	GameManager.set_chasing("resident", false)
	for v in vent_nodes:
		if is_instance_valid(v):
			v.queue_free()

func _delay() -> float:
	var dr: Array = cfg.get("delay", [14.0, 22.0])
	return _rng.randf_range(float(dr[0]), float(dr[1]))

func state_name() -> String:
	return NAMES[state]

func _enter(s: int) -> void:
	state = s
	timer = 0.0
	warn_icon.visible = false
	match s:
		S.DORMANT, S.GONE:
			visible = false
			if block_body != null and s == S.GONE:
				block_body.collision_layer = 0
			GameManager.set_chasing("resident", false)
		S.WARNING:
			visible = false
			warn_icon.visible = false
			AudioManager.play_at("rumble", vents[active_vent], -2.0, "[Vibração no chão]")
		S.EMERGE:
			position = vents[active_vent]
			visible = true
			sprite.play("emerge")
			AudioManager.play_at("growl", position, -4.0, "[O Morador urra]")
		S.STALK:
			sprite.play("walk")
			GameManager.set_chasing("resident", true)
		S.RETREAT:
			GameManager.set_chasing("resident", false)
		S.BLOCK:
			visible = true
			sprite.play("idle")
		S.LURED:
			sprite.play("walk")
	state_changed.emit(NAMES[s])

func _physics_process(delta: float) -> void:
	if not enabled or room == null or player == null:
		return
	timer += delta
	_hit_cd = maxf(0.0, _hit_cd - delta)
	match state:
		S.DORMANT: _do_dormant(delta)
		S.WARNING: _do_warning(delta)
		S.EMERGE: _do_emerge(delta)
		S.STALK: _do_stalk(delta)
		S.RETREAT: _do_retreat(delta)
		S.BLOCK: _do_block(delta)
		S.LURED: _do_lured(delta)
	_pulse_vents()

func _pulse_vents() -> void:
	for i in vent_nodes.size():
		var v := vent_nodes[i]
		var s := 1.0
		if state == S.WARNING and i == active_vent:
			s = 1.0 + 0.25 * sin(timer * 10.0)
		v.scale = Vector2(s, s)

func in_zone() -> bool:
	return zone.has_point(player.position)

# ---------- Hunter ----------

func _do_dormant(delta: float) -> void:
	if not in_zone() or player.hiding:
		dormant_timer = maxf(0.0, dormant_timer - delta * 0.5)
		return
	dormant_timer += delta
	if dormant_timer > threshold - 6.0:
		_sound_t -= delta
		if _sound_t <= 0.0 and not vents.is_empty():
			_sound_t = 2.2
			AudioManager.play_at("drag", vents[_rng.randi() % vents.size()], -6.0, "[Algo se arrasta sob o chão]")
			if GameManager.world != null:
				GameManager.world.shake(1.5, 0.25)
	if dormant_timer >= threshold:
		var idx := _pick_vent()
		if idx >= 0:
			active_vent = idx
			dormant_timer = 0.0
			threshold = _delay()
			_enter(S.WARNING)
		else:
			dormant_timer = threshold - 3.0

func _pick_vent() -> int:
	var cands: Array[int] = []
	for i in vents.size():
		if vents[i].distance_to(player.position) >= MIN_SPAWN_DIST and room.nav.reachable(vents[i], player.position):
			cands.append(i)
	if cands.is_empty():
		return -1
	return cands[_rng.randi() % cands.size()]

func _do_warning(delta: float) -> void:
	warn_icon.visible = false
	if GameManager.world != null and int(timer * 4.0) != int((timer - delta) * 4.0):
		GameManager.world.shake(1.8, 0.2)
	if timer >= WARNING_TIME:
		_enter(S.EMERGE)

func _do_emerge(_delta: float) -> void:
	velocity = Vector2.ZERO
	if timer >= EMERGE_TIME:
		_enter(S.STALK)

func is_lit() -> bool:
	if not GameManager.flashlight_on or player.hiding:
		return false
	var to := position - player.position
	if to.length() > 150.0:
		return false
	if absf(rad_to_deg(player.facing.angle_to(to))) > 36.0:
		return false
	return room.nav.has_los(player.position, position)

func _do_stalk(delta: float) -> void:
	if player.hiding:
		hidden_timer += delta
		if hidden_timer >= 3.0:
			_enter(S.RETREAT)
			return
	else:
		hidden_timer = 0.0
	if in_zone():
		out_of_zone = 0.0
	else:
		out_of_zone += delta
	if timer >= STALK_MAX or out_of_zone >= 3.0:
		_enter(S.RETREAT)
		return
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.35
		path = room.nav.find_path(position, player.position)
		path_i = 0 if path.size() < 2 else 1
	var spd := speed
	if is_lit():
		spd *= 0.4
		_sound_t -= delta
		if _sound_t <= 0.0:
			_sound_t = 2.0
			AudioManager.play_at("growl", position, -8.0, "[O Morador recua da luz]")
	if not player.hiding:
		_follow(spd, delta)
	else:
		velocity = Vector2.ZERO
	if position.distance_to(player.position) < CAPTURE_DIST and not player.hiding and not player.captured and _hit_cd <= 0.0:
		_hit_cd = 2.5
		var fatal := player.hurt(1, "resident")   # 1º–3º golpes ferem; só o golpe em ferimento grave captura
		if fatal:
			if not _captured_sent:
				_captured_sent = true
				GameManager.capture("resident")
		else:
			_enter(S.RETREAT)   # enfraquecido: interrompe a perseguição e foge para uma abertura

func _follow(spd: float, delta: float) -> void:
	if path_i >= path.size():
		velocity = Vector2.ZERO
		return
	var to := path[path_i] - position
	if to.length() < 3.0:
		path_i += 1
		return
	velocity = to.normalized() * spd
	sprite.flip_h = velocity.x < 0
	move_and_slide()

func _do_retreat(delta: float) -> void:
	if vents.is_empty():
		_enter(S.DORMANT)
		return
	var best := 0
	var bd := INF
	for i in vents.size():
		var d := position.distance_to(vents[i])
		if d < bd:
			bd = d
			best = i
	if path.is_empty() or timer < 0.05:
		path = room.nav.find_path(position, vents[best])
		path_i = 0 if path.size() < 2 else 1
	_follow(speed * 1.1, delta)
	if position.distance_to(vents[best]) < 8.0 or timer > 8.0:
		dormant_timer = -8.0
		_enter(S.DORMANT)

# ---------- Blocker ----------

func _do_block(delta: float) -> void:
	velocity = Vector2.ZERO
	var d := position.distance_to(player.position)
	_sound_t -= delta
	if d < 110.0 and _sound_t <= 0.0:
		_sound_t = 3.0
		AudioManager.play_at("breath", position, -6.0, "[Respiração úmida]")
		if GameManager.world != null:
			GameManager.world.shake(1.0, 0.3)

func _do_lured(delta: float) -> void:
	_follow(speed * 0.8, delta)
	if path_i >= path.size() or timer > 10.0:
		if done_flag != "":
			NarrativeManager.set_flag(done_flag, true)
		AudioManager.play_at("growl", position, -8.0, "[O Morador se afasta]")
		_enter(S.GONE)

func _on_noise(pos: Vector2, radius: float, source: String) -> void:
	if mode != "blocker" or state != S.BLOCK:
		return
	if source != "lure":
		return
	if position.distance_to(pos) > radius + 260.0:
		return
	path = room.nav.find_path(position, pos)
	path_i = 0 if path.size() < 2 else 1
	if block_body != null:
		block_body.collision_layer = 0
	_enter(S.LURED)
