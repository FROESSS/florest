class_name Player
extends CharacterBody2D
## Elias: movimento em 8 direções, lanterna, ruído, esconderijo, estamina, ferimentos e cura.

signal wounded(level: int)
signal healed(level: int)

const NOISE_WALK := 55.0
const NOISE_RUN := 150.0
const STAMINA_MAX := 100.0
const STAMINA_DRAIN := 18.0          # por segundo correndo (≈5,5 s de corrida contínua)
const STAMINA_REGEN_IDLE := 26.0
const STAMINA_REGEN_MOVE := 14.0
const EXHAUST_RECOVER := 25.0        # após esgotar, só volta a correr com este valor
const WOUND_NAMES := ["saudável", "leve", "médio", "grave"]
const NATURAL_HEAL_SECONDS := 110.0  # um nível de ferimento melhora sozinho se Elias ficar em segurança

var facing: Vector2 = Vector2.DOWN
var dir_name: String = "down"
var hiding: bool = false
var hide_spot: Interactable = null
var controllable: bool = true
var running: bool = false
var captured: bool = false
var stamina: float = STAMINA_MAX
var exhausted: bool = false
var wound: int = 0
var heal_t: float = 0.0
var stun_t: float = 0.0
var sprite: AnimatedSprite2D
var flash: PointLight2D
var dust: CPUParticles2D
var glow: PointLight2D
var col: CollisionShape2D
var _step_acc: float = 0.0
var _action_anim: float = 0.0
var _regen_delay: float = 0.0
var _breath_t: float = 2.0
var _wound_t: float = 0.0
var _heal_item: String = ""
var _bob: float = 0.0
var _save_t: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = PixelArt.character_frames("elias")
	sprite.offset = Vector2(0, -15)
	add_child(sprite)
	sprite.play("idle_down")
	col = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(8, 5)
	col.shape = rs
	col.position = Vector2(0, -2)
	add_child(col)
	glow = PointLight2D.new()
	glow.texture = PixelArt.light_radial(128)
	glow.texture_scale = 0.55
	glow.energy = 0.55
	glow.color = Color("b8c0d8")
	add_child(glow)
	flash = PointLight2D.new()
	flash.texture = PixelArt.light_cone(256)
	flash.texture_scale = 1.25
	flash.energy = 1.15
	flash.color = Color("fff1c8")
	flash.enabled = GameManager.flashlight_on
	flash.position = Vector2(0, -10)
	flash.shadow_enabled = true
	flash.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	flash.shadow_filter_smooth = 2.0
	add_child(flash)
	dust = CPUParticles2D.new()
	dust.amount = 16
	dust.lifetime = 2.6
	dust.preprocess = 2.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(48, 20)
	dust.position = Vector2(64, 0)
	dust.direction = Vector2(0, -1)
	dust.spread = 180.0
	dust.gravity = Vector2(0, -1)
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 5.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 1.0
	dust.color = Color(1.0, 0.95, 0.8, 0.55)
	dust.emitting = false
	flash.add_child(dust)
	GameManager.flashlight_changed.connect(func(on: bool) -> void: flash.enabled = on and not hiding)
	stamina = clampf(float(GameManager.player_state.get("stamina", STAMINA_MAX)), 0.0, STAMINA_MAX)
	wound = clampi(int(GameManager.player_state.get("wound", 0)), 0, 3)
	exhausted = bool(GameManager.player_state.get("exhausted", false)) and stamina < EXHAUST_RECOVER

func _exit_tree() -> void:
	_store()

func _store() -> void:
	GameManager.player_state["stamina"] = snappedf(stamina, 0.1)
	GameManager.player_state["wound"] = wound
	GameManager.player_state["exhausted"] = exhausted

func wound_name() -> String:
	return WOUND_NAMES[wound]

func can_run() -> bool:
	return not exhausted and wound < 3 and stamina > 0.0 and heal_t <= 0.0

func speed_mult() -> float:
	var m := 1.0
	if exhausted:
		m *= 0.9
	match wound:
		2: m *= 0.9
		3: m *= 0.8
	return m

