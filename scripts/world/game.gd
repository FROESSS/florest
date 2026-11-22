class_name Game
extends Node2D
## Cena de jogo: carrega salas, jogador, câmera, inimigos, UI, triggers, capturas e finais.

signal room_loaded(room_id: String)

var room: Room = null
var player: Player = null
var camera: Camera2D = null
var hud: HUD
var dialogue: DialogueUI
var puzzle: PuzzleUI
var book: BookUI
var memory: MemoryUI
var pause: PauseUI
var runner: EffectRunner
var target: Interactable = null
var changing_room: bool = false
var spawned_enemies: Dictionary = {}
var _shake_t: float = 0.0
var _shake_amt: float = 0.0
var _capturing: bool = false
var _rng := RandomNumberGenerator.new()

const CLARA_LINES := [
	"Por aqui. Fique perto de mim.",
	"Ela não me procura. Só você.",
	"Nem tudo o que você lembra aconteceu.",
	"Eu conheço esta casa melhor do que ela.",
	"Escute o chão. Ele sempre avisa.",
]

func _ready() -> void:
	_rng.randomize()
	GameManager.world = self
	hud = HUD.new()
	dialogue = DialogueUI.new()
	puzzle = PuzzleUI.new()
	book = BookUI.new()
	memory = MemoryUI.new()
	pause = PauseUI.new()
	for n in [hud, dialogue, puzzle, book, memory, pause]:
		add_child(n)
	runner = EffectRunner.new()
	runner.game = self
	add_child(runner)
	NarrativeManager.flag_changed.connect(_on_flag_changed)
	GameManager.player_captured.connect(_on_captured)
	var spawn := GameManager.last_spawn
	var use_pending := GameManager.has_pending_pos
	await load_room(GameManager.current_room, spawn, use_pending, false)
	if not GameManager.test_mode:
		await SceneManager.fade_in(0.6)
	if not NarrativeManager.has_flag("intro_shown") and GameManager.chapter == 1:
		NarrativeManager.set_flag("intro_shown", true)
		hud.show_hint(LocalizationManager.t("controls.hint"), 12.0)

func _exit_tree() -> void:
	if GameManager.world == self:
		GameManager.world = null
		GameManager.player = null

func current_room_node() -> Node:
	return room

# ---------- Salas ----------

func load_room(room_id: String, spawn: String = "", use_pending: bool = false, fade: bool = true) -> void:
	if not NarrativeManager.rooms_db.has(room_id):
		push_error("Sala inexistente: " + room_id)
		return
	while changing_room:
		await get_tree().process_frame
	changing_room = true
	if fade and room != null:
		await SceneManager.fade_out(0.3)
	if room != null:
		room.queue_free()
		room = null
		player = null
		camera = null
		target = null
	spawned_enemies.clear()
	GameManager.chasers.clear()
	room = Room.new()
	add_child(room)
	room.build(room_id)
	GameManager.current_room = room_id
	GameManager.last_spawn = spawn
	var spec_chapter := int(room.spec.get("chapter", GameManager.chapter))
	if spec_chapter != GameManager.chapter:
		GameManager.set_chapter(spec_chapter)
	player = Player.new()
	room.y_layer.add_child(player)
	GameManager.player = player
	var pos := room.spawn_position(spawn)
	if use_pending or GameManager.has_pending_pos:
		var p := GameManager.pending_pos
		if room.nav.is_free_point(p):
			pos = p
		GameManager.has_pending_pos = false
	player.position = pos
	GameManager.last_safe_pos = pos
	camera = Camera2D.new()
	player.add_child(camera)
	camera.position = Vector2(0, -10)
	_apply_camera_limits()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.make_current()
	camera.reset_smoothing()
	_spawn_enemies()
	spawn_clara()
	AudioManager.set_ambient(str(room.spec.get("ambient_sound", "amb_house")))
	hud.set_hidden(false)
	changing_room = false
	room_loaded.emit(room_id)
	if fade and not GameManager.test_mode:
		await SceneManager.fade_in(0.3)
	if not GameManager.is_chased():
		SaveManager.save_to("auto")

