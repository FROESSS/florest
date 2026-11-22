class_name EffectRunner
extends Node
## Executa interações e efeitos orientados a dados (JSON). Pausa o mundo durante a execução.

var game: Game
var busy: bool = false
var current_obj: Interactable = null
var _pause_depth: int = 0

const GENERIC_LOCKED := "Está trancado."

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ---------- Entrada ----------

func interact(obj: Interactable) -> void:
	if busy:
		return
	var spec: Dictionary = obj.spec
	if obj.is_hide_spot() and not game.player.hiding:
		game.player.enter_hide(obj)
		game.hud.set_hidden(true)
		return
	busy = true
	current_obj = obj
	_pause(true)
	game.player.play_interact()
	var req: Dictionary = spec.get("requires", {})
	var effects: Array = _effects_of(spec)
	var once: bool = bool(spec.get("once", _default_once(effects)))
	var done_flag := "done_" + obj.uid
	if not req.is_empty() and not NarrativeManager.check(req):
		AudioManager.play_sfx("door_locked" if spec.has("door") else "error", -4.0)
		await run([{"text": spec.get("locked_text", GENERIC_LOCKED)}])
	elif once and NarrativeManager.has_flag(done_flag):
		var rep = spec.get("repeat_text", "")
		if rep != "":
			await run([{"text": rep}])
	else:
		await run(effects)
		if once:
			NarrativeManager.set_flag(done_flag, true)
	current_obj = null
	_pause(false)
	busy = false
	_autosave()

func run_trigger(trig: Dictionary, flag_id: String) -> void:
	if busy:
		return
	busy = true
	_pause(true)
	NarrativeManager.set_flag(flag_id, true)
	await run(trig.get("effects", []))
	_pause(false)
	busy = false
	_autosave()

func _pause(on: bool) -> void:
	if on:
		_pause_depth += 1
	else:
		_pause_depth = maxi(0, _pause_depth - 1)
	game.get_tree().paused = _pause_depth > 0

func _default_once(effects: Array) -> bool:
	for e in effects:
		if e is Dictionary:
			for k in ["give", "take", "battery", "choice"]:
				if e.has(k):
					return true
	return false

func _effects_of(spec: Dictionary) -> Array:
	var out: Array = []
	if spec.has("door"):
		var d: Dictionary = spec["door"]
		out.append({"sfx": "door_open"})
		out.append({"goto": {"room": d["to"], "spawn": d.get("spawn", "")}})
	out.append_array(spec.get("effects", []))
	return out

# ---------- Execução ----------

func run(effects: Array) -> void:
	for e in effects:
		if e is Dictionary:
			await _run_one(e)

func _run_one(e: Dictionary) -> void:
	if e.has("if"):
		var branch: Array = e.get("then", []) if NarrativeManager.check(e["if"]) else e.get("else", [])
		await run(branch)
		return
	if e.has("text"):
		var t = e["text"]
		var lines: Array = t if t is Array else [t]
		await game.dialogue.run(lines, str(e.get("who", "")))
	if e.has("say"):
		var s: Dictionary = e["say"]
		await game.dialogue.run([{"who": s.get("who", ""), "text": s.get("text", "")}])
	if e.has("flag"):
		NarrativeManager.set_flag(str(e["flag"]), e.get("value", true))
	if e.has("counter"):
		NarrativeManager.add_counter(str(e["counter"]), int(e.get("add", 1)))
	if e.has("give"):
		var id := str(e["give"])
		if InventoryManager.add_item(id):
			AudioManager.play_sfx("pickup", -4.0)
			GameManager.toast.emit(LocalizationManager.tf("hud.item_got", [InventoryManager.item_info(id).get("name", id)]))
	if e.has("take"):
		InventoryManager.remove_item(str(e["take"]))
	if e.has("battery"):
		GameManager.set_battery(GameManager.battery + float(e["battery"]))
		AudioManager.play_sfx("pickup", -4.0)
		GameManager.toast.emit("Bateria recarregada.")
	if e.has("memory"):
		var mid := str(e["memory"])
		if not NarrativeManager.memories_found.has(mid):
			await game.memory.play_memory(mid)
			NarrativeManager.add_memory(mid)
			GameManager.toast.emit(LocalizationManager.tf("hud.memory_got", [NarrativeManager.memories_db.get(mid, {}).get("title", mid)]))
		else:
			await game.memory.play_memory(mid)   # reviver uma lembrança já registrada
	if e.has("doc"):
		var did := str(e["doc"])
		NarrativeManager.add_document(did)
		GameManager.toast.emit(LocalizationManager.tf("hud.doc_got", [NarrativeManager.docs_db.get(did, {}).get("title", did)]))
		AudioManager.play_sfx("pickup", -6.0)
		if not GameManager.test_mode:
			game.book.read_document(did)
			await game.book.closed
		else:
			GameManager.docs_opened += 1
	if e.has("puzzle"):
		await _run_puzzle(e)
	if e.has("inspect"):
		var ins: Dictionary = e["inspect"] if e["inspect"] is Dictionary else {}
		if not GameManager.test_mode and current_obj != null:
			game.book.inspect_object(current_obj, str(ins.get("title", current_obj.spec.get("name", ""))), str(ins.get("text", "")))
			await game.book.closed
		else:
			GameManager.docs_opened += 1
	if e.has("choice"):
		await _run_choice(str(e["choice"]))
	if e.has("goto"):
		var g: Dictionary = e["goto"]
		await game.load_room(str(g["room"]), str(g.get("spawn", "")))
	if e.has("cutscene"):
		await game.memory.play_cutscene(str(e["cutscene"]))
	if e.has("chapter"):
		await game.goto_chapter(int(e["chapter"]))
	if e.has("checkpoint"):
		SaveManager.save_to("auto")
	if e.has("noise"):
		var n: Dictionary = e["noise"]
		var at: Vector2 = game.player.position
		if n.has("tile"):
			at = Vector2(n["tile"][0] * 16 + 8, n["tile"][1] * 16 + 8)
		GameManager.emit_noise(at, float(n.get("radius", 200.0)), str(n.get("source", "object")))
	if e.has("sfx"):
		AudioManager.play_sfx(str(e["sfx"]), float(e.get("db", -2.0)), str(e.get("sub", "")))
	if e.has("force_chase"):
		game.force_chase()
	if e.has("shake"):
		game.shake(float(e["shake"]), 0.5)
	if e.has("wait"):
		if not GameManager.test_mode:
			await get_tree().create_timer(float(e["wait"]), true).timeout
	if e.has("objective"):
		NarrativeManager.set_objective(str(e["objective"]))
		game.hud.show_objective()
	if e.has("hint"):
		game.hud.show_hint(str(e["hint"]), float(e.get("hint_time", 8.0)))
	if e.has("clara_talk"):
		await game.clara_talk()
	if e.has("set_clara"):
		NarrativeManager.set_flag("clara_follows", bool(e["set_clara"]))
		game.spawn_clara()
	if e.has("final_choice"):
		await _run_final_choice()
	if e.has("ending"):
		await game.run_ending(str(e["ending"]))