func _physics_process(delta: float) -> void:
	if captured:
		return
	_action_anim = maxf(0.0, _action_anim - delta)
	stun_t = maxf(0.0, stun_t - delta)
	var input := Vector2.ZERO
	var free := controllable and not hiding and not get_tree().paused and not GameManager.input_locked and stun_t <= 0.0 and heal_t <= 0.0
	if free:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if Input.is_action_just_pressed("flashlight"):
			GameManager.set_flashlight(not GameManager.flashlight_on)
	_update_heal(delta)
	var want_run := input != Vector2.ZERO and Input.is_action_pressed("run")
	running = want_run and can_run()
	_update_stamina(delta, input != Vector2.ZERO)
	var base := SettingsManager.run_speed if running else SettingsManager.walk_speed
	var spd := base * speed_mult()
	velocity = input * spd
	move_and_slide()
	if input != Vector2.ZERO:
		facing = input.normalized()
		if absf(input.x) > absf(input.y) + 0.01:
			dir_name = "right" if input.x > 0 else "left"
		elif absf(input.y) > absf(input.x) + 0.01:
			dir_name = "down" if input.y > 0 else "up"
		_step_acc += spd * delta
		var stride := 26.0 if not running else 34.0
		if _step_acc >= stride:
			_step_acc = 0.0
			_do_step()
	if not hiding:
		var a := "idle"
		if heal_t > 0.0:
			a = "hide"
		elif stun_t > 0.0:
			a = "hit"
		elif _action_anim > 0.0:
			a = "interact"
		elif input != Vector2.ZERO:
			a = "run" if running else "walk"
		var anim_name := "%s_%s" % [a, dir_name]
		if a == "hit":
			anim_name = "hit_%s" % dir_name
		if sprite.animation != anim_name:
			sprite.play(anim_name)
		_fatigue_visuals(delta, input == Vector2.ZERO)
	if flash.enabled:
		flash.rotation = lerp_angle(flash.rotation, facing.angle(), clampf(delta * 14.0, 0.0, 1.0))
	dust.emitting = flash.enabled and not SettingsManager.reduce_distortion
	if not hiding and not GameManager.is_chased() and velocity.length() < 1.0 and stun_t <= 0.0:
		GameManager.last_safe_pos = position
	_save_t += delta
	if _save_t > 1.0:
		_save_t = 0.0
		_store()

# ---------- Estamina ----------

func _update_stamina(delta: float, moving: bool) -> void:
	if running:
		var k := 1.3 if wound >= 2 else 1.0
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * k * delta)
		_regen_delay = 1.6 if GameManager.is_chased() else 0.7
		if stamina <= 0.0 and not exhausted:
			exhausted = true
			AudioManager.play_sfx("gasp", -4.0, "[Elias está sem fôlego]")
	else:
		_regen_delay = maxf(0.0, _regen_delay - delta)
		if _regen_delay <= 0.0:
			var rate := STAMINA_REGEN_MOVE if moving else STAMINA_REGEN_IDLE
			if GameManager.is_chased():
				rate *= 0.5
			if wound == 1:
				rate *= 0.85
			elif wound >= 2:
				rate *= 0.6
			stamina = minf(STAMINA_MAX, stamina + rate * delta)
	if exhausted and stamina >= EXHAUST_RECOVER:
		exhausted = false
	# respiração: ofegante quando cansado/ferido; faz um ruído baixo audível de perto
	var tired := exhausted or stamina < 30.0 or wound >= 2
	if tired and not hiding:
		_breath_t -= delta
		if _breath_t <= 0.0:
			_breath_t = 2.2 if exhausted else 3.6
			AudioManager.play_sfx("gasp", -12.0, "[Respiração ofegante]")
			GameManager.emit_noise(global_position, 40.0, "breath")

func _fatigue_visuals(delta: float, idle: bool) -> void:
	var tired := exhausted or stamina < 30.0 or wound >= 2
	_bob += delta * (9.0 if tired else 0.0)
	sprite.offset = Vector2(0, -15 + (roundf(sin(_bob)) if tired and idle else 0.0))
	sprite.speed_scale = 1.8 if (tired and idle) else 1.0
	var tint := Color.WHITE
	if wound >= 1:
		tint = Color(1.0, 1.0 - 0.07 * wound, 1.0 - 0.1 * wound)
	sprite.modulate = tint