func _apply_camera_limits() -> void:
	var ps := room.pixel_size()
	var vw := 640.0
	var vh := 360.0
	var l := 0.0
	var r := ps.x
	if ps.x < vw:
		l = -(vw - ps.x) / 2.0
		r = ps.x + (vw - ps.x) / 2.0
	var t := 0.0
	var b := ps.y
	if ps.y < vh:
		t = -(vh - ps.y) / 2.0
		b = ps.y + (vh - ps.y) / 2.0
	camera.limit_left = int(l)
	camera.limit_right = int(r)
	camera.limit_top = int(t)
	camera.limit_bottom = int(b)

func goto_chapter(n: int) -> void:
	var ch: Dictionary = NarrativeManager.chapters_db.get(n, {})
	if ch.is_empty():
		return
	await SceneManager.fade_out(0.6)
	GameManager.set_chapter(n)
	NarrativeManager.set_flag("chapter_%d_started" % n, true)
	await memory.play_cutscene("chapter_%d" % n)
	NarrativeManager.set_objective(str(ch.get("objective", "")))
	await load_room(str(ch["start_room"]), str(ch.get("start_spawn", "")), false, false)
	await SceneManager.fade_in(0.6)
	if str(ch.get("objective", "")) != "":
		hud.show_objective()

# ---------- Entidades ----------

func _on_flag_changed(_id: String, _v: Variant) -> void:
	if room == null or changing_room:
		return
	room.refresh_dynamic()
	_spawn_enemies()

func _spawn_enemies() -> void:
	if room == null or player == null:
		return
	for e in room.spec.get("enemies", []):
		var eid := str(e.get("id", e.get("type", "e")))
		if spawned_enemies.has(eid):
			continue
		if not NarrativeManager.check(e.get("active_if", {})):
			continue
		if e.has("inactive_if") and NarrativeManager.check(e["inactive_if"]):
			continue
		spawned_enemies[eid] = true
		match str(e.get("type", "caretaker")):
			"caretaker":
				var c := Caretaker.new()
				room.y_layer.add_child(c)
				c.setup(room, player, e)
				room.enemies.append(c)
				if e.get("start_chase", false):
					c.last_known = player.position
					c._enter(Caretaker.S.CHASE)
			"resident":
				var r := Resident.new()
				room.y_layer.add_child(r)
				r.setup(room, player, e)
				room.enemies.append(r)

func force_chase() -> void:
	for en in room.enemies:
		if en is Caretaker and is_instance_valid(en):
			en.last_known = player.position
			en.awareness = 1.0
			en._enter(Caretaker.S.CHASE)

func spawn_clara() -> void:
	if room == null or player == null:
		return
	if not NarrativeManager.has_flag("clara_follows") or bool(room.spec.get("no_clara", false)):
		return
	if room.find_object("clara_follow") != null:
		return
	var tile := room.nav.cell_of(player.position + Vector2(-16, 0))
	tile = room.nav.nearest_free_cell(tile)
	var it := Interactable.new()
	room.y_layer.add_child(it)
	it.setup(room.id, {
		"id": "clara_follow", "kind": "npc", "style": "clara", "follow": true, "ghost": false,
		"tile": [tile.x, tile.y], "name": "Clara", "prompt": "Falar com",
		"effects": [{"clara_talk": true}],
	})
	room.objects.append(it)

func clara_talk() -> void:
	for entry in room.spec.get("clara_talk", []):
		var fid := "clara_said:%s:%s" % [room.id, str(entry.get("id", ""))]
		if NarrativeManager.has_flag(fid):
			continue
		if not NarrativeManager.check(entry.get("conditions", {})):
			continue
		NarrativeManager.set_flag(fid, true)
		await runner.run(entry.get("effects", []))
		return
	await dialogue.run([{"who": "Clara", "text": CLARA_LINES[_rng.randi() % CLARA_LINES.size()]}])

# ---------- Loop ----------

func _is_interactive(o: Interactable) -> bool:
	var s := o.spec
	return s.has("effects") or s.has("door") or s.get("hide", false)

