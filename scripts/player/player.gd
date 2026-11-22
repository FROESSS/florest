class_name Player
extends CharacterBody2D
## Elias: movimento em 8 direções, lanterna, ruído, esconderijo e animações.

const NOISE_WALK := 55.0
const NOISE_RUN := 150.0

var facing: Vector2 = Vector2.DOWN
var dir_name: String = "down"
var hiding: bool = false
var hide_spot: Interactable = null
var controllable: bool = true
var running: bool = false
var captured: bool = false
var sprite: AnimatedSprite2D
var flash: PointLight2D
var glow: PointLight2D
var col: CollisionShape2D
var _step_acc: float = 0.0
var _action_anim: float = 0.0

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
	add_child(flash)
	GameManager.flashlight_changed.connect(func(on: bool) -> void: flash.enabled = on and not hiding)

func _physics_process(delta: float) -> void:
	if captured:
		return
	_action_anim = maxf(0.0, _action_anim - delta)
	var input := Vector2.ZERO
	if controllable and not hiding and not get_tree().paused and not GameManager.input_locked:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if Input.is_action_just_pressed("flashlight"):
			GameManager.set_flashlight(not GameManager.flashlight_on)
	running = input != Vector2.ZERO and Input.is_action_pressed("run")
	var spd := SettingsManager.run_speed if running else SettingsManager.walk_speed
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
		if _action_anim > 0.0:
			a = "interact"
		elif input != Vector2.ZERO:
			a = "run" if running else "walk"
		var anim_name := "%s_%s" % [a, dir_name]
		if sprite.animation != anim_name:
			sprite.play(anim_name)
	if flash.enabled:
		flash.rotation = lerp_angle(flash.rotation, facing.angle(), clampf(delta * 14.0, 0.0, 1.0))
	if not hiding and not GameManager.is_chased() and velocity.length() < 1.0:
		GameManager.last_safe_pos = position

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
