class_name Caretaker
extends CharacterBody2D
## A Cuidadora. Estados: Patrol, Suspicious, Investigate, Search, Chase, Attack, Return.
## Percepção: visão (cone + linha de visão), proximidade e ruído (raio reduzido atrás de paredes).
## Regras de esconderijo: ela só abre o esconderijo se VIU Elias entrar.

signal state_changed(state_name: String)

enum S { PATROL, SUSPICIOUS, INVESTIGATE, SEARCH, CHASE, ATTACK, RETURN }
const NAMES := ["PATROL", "SUSPICIOUS", "INVESTIGATE", "SEARCH", "CHASE", "ATTACK", "RETURN"]

const VISION_RANGE := 120.0
const FOV_DEG := 110.0
const CLOSE_SENSE := 24.0
const CAPTURE_DIST := 15.0

var room: Room
var player: Player
var state: int = S.PATROL
var patrol: Array[Vector2] = []
var patrol_i: int = 0
var path: PackedVector2Array = PackedVector2Array()
var path_i: int = 0
var facing: Vector2 = Vector2.DOWN
var awareness: float = 0.0
var last_known: Vector2 = Vector2.ZERO
var timer: float = 0.0
var lost_timer: float = 0.0
var search_points: Array[Vector2] = []
var search_i: int = 0
var saw_hide: bool = false
var enabled: bool = true
var patrol_speed: float = 42.0
var investigate_speed: float = 62.0
var chase_speed: float = 98.0
var sprite: AnimatedSprite2D
var icon: Label
var glow: PointLight2D
var _repath: float = 0.0
var _step_acc: float = 0.0
var _sound_t: float = 4.0
var _prev_hidden: bool = false
var _wait: float = 0.0
var _rng := RandomNumberGenerator.new()
var _captured_sent: bool = false

func setup(p_room: Room, p_player: Player, cfg: Dictionary) -> void:
	room = p_room
	player = p_player
	_rng.randomize()
	var t: Array = cfg.get("tile", [5, 5])
	position = room.nav.center_of(Vector2i(t[0], t[1]))
	for p in cfg.get("patrol", []):
		patrol.append(room.nav.center_of(Vector2i(p[0], p[1])))
	patrol_speed = float(cfg.get("patrol_speed", patrol_speed))
	chase_speed = float(cfg.get("chase_speed", chase_speed))
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = PixelArt.character_frames("caretaker")
	sprite.offset = Vector2(0, -15)
	add_child(sprite)
	sprite.play("idle_down")
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(8, 6)
	cs.shape = rs
	cs.position = Vector2(0, -3)
	add_child(cs)
	icon = Label.new()
	icon.position = Vector2(-8, -48)
	icon.size = Vector2(16, 14)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 12)
	icon.add_theme_color_override("font_outline_color", Color.BLACK)
	icon.add_theme_constant_override("outline_size", 4)
	add_child(icon)
	glow = PointLight2D.new()
	glow.texture = PixelArt.light_radial(128)
	glow.texture_scale = 0.5
	glow.energy = 0.32
	glow.color = Color("c8d0c0")
	glow.position = Vector2(0, -14)
	add_child(glow)
	GameManager.noise_emitted.connect(_on_noise)
	if patrol.is_empty():
		patrol.append(position)
	_enter(S.PATROL)

func _exit_tree() -> void:
	if GameManager.noise_emitted.is_connected(_on_noise):
		GameManager.noise_emitted.disconnect(_on_noise)
	GameManager.set_chasing("caretaker", false)

# ---------- Máquina de estados ----------

func _enter(s: int) -> void:
	var prev := state
	state = s
	timer = 0.0
	_wait = 0.0
	match s:
		S.PATROL:
			icon.text = ""
			if prev != S.PATROL:
				_next_patrol_target(true)
			else:
				_set_path_to(patrol[patrol_i])
		S.SUSPICIOUS:
			icon.text = "?"
			icon.modulate = Color("f4e8a0")
			AudioManager.play_at("breath", position, -10.0, "[Respiração rouca]")
		S.INVESTIGATE:
			icon.text = "?"
			icon.modulate = Color("f4c070")
			_set_path_to(last_known)
		S.SEARCH:
			icon.text = "…"
			icon.modulate = Color("e0e0e0")
			_build_search_points()
		S.CHASE:
			icon.text = "!"
			icon.modulate = Color("ff6060")
			lost_timer = 0.0
			awareness = 1.0
			GameManager.set_chasing("caretaker", true)
			AudioManager.play_at("screech", position, -2.0, "[A Cuidadora grita]")
			glow.color = Color("ff7070")
			glow.energy = 0.5
		S.ATTACK:
			icon.text = "!"
		S.RETURN:
			icon.text = ""
			var best := 0
			var bd := INF
			for i in patrol.size():
				var d := position.distance_to(patrol[i])
				if d < bd:
					bd = d
					best = i
			patrol_i = best
			_set_path_to(patrol[patrol_i])
	if s != S.CHASE and s != S.ATTACK:
		GameManager.set_chasing("caretaker", false)
		glow.color = Color("c8d0c0")
		glow.energy = 0.32
	state_changed.emit(NAMES[s])