func _update_target() -> void:
	target = null
	if player.hiding:
		hud.set_prompt("Sair do esconderijo")
		return
	var probe := player.interaction_probe()
	var feet := player.position + Vector2(0, -4)
	var best_d := INF
	for o in room.objects:
		if not o.visible or not _is_interactive(o):
			continue
		var gr := o.rect.grow(8.0)
		if gr.has_point(probe) or gr.has_point(feet):
			var d := probe.distance_to(o.center())
			if d < best_d:
				best_d = d
				target = o
	hud.set_prompt(target.prompt() if target != null else "")

func _physics_process(delta: float) -> void:
	if room == null or player == null or changing_room or _capturing or runner.busy:
		return
	_update_target()
	_check_triggers()
	if _shake_t > 0.0 and camera != null:
		_shake_t -= delta
		camera.offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).round() * _shake_amt
		if _shake_t <= 0.0:
			camera.offset = Vector2.ZERO

func _check_triggers() -> void:
	var cell := room.nav.cell_of(player.position)
	for t in room.spec.get("triggers", []):
		var tid := "trg:%s:%s" % [room.id, str(t.get("id", ""))]
		var once: bool = bool(t.get("once", true))
		if once and NarrativeManager.has_flag(tid):
			continue
		var r: Array = t["rect"]
		if cell.x < r[0] or cell.x >= r[0] + r[2] or cell.y < r[1] or cell.y >= r[1] + r[3]:
			continue
		if not NarrativeManager.check(t.get("conditions", {})):
			continue
		runner.run_trigger(t, tid)
		return

func shake(amount: float, dur: float) -> void:
	if SettingsManager.reduce_shake:
		return
	_shake_amt = amount
	_shake_t = dur

func _unhandled_input(event: InputEvent) -> void:
	if room == null or player == null or changing_room or _capturing or runner.busy:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_open_pause()
	elif event.is_action_pressed("inventory") and not player.hiding:
		get_viewport().set_input_as_handled()
		_open_book(false)
	elif event.is_action_pressed("journal") and not player.hiding:
		get_viewport().set_input_as_handled()
		_open_book(true)
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if player.hiding:
			player.exit_hide()
			hud.set_hidden(false)
		elif target != null:
			runner.interact(target)

func _open_pause() -> void:
	get_tree().paused = true
	pause.open()
	await pause.closed
	get_tree().paused = false

func _open_book(journal: bool) -> void:
	get_tree().paused = true
	if journal:
		book.open_journal(0)
	else:
		book.open_inventory()
	await book.closed
	get_tree().paused = false

# ---------- Captura e finais ----------

func _on_captured(by: String) -> void:
	if _capturing or GameManager.ended != "":
		return
	_capturing = true
	player.play_captured()
	AudioManager.play_sfx("thud")
	AudioManager.play_sfx("screech", -6.0)
	shake(3.0, 0.6)
	if not GameManager.test_mode:
		await get_tree().create_timer(1.0).timeout
	await SceneManager.fade_out(0.5)
	GameManager.set_flashlight(false)
	# Morte NÃO desfaz progresso (itens, documentos, puzzles, flags): só reposiciona Elias
	# no ponto de recuperação válido mais próximo, longe de inimigos, e reinicia os inimigos.
	var extra: Array = []
	for en in room.enemies:
		if is_instance_valid(en):
			extra.append(en.position)
	var rp := Recovery.choose(room, player.position, extra)
	GameManager.pending_pos = rp["pos"]
	GameManager.has_pending_pos = true
	GameManager.deaths += 1
	GameManager.world_state["deaths"] = GameManager.deaths
	await load_room(GameManager.current_room, GameManager.last_spawn, true, false)
	_capturing = false
	await SceneManager.fade_in(0.5)
	GameManager.toast.emit(LocalizationManager.t("game.captured"))

func run_ending(ending_id: String) -> void:
	GameManager.ended = ending_id
	NarrativeManager.set_flag("ending_" + ending_id, true)
	_record_ending(ending_id)
	await SceneManager.fade_out(0.8)
	await memory.play_cutscene("ending_" + ending_id)
	await memory.play_cutscene("ending_credits")
	if not GameManager.test_mode:
		SceneManager.goto_menu()

func _record_ending(ending_id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://meta.cfg")
	cfg.set_value("endings", ending_id, true)
	cfg.save("user://meta.cfg")
