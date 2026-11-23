class_name Resident
extends CharacterBody2D
## O Morador. Modo "hunter": domina uma zona contaminada, anuncia-se por sons/vibração/visual (aviso de 3 s)
## e emerge SEMPRE de aberturas (planejadas ou buracos que ele mesmo cavou), a ≥130 px de Elias.
## Cada vez que é enfraquecido/obrigado a fugir (luz sustentada, golpe que feriu Elias, saída da zona, tempo),
## ele recua para uma abertura — e, de tempos em tempos, CAVA um novo buraco que permanece no cenário.
## Modo "blocker": bloqueia um corredor até ser atraído por um ruído planejado ("lure").

signal state_changed(state_name: String)
signal retreated(reason: String, dug: bool)

enum S { DORMANT, WARNING, EMERGE, STALK, RETREAT, BLOCK, LURED, GONE, DIGGING }
const NAMES := ["DORMANT", "WARNING", "EMERGE", "STALK", "RETREAT", "BLOCK", "LURED", "GONE", "DIGGING"]

const MIN_SPAWN_DIST := 130.0
const WARNING_TIME := 3.0
const EMERGE_TIME := 1.2
const STALK_MAX := 16.0
const CAPTURE_DIST := 15.0
const LIGHT_WEAKEN_TIME := 3.0       # luz sustentada na criatura a faz desistir
const DIG_TIME := 1.4
const MIN_COOLDOWN := 18.0           # intervalo mínimo antes de poder voltar após uma fuga

var room: Room
var player: Player
var cfg: Dictionary = {}
var mode: String = "hunter"
var state: int = S.DORMANT
var zone: Rect2 = Rect2()
var planned_vents: Array[Vector2] = []
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
var light_time: float = 0.0
var active_vent: Vector2 = Vector2.ZERO
var next_vent: Vector2 = Vector2.ZERO
var has_next_vent: bool = false
var retreat_reason: String = ""
var speed: float = 58.0
var enabled: bool = true
var done_flag: String = ""
var retreats: int = 0
var dig_tile: Vector2i = Vector2i(-1, -1)
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
			planned_vents.append(vp)
			var vs := Sprite2D.new()
			vs.texture = TileArt.prop("vent", 16, 16)
			vs.position = vp
			vs.z_index = -1
			room.add_child(vs)
			vent_nodes.append(vs)
		var rs_state: Dictionary = GameManager.world_state.get("resident", {}).get(room.id, {})
		retreats = int(rs_state.get("retreats", 0))
		threshold = _delay()
		_enter(S.DORMANT)

func _exit_tree() -> void:
	if GameManager.noise_emitted.is_connected(_on_noise):
		GameManager.noise_emitted.disconnect(_on_noise)
	GameManager.set_chasing("resident", false)
	for v in vent_nodes:
		if is_instance_valid(v):
			v.queue_free()

# ---------- Aberturas ----------

func all_vents() -> Array[Vector2]:
	var out: Array[Vector2] = planned_vents.duplicate()
	for h in room.hole_positions():
		out.append(h)
	return out

func hole_count() -> int:
	return room.holes.size()

func _delay() -> float:
	var dr: Array = cfg.get("delay", [14.0, 22.0])
	var base := _rng.randf_range(float(dr[0]), float(dr[1]))
	# quanto mais buracos, mais imprevisível/perigoso: o intervalo encurta (até 55%)
	return base * maxf(0.55, 1.0 - 0.07 * hole_count())

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
			AudioManager.play_at("rumble", active_vent, -2.0, "[Vibração no chão]")
		S.EMERGE:
			position = active_vent
			visible = true
			sprite.play("emerge")
			AudioManager.play_at("growl", position, -4.0, "[O Morador urra]")
		S.STALK:
			sprite.play("walk")
			light_time = 0.0
			GameManager.set_chasing("resident", true)
		S.RETREAT:
			GameManager.set_chasing("resident", false)
			path = PackedVector2Array()
		S.DIGGING:
			GameManager.set_chasing("resident", false)
			velocity = Vector2.ZERO
			AudioManager.play_at("hole", position, -2.0, "[O Morador cava o chão]")
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
		S.DIGGING: _do_digging(delta)
		S.BLOCK: _do_block(delta)
		S.LURED: _do_lured(delta)
	_pulse_vents()

func _node_at(pos: Vector2) -> Node2D:
	for i in vent_nodes.size():
		if planned_vents[i].distance_to(pos) < 4.0:
			return vent_nodes[i]
	for h in room.holes:
		if room.nav.center_of(h["tile"]).distance_to(pos) < 4.0:
			return h["node"]
	return null

func _pulse_vents() -> void:
	for n in vent_nodes:
		n.scale = Vector2.ONE
	for h in room.holes:
		h["node"].scale = Vector2.ONE
	var target := Vector2.ZERO
	var on := false
	if state == S.WARNING:
		target = active_vent
		on = true
	elif state == S.DORMANT and has_next_vent:
		target = next_vent     # sinal de atividade: a abertura escolhida pulsa e range antes de ele sair
		on = true
	if on:
		var n := _node_at(target)
		if n != null:
			var k := 0.25 if state == S.WARNING else 0.12
			var s := 1.0 + k * sin(timer * (10.0 if state == S.WARNING else 5.0))
			n.scale = Vector2(s, s)