func state_name() -> String:
	return NAMES[state]

func _physics_process(delta: float) -> void:
	if not enabled or room == null or player == null:
		return
	timer += delta
	_perceive(delta)
	match state:
		S.PATROL: _do_patrol(delta)
		S.SUSPICIOUS: _do_suspicious(delta)
		S.INVESTIGATE: _do_investigate(delta)
		S.SEARCH: _do_search(delta)
		S.CHASE: _do_chase(delta)
		S.ATTACK: velocity = Vector2.ZERO
		S.RETURN: _do_return(delta)
	_animate(delta)
	_ambient_sounds(delta)
	queue_redraw()
	_prev_hidden = player.hiding

func _draw() -> void:
	if awareness > 0.02 and state != S.CHASE and state != S.ATTACK:
		draw_rect(Rect2(-7, -52, 14, 3), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(-6, -51, 12.0 * clampf(awareness, 0.0, 1.0), 1), Color("f4e8a0"))

# ---------- Percepção ----------

func eye_pos() -> Vector2:
	return position + Vector2(0, -12)

func vision_range() -> float:
	return VISION_RANGE * (1.4 if GameManager.flashlight_on else 1.0)

func can_see_player() -> bool:
	if player.hiding or player.captured:
		return false
	var to := player.position - position
	var d := to.length()
	if d > vision_range():
		return false
	if d > CLOSE_SENSE:
		var ang := absf(rad_to_deg(facing.angle_to(to)))
		if ang > FOV_DEG * 0.5:
			return false
	return room.nav.has_los(position, player.position)

func _perceive(delta: float) -> void:
	# borda de descida: Elias acabou de se esconder
	if player.hiding and not _prev_hidden:
		var d := position.distance_to(player.position)
		var had_los := room.nav.has_los(position, player.position)
		saw_hide = (state == S.CHASE or awareness > 0.5) and had_los and d < vision_range() * 1.25
		if state == S.CHASE and not saw_hide:
			last_known = player.position
			_enter(S.SEARCH)
		elif saw_hide:
			last_known = player.position
	if not player.hiding:
		saw_hide = false
	if state == S.ATTACK:
		return
	var seen := can_see_player()
	if seen:
		var d2 := position.distance_to(player.position)
		var closeness := 1.0 - clampf(d2 / vision_range(), 0.0, 1.0)
		awareness += delta * (1.1 + closeness * 3.2)
		last_known = player.position
		if state == S.CHASE:
			lost_timer = 0.0
		elif awareness >= 1.0:
			_enter(S.CHASE)
		elif awareness >= 0.35 and (state == S.PATROL or state == S.RETURN or state == S.SEARCH):
			_enter(S.SUSPICIOUS)
	else:
		awareness = maxf(0.0, awareness - delta * 0.5)

func _on_noise(pos: Vector2, radius: float, source: String) -> void:
	if not enabled or room == null or state == S.CHASE or state == S.ATTACK:
		return
	if source == "clara" or radius <= 0.0:
		return
	var d := position.distance_to(pos)
	var eff := radius if room.nav.has_los(position, pos) else radius * 0.6
	if d > eff:
		return
	last_known = pos + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-14, 14))
	if not room.nav.is_free_point(last_known):
		last_known = pos
	match state:
		S.PATROL, S.RETURN:
			facing = (pos - position).normalized()
			_enter(S.SUSPICIOUS)
		S.SEARCH, S.INVESTIGATE, S.SUSPICIOUS:
			if radius >= Player.NOISE_RUN * 0.9 or state == S.SEARCH:
				_enter(S.INVESTIGATE)

# ---------- Comportamentos ----------

func _set_path_to(p: Vector2) -> void:
	path = room.nav.find_path(position, p)
	path_i = 0 if path.size() < 2 else 1