func _autosave() -> void:
	if GameManager.is_chased() or GameManager.ended != "" or game.changing_room:
		return
	SaveManager.save_to("auto")

## Puzzle com estados: não iniciado → em andamento → resolvido (ou bloqueado).
## Cancelar/errar NUNCA tranca o mecanismo; resolvido executa on_solved uma vez e depois `repeat`.
func _run_puzzle(e: Dictionary) -> void:
	var pid := str(e["puzzle"])
	var st := NarrativeManager.puzzle_state(pid)
	if st == "blocked":
		await run([{"text": e.get("blocked_text", "Não consigo mexer nisso agora.")}])
		return
	if st != "solved":
		NarrativeManager.set_puzzle_state(pid, "in_progress")
		var ok: bool = await game.puzzle.open(pid)
		NarrativeManager.add_attempt(pid)
		if not ok:
			await run(e.get("on_fail", []))
			return
		NarrativeManager.set_puzzle_state(pid, "solved")
	var done_flag := "onsolved_" + pid
	if not NarrativeManager.has_flag(done_flag):
		await run(e.get("on_solved", []))
		NarrativeManager.set_flag(done_flag, true)
	elif e.has("repeat"):
		await run(e["repeat"])
	elif not bool(e.get("silent_repeat", false)):
		await run([{"text": "Já resolvi isso."}])

func _run_choice(cid: String) -> void:
	var def: Dictionary = NarrativeManager.choices_db.get(cid, {})
	if def.is_empty():
		return
	if NarrativeManager.flags.has("choice_" + cid) and not bool(def.get("repeatable", false)):
		return   # escolha única já feita: não reexecuta nem sobrescreve
	var opts: Array = []
	for o in def.get("options", []):
		var req: Dictionary = o.get("requires", {})
		opts.append({"text": o.get("text", ""), "disabled": not req.is_empty() and not NarrativeManager.check(req)})
	var idx := 0
	if GameManager.test_mode:
		idx = int(GameManager.test_choices.get(cid, 0))
	else:
		idx = await game.dialogue.choose(str(def.get("prompt", "")), opts)
	if idx < 0 or idx >= opts.size():
		idx = 0
	var picked: Dictionary = def["options"][idx]
	if not bool(def.get("repeatable", false)) or not picked.get("effects", []).is_empty():
		NarrativeManager.set_flag("choice_" + cid, idx)
	await run(picked.get("effects", []))

func _run_final_choice() -> void:
	var opts: Array = NarrativeManager.final_options()
	if opts.is_empty():
		await game.dialogue.run(["Ainda não sei o que fazer aqui. Preciso encontrar outro caminho..."])
		return
	var idx := 0
	if GameManager.test_mode:
		var want := str(GameManager.test_choices.get("final", ""))
		for i in opts.size():
			if opts[i]["id"] == want:
				idx = i
	else:
		idx = await game.dialogue.choose("O que Elias vai fazer?", opts)
	await game.run_ending(str(opts[idx]["id"]))