func in_zone() -> bool:
	return zone.has_point(player.position)

# ---------- Hunter ----------

func _do_dormant(delta: float) -> void:
	if not in_zone() or player.hiding:
		dormant_timer = maxf(0.0, dormant_timer - delta * 0.5)
		if dormant_timer < threshold - 6.0:
			has_next_vent = false
		return
	dormant_timer += delta
	if dormant_timer > threshold - 6.0:
		if not has_next_vent:
			var v := _pick_vent()
			if v.x >= 0.0:
				next_vent = v
				has_next_vent = true
		_sound_t -= delta
		if _sound_t <= 0.0 and has_next_vent:
			_sound_t = 2.2
			AudioManager.play_at("drag", next_vent, -6.0, "[Algo se arrasta sob o chão]")
			if GameManager.world != null:
				GameManager.world.shake(1.5, 0.25)
	if dormant_timer >= threshold:
		var v2 := next_vent if has_next_vent else _pick_vent()
		# revalida: o jogador pode ter se aproximado da abertura escolhida
		if v2.x < 0.0 or v2.distance_to(player.position) < MIN_SPAWN_DIST or not room.nav.reachable(v2, player.position):
			v2 = _pick_vent()
		if v2.x >= 0.0:
			active_vent = v2
			has_next_vent = false
			dormant_timer = 0.0
			threshold = _delay()
			_enter(S.WARNING)
		else:
			dormant_timer = threshold - 3.0

## Retorna (-1,-1) se não houver abertura justa agora.
func _pick_vent() -> Vector2:
	var cands: Array[Vector2] = []
	for v in all_vents():
		if v.distance_to(player.position) >= MIN_SPAWN_DIST and room.nav.reachable(v, player.position):
			cands.append(v)
	if cands.is_empty():
		return Vector2(-1, -1)
	return cands[_rng.randi() % cands.size()]

func _do_warning(delta: float) -> void:
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
			begin_retreat("escondido")
			return
	else:
		hidden_timer = 0.0
	if in_zone():
		out_of_zone = 0.0
	else:
		out_of_zone += delta
	if timer >= STALK_MAX:
		begin_retreat("tempo")
		return
	if out_of_zone >= 3.0:
		begin_retreat("zona")
		return
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.35
		path = room.nav.find_path(position, player.position)
		path_i = 0 if path.size() < 2 else 1
	var spd := speed
	if is_lit():
		spd *= 0.4
		light_time += delta
		_sound_t -= delta
		if _sound_t <= 0.0:
			_sound_t = 2.0
			AudioManager.play_at("growl", position, -8.0, "[O Morador recua da luz]")
		if light_time >= LIGHT_WEAKEN_TIME:
			begin_retreat("luz")        # enfraquecido pela luz sustentada
			return
	else:
		light_time = maxf(0.0, light_time - delta * 0.5)
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
			begin_retreat("golpe")   # satisfeito/enfraquecido: interrompe a perseguição

func _follow(spd: float, _delta: float) -> void:
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

# ---------- Fuga, escavação e buracos ----------

func _res_state() -> Dictionary:
	var rs: Dictionary = GameManager.world_state.get("resident", {})
	var d: Dictionary = rs.get(room.id, {})
	d["retreats"] = retreats
	rs[room.id] = d
	GameManager.world_state["resident"] = rs
	return d

func begin_retreat(reason: String) -> void:
	retreats += 1
	retreat_reason = reason
	_res_state()
	dig_tile = Vector2i(-1, -1)
	# decide cavar: a cada 2ª fuga, ou se não há abertura por perto (< 6 tiles)
	var nearest := INF
	for v in all_vents():
		nearest = minf(nearest, position.distance_to(v))
	var want_dig := retreats % 2 == 0 or nearest > 96.0
	if want_dig:
		var c := room.nav.cell_of(position)
		for r in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			if room.can_add_hole(c + r):
				dig_tile = c + r
				break
	if dig_tile.x >= 0:
		_enter(S.DIGGING)
	else:
		_enter(S.RETREAT)

func _do_digging(_delta: float) -> void:
	velocity = Vector2.ZERO
	if timer >= DIG_TIME:
		var made := room.add_hole(dig_tile)     # o buraco permanece no cenário e no save
		retreated.emit(retreat_reason, made)
		_sink()

func _do_retreat(delta: float) -> void:
	var vs := all_vents()
	if vs.is_empty():
		_sink()
		return
	var best := vs[0]
	var bd := INF
	for v in vs:
		var d := position.distance_to(v)
		if d < bd:
			bd = d
			best = v
	if path.is_empty() or timer < 0.05:
		path = room.nav.find_path(position, best)
		path_i = 0 if path.size() < 2 else 1
	_follow(speed * 1.1, delta)
	if position.distance_to(best) < 8.0 or timer > 8.0:
		retreated.emit(retreat_reason, false)
		_sink()

func _sink() -> void:
	AudioManager.play_at("hole", position, -6.0)
	dormant_timer = -MIN_COOLDOWN
	has_next_vent = false
	threshold = _delay()
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