func _move_along(speed: float, delta: float) -> bool:
	if path_i >= path.size():
		velocity = Vector2.ZERO
		return true
	var to := path[path_i] - position
	if to.length() < 3.0:
		path_i += 1
		return path_i >= path.size()
	var dirv := to.normalized()
	facing = facing.lerp(dirv, clampf(delta * 9.0, 0.0, 1.0))
	if facing.length() < 0.1:
		facing = dirv
	facing = facing.normalized()
	velocity = dirv * speed
	move_and_slide()
	return false

func _next_patrol_target(nearest: bool = false) -> void:
	if patrol.size() > 1 and not nearest:
		patrol_i = (patrol_i + 1) % patrol.size()
	_set_path_to(patrol[patrol_i])

func _do_patrol(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		velocity = Vector2.ZERO
		facing = facing.rotated(sin(timer * 1.3) * delta * 0.8)
		if _wait <= 0.0:
			_next_patrol_target()
		return
	if _move_along(patrol_speed, delta):
		_wait = 1.6

func _do_suspicious(delta: float) -> void:
	velocity = Vector2.ZERO
	var to := last_known - position
	if to.length() > 2.0:
		facing = facing.lerp(to.normalized(), clampf(delta * 6.0, 0.0, 1.0)).normalized()
	if timer >= 1.1:
		_enter(S.INVESTIGATE)

func _do_investigate(delta: float) -> void:
	if _move_along(investigate_speed, delta) or timer > 12.0:
		_enter(S.SEARCH)

func _build_search_points() -> void:
	search_points.clear()
	search_i = 0
	search_points.append(last_known)
	for i in 2:
		var c := room.nav.cell_of(last_known) + Vector2i(_rng.randi_range(-3, 3), _rng.randi_range(-3, 3))
		c = room.nav.nearest_free_cell(c)
		search_points.append(room.nav.center_of(c))
	_set_path_to(search_points[0])

func _do_search(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		velocity = Vector2.ZERO
		facing = facing.rotated(delta * 2.2)
		if _wait <= 0.0:
			search_i += 1
			if search_i >= search_points.size():
				_enter(S.RETURN)
			else:
				_set_path_to(search_points[search_i])
		return
	if _move_along(investigate_speed * 0.8, delta):
		_wait = 1.4

func _do_chase(delta: float) -> void:
	var target := player.position
	if player.hiding:
		if saw_hide:
			target = player.hide_spot.exit_position() if player.hide_spot != null else player.position
		else:
			last_known = player.position
			_enter(S.SEARCH)
			return
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.3
		_set_path_to(target)
	_move_along(chase_speed, delta)
	var d := position.distance_to(player.position)
	if not can_see_player() and not (player.hiding and saw_hide):
		lost_timer += delta
		if lost_timer >= 3.5 or (lost_timer >= 2.0 and d > 240.0):
			_enter(S.SEARCH)
			return
	var at_spot: bool = player.hiding and saw_hide and player.hide_spot != null and player.hide_spot.rect.grow(14.0).has_point(position)
	if (at_spot or (d < CAPTURE_DIST and not player.hiding)) and not player.captured:
		_enter(S.ATTACK)
		if not _captured_sent:
			_captured_sent = true
			GameManager.capture("caretaker")

func _do_return(delta: float) -> void:
	if _move_along(patrol_speed, delta):
		_enter(S.PATROL)

# ---------- Apresentação ----------

func _animate(delta: float) -> void:
	var moving := velocity.length() > 5.0
	var dn := "down"
	if absf(facing.x) > absf(facing.y):
		dn = "right" if facing.x > 0 else "left"
	else:
		dn = "down" if facing.y > 0 else "up"
	var a := "walk_" if moving else "idle_"
	var n := a + dn
	if sprite.animation != n:
		sprite.play(n)
	sprite.speed_scale = 1.7 if state == S.CHASE else 1.0
	if moving:
		_step_acc += velocity.length() * delta
		if _step_acc > 30.0:
			_step_acc = 0.0
			AudioManager.play_at("step_run" if state == S.CHASE else "step_walk", position, -10.0)

func _ambient_sounds(delta: float) -> void:
	_sound_t -= delta
	if _sound_t > 0.0:
		return
	match state:
		S.PATROL, S.RETURN:
			AudioManager.play_at("hum", position, -4.0, "[Cantiga distorcida]")
			_sound_t = _rng.randf_range(8.0, 12.0)
		S.SEARCH, S.INVESTIGATE:
			AudioManager.play_at("breath", position, -8.0, "[Respiração pesada]")
			_sound_t = 3.0
		S.CHASE:
			AudioManager.play_at("drag", position, -6.0)
			_sound_t = 1.2
		_:
			_sound_t = 2.0