# ---------- Ferimentos e cura ----------

## Retorna true se o golpe seria fatal (ferimento já era grave).
func hurt(amount: int, source: String = "") -> bool:
	if captured:
		return false
	if wound >= 3:
		return true
	wound = mini(3, wound + amount)
	_wound_t = 0.0
	stun_t = 0.6
	AudioManager.play_sfx("pain", -2.0, "[Elias grita de dor]")
	if GameManager.world != null:
		GameManager.world.shake(2.0, 0.3)
	GameManager.toast.emit("Ferimento: %s" % wound_name())
	wounded.emit(wound)
	_store()
	return false

func start_heal(item_id: String) -> bool:
	if captured or hiding or heal_t > 0.0:
		return false
	if wound <= 0:
		GameManager.toast.emit(LocalizationManager.t("hud.no_wound"))
		return false
	if not InventoryManager.has_item(item_id):
		GameManager.toast.emit(LocalizationManager.t("hud.no_kit"))
		return false
	var use: Dictionary = InventoryManager.item_info(item_id).get("use", {})
	heal_t = float(use.get("time", 2.0))
	_heal_item = item_id
	AudioManager.play_sfx("heal", -3.0)
	return true

func best_kit() -> String:
	if wound >= 2 and InventoryManager.has_item("kit_grande"):
		return "kit_grande"
	if InventoryManager.has_item("kit_pequeno"):
		return "kit_pequeno"
	if InventoryManager.has_item("kit_grande"):
		return "kit_grande"
	return ""

func _update_heal(delta: float) -> void:
	if heal_t > 0.0:
		heal_t -= delta
		if heal_t <= 0.0:
			heal_t = 0.0
			var use: Dictionary = InventoryManager.item_info(_heal_item).get("use", {})
			if InventoryManager.remove_item(_heal_item):
				wound = maxi(0, wound - int(use.get("heal", 1)))
				GameManager.toast.emit("%s — ferimento: %s" % [LocalizationManager.t("hud.healed"), wound_name()])
				healed.emit(wound)
				_store()
			_heal_item = ""
		return
	if wound > 0 and not GameManager.is_chased():
		_wound_t += delta
		if _wound_t >= NATURAL_HEAL_SECONDS:
			_wound_t = 0.0
			wound -= 1
			healed.emit(wound)
			_store()
	elif GameManager.is_chased():
		_wound_t = 0.0

func recover_after_death() -> void:
	wound = mini(wound, 1)
	stamina = STAMINA_MAX
	exhausted = false
	_store()

# ---------- Ruído, interação, esconderijo ----------

func _do_step() -> void:
	AudioManager.play_sfx("step_run" if running else "step_walk", -14.0 if running else -18.0)
	GameManager.emit_noise(global_position, NOISE_RUN if running else NOISE_WALK, "step")

func play_interact() -> void:
	_action_anim = 0.35

func enter_hide(spot: Interactable) -> void:
	hiding = true
	hide_spot = spot
	position = spot.hide_position()
	velocity = Vector2.ZERO
	sprite.visible = false
	flash.enabled = false
	glow.enabled = false
	col.set_deferred("disabled", true)
	AudioManager.play_sfx("hide", -6.0)

func exit_hide() -> void:
	if hide_spot != null:
		position = hide_spot.exit_position()
	hiding = false
	hide_spot = null
	sprite.visible = true
	glow.enabled = true
	flash.enabled = GameManager.flashlight_on
	col.set_deferred("disabled", false)
	AudioManager.play_sfx("hide", -8.0)

func play_captured() -> void:
	captured = true
	velocity = Vector2.ZERO
	sprite.visible = true
	sprite.play("hit_" + dir_name)
	flash.enabled = false

func interaction_probe() -> Vector2:
	return position + facing * 6.0 + Vector2(0, -4)
