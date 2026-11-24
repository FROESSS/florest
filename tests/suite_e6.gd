extends Node
## Etapa 6: puzzles com pistas distribuídas e dedutíveis, narrativa coerente/gradual, eventos e transições.
var t

func _all_effects(rooms_filter: String = "") -> Array:
	# retorna [{room, effects}] de objetos, triggers e clara_talk
	var out: Array = []
	for rid in NarrativeManager.rooms_db:
		var spec: Dictionary = NarrativeManager.rooms_db[rid]
		for o in spec.get("objects", []):
			out.append({"room": rid, "effects": o.get("effects", []), "obj": o})
		for tr in spec.get("triggers", []):
			out.append({"room": rid, "effects": tr.get("effects", []), "obj": {}})
		for ct in spec.get("clara_talk", []):
			out.append({"room": rid, "effects": ct.get("effects", []), "obj": {}})
	return out

func _walk(effects: Array, cb: Callable) -> void:
	for e in effects:
		if e is Dictionary:
			cb.call(e)
			if e.has("puzzle"):
				_walk(e.get("on_solved", []), cb)
				_walk(e.get("on_fail", []), cb)
			if e.has("if"):
				_walk(e.get("then", []), cb)
				_walk(e.get("else", []), cb)

func _sources() -> Dictionary:
	# id -> sala onde pode ser obtido, por tipo
	var docs := {}
	var mems := {}
	var puzzles := {}
	var sfx: Array = []
	for item in _all_effects():
		_walk(item["effects"], func(e: Dictionary) -> void:
			if e.has("doc"):
				docs[str(e["doc"])] = item["room"]
			if e.has("memory"):
				mems[str(e["memory"])] = item["room"]
			if e.has("puzzle"):
				puzzles[str(e["puzzle"])] = item["room"]
			if e.has("sfx"):
				sfx.append(str(e["sfx"])))
	for cid in NarrativeManager.choices_db:
		for o in NarrativeManager.choices_db[cid]["options"]:
			_walk(o.get("effects", []), func(e: Dictionary) -> void:
				if e.has("puzzle"):
					puzzles[str(e["puzzle"])] = "choice"
				if e.has("memory"):
					mems[str(e["memory"])] = "choice")
	return {"docs": docs, "mems": mems, "puzzles": puzzles, "sfx": sfx}

func run() -> void:
	var src := _sources()
	_test_no_orphans(src)
	_test_clue_distribution(src)
	_test_deductions()
	_test_lore_progression(src)
	await _test_transitions()

func _test_no_orphans(src: Dictionary) -> void:
	for d in NarrativeManager.docs_db:
		t.check(src["docs"].has(d), "documento '%s' pode ser encontrado no jogo" % d)
	for m in NarrativeManager.memories_db:
		t.check(src["mems"].has(m), "memória '%s' pode ser encontrada" % m)
	for p in NarrativeManager.puzzles_db:
		t.check(src["puzzles"].has(p), "puzzle '%s' está ligado a um mecanismo" % p)
	for s in src["sfx"]:
		t.check(s in AudioManager.SOUND_NAMES, "efeito sonoro '%s' existe" % s)
	t.check(NarrativeManager.memories_db.size() == 13, "13 memórias no total (%d)" % NarrativeManager.memories_db.size())

func _clue_text(spec: String) -> String:
	var kind := spec.get_slice(":", 0)
	var id := spec.get_slice(":", 1)
	if kind == "doc":
		return str(NarrativeManager.docs_db.get(id, {}).get("body", ""))
	return "\n".join(PackedStringArray(NarrativeManager.memories_db.get(id, {}).get("lines", [])))

func _test_clue_distribution(src: Dictionary) -> void:
	var by_chapter := {}
	for pid in NarrativeManager.puzzles_db:
		var d: Dictionary = NarrativeManager.puzzles_db[pid]
		var mech_room: String = src["puzzles"].get(pid, "")
		var all_text := ""
		var far := false
		for c in d.get("clues", []):
			var kind := str(c).get_slice(":", 0)
			var id := str(c).get_slice(":", 1)
			var room: String = (src["docs"] if kind == "doc" else src["mems"]).get(id, "")
			t.check(room != "", "%s: pista '%s' existe no jogo" % [pid, c])
			all_text += _clue_text(str(c)) + "\n"
			if room != mech_room:
				far = true
		for info in d.get("info", []):
			t.check(all_text.contains(str(info)), "%s: as pistas contêm '%s'" % [pid, info])
		if bool(d.get("cross_room", false)):
			t.check(far, "%s: ao menos uma pista está em sala diferente do mecanismo (%s)" % [pid, mech_room])
		# o enunciado não entrega a resposta
		var prompt := str(d.get("prompt", ""))
		if d["type"] == "code":
			t.check(not prompt.contains(str(d["solution"])), "%s: enunciado não revela o código" % pid)
		var ch := int(NarrativeManager.rooms_db[mech_room]["chapter"]) if NarrativeManager.rooms_db.has(mech_room) else 1
		by_chapter[ch] = int(by_chapter.get(ch, 0)) + (2 if far else 1)
	# dificuldade progressiva: capítulo I sem pistas distantes; II em diante, todos cross-room
	t.check(not bool(NarrativeManager.puzzles_db["p_caixa_musica"].get("cross_room", true)), "capítulo I: puzzle introdutório com pistas na própria sala")
	for pid in ["p_prontuarios", "p_simbolos", "p_fusiveis", "p_brinquedos", "p_terminal", "p_cofre", "p_valvulas"]:
		t.check(bool(NarrativeManager.puzzles_db[pid].get("cross_room", false)), "%s: pistas distribuídas entre salas" % pid)
	t.check(NarrativeManager.puzzles_db["p_brinquedos"]["clues"].size() >= 2, "brinquedos: exige combinar duas fontes (lembrança + diário)")

func _idx(text: String, word: String) -> int:
	return text.find(word)

func _test_deductions() -> void:
	var P: Dictionary = NarrativeManager.puzzles_db
	var D: Dictionary = NarrativeManager.docs_db
	# fusíveis: ligados = números pares
	var sol: Array = P["p_fusiveis"]["solution"]
	for i in sol.size():
		t.check((int(sol[i]) == 1) == ((i + 1) % 2 == 0), "fusível %d segue a regra 'pares ligados'" % (i + 1))
	# prontuários: ordem por data do livro de matrícula
	var ledger: String = D["ledger_matricula"]["body"]
	var codes := {}
	for it in P["p_prontuarios"]["items"]:
		var lbl := str(it["label"])
		codes[str(it["id"])] = lbl.substr(lbl.find("(L-") + 1, 4)
	var dated: Array = []
	for line in ledger.split("\n"):
		for id in codes:
			if line.contains(codes[id]) and line.length() > 10 and line.substr(2, 1) == "/":
				var parts := line.substr(0, 10).split("/")
				dated.append({"id": id, "key": int(parts[2]) * 10000 + int(parts[1]) * 100 + int(parts[0])})
	dated.sort_custom(func(a, b): return a["key"] < b["key"])
	var order := dated.map(func(x): return x["id"])
	t.check(order == P["p_prontuarios"]["solution"], "prontuários: ordem cronológica do livro = solução %s" % str(order))
	# escadas: 2 (quarto), 7 (grande), 1 (pequena) na ordem do diário de Lia
	var texts := ""
	for rid in ["c2_dormitorio", "c2_aula"]:
		for o in NarrativeManager.rooms_db[rid]["objects"]:
			texts += JSON.stringify(o.get("effects", [])) + "\n"
	t.check(texts.contains("2 degraus") and texts.contains("7 degraus") and texts.contains("1 degrau"), "legendas das escadas existem")
	var diary: String = D["diario_lia"]["body"]
	t.check(_idx(diary, "nosso quarto") < _idx(diary, "grande") and _idx(diary, "grande") < _idx(diary, "pequena"), "diário define a ordem quarto → grande → pequena")
	t.check(P["p_simbolos"]["solution"] == "271", "código das escadas = 2,7,1")
	# brinquedos: ordem consistente entre as duas fontes
	var mem := _clue_text("memory:brinquedos")
	var mar: String = D["diario_marta"]["body"]
	t.check(_idx(mem, "urso") < _idx(mem, "trem"), "lembrança: urso antes do trem")
	t.check(_idx(mar, "urso") < _idx(mar, "trem") and _idx(mar, "trem") < _idx(mar, "boneca") and _idx(mar, "boneca") < _idx(mar, "bola"), "diário de Marta: urso, trem, boneca, bola")
	t.check(P["p_brinquedos"]["solution"] == ["urso", "trem", "boneca", "bola"], "solução dos brinquedos coerente com as pistas")
	# datas DDMM
	t.check(D["memorando_encerramento"]["body"].contains("07/12") and P["p_terminal"]["solution"] == "0712", "terminal: 07/12 → 0712")
	t.check(D["carta_inauguracao"]["body"].contains("14 de março") and P["p_cofre"]["solution"] == "1403", "cofre: 14 de março → 1403")
	t.check(D["nota_valvulas"]["body"].contains("3, 1, 2") and P["p_valvulas"]["solution"] == ["v3", "v1", "v2"], "válvulas: 3, 1, 2")

func _test_lore_progression(src: Dictionary) -> void:
	# revelação gradual: cada documento é encontrado no capítulo declarado
	for d in src["docs"]:
		var room: String = src["docs"][d]
		var rc := int(NarrativeManager.rooms_db[room]["chapter"])
		t.check(int(NarrativeManager.docs_db[d]["chapter"]) == rc, "documento '%s' é do capítulo %d e está em %s (cap. %d)" % [d, NarrativeManager.docs_db[d]["chapter"], room, rc])
	# a identidade de Clara Valmont só aparece a partir do capítulo IV
	for d in NarrativeManager.docs_db:
		if int(NarrativeManager.docs_db[d]["chapter"]) < 4:
			t.check(not str(NarrativeManager.docs_db[d]["body"]).contains("Clara Valmont"), "'%s' (cap. <4) não revela a identidade de Clara cedo demais" % d)
	# o Morador é explicado (cap. III) e os buracos têm explicação narrativa
	t.check(str(NarrativeManager.docs_db["necropsia"]["body"]).contains("Morador"), "necropsia explica a natureza do Morador")
	t.check(str(NarrativeManager.docs_db["mapa_tnc"]["body"]).contains("cria um"), "mapa do TNC explica os buracos")
	# por que o orfanato continua funcionando
	t.check(str(NarrativeManager.docs_db["recibo_fundacao"]["body"]).contains("2031") and str(NarrativeManager.docs_db["contrato_fundacao"]["body"]).contains("observar"), "motivo de o orfanato continuar e observador do final Liberdade")
	# cada capítulo recebe ao menos 2 documentos novos
	var per := {}
	for d in src["docs"]:
		var ch := int(NarrativeManager.docs_db[d]["chapter"])
		per[ch] = int(per.get(ch, 0)) + 1
	for ch in range(1, 6):
		t.check(int(per.get(ch, 0)) >= 1, "capítulo %d tem documentos (%d)" % [ch, int(per.get(ch, 0))])
	for ch in [3, 4]:
		t.check(int(per.get(ch, 0)) >= 4, "capítulo %d aprofunda a história (%d documentos)" % [ch, int(per.get(ch, 0))])
	# gravações são do tipo áudio
	var audio := 0
	for d in NarrativeManager.docs_db:
		if NarrativeManager.docs_db[d].get("kind", "") == "audio":
			audio += 1
	t.check(audio >= 3, "gravações em áudio (%d)" % audio)

func _test_transitions() -> void:
	for n in range(1, 6):
		var c: Dictionary = NarrativeManager.cutscenes_db["chapter_%d" % n]
		t.check(str(c.get("title", "")) != "" and str(c.get("subtitle", "")) != "" and str(c.get("sound", "")) != "" and str(c.get("scene", "")).begins_with("title_"), "capítulo %d: título, descrição, som e cena" % n)
		t.check(c["sound"] in AudioManager.SOUND_NAMES, "capítulo %d: som existe" % n)
	for n in range(1, 5):
		t.check(NarrativeManager.cutscenes_db.has("chapter_end_%d" % n), "cartão de fim do capítulo %d" % n)
	# reprodução real da transição (UI), com avanço automático
	Engine.time_scale = 4.0
	GameManager.test_mode = false
	for id in ["chapter_end_1", "chapter_2"]:
		var ui := MemoryUI.new()
		add_child(ui)
		var done := [false]
		var f := func() -> void:
			await ui.play_cutscene(id)
			done[0] = true
		f.call()
		var g := 0
		var shown := false
		while not done[0] and g < 300:
			await get_tree().create_timer(0.1).timeout
			shown = shown or ui.visible
			ui._advance.emit()
			g += 1
		t.check(done[0] and shown and not ui.visible, "transição '%s' toca e termina sozinha" % id)
		ui.queue_free()
	Engine.time_scale = 1.0
	GameManager.test_mode = true
	# progresso salvo na virada de capítulo
	GameManager.new_game()
	GameManager.test_mode = true
	var game: Game = load("res://scenes/main/Game.tscn").instantiate()
	add_child(game)
	for i in 8:
		await get_tree().process_frame
	SaveManager.delete_slot("auto")
	await game.goto_chapter(2)
	t.check(GameManager.chapter == 2 and game.room.id == "c2_dormitorio", "goto_chapter leva ao início do capítulo II")
	t.check(NarrativeManager.has_flag("chapter_1_done") and NarrativeManager.has_flag("chapter_2_started"), "flags de fim/início de capítulo")
	var auto := SaveManager.read_slot("auto")
	t.check(not auto.is_empty() and int(auto["chapter"]) == 2, "autosave gravado na virada de capítulo")
	t.check(NarrativeManager.objective != "", "objetivo do novo capítulo registrado")
	game.queue_free()
	await get_tree().process_frame
	SaveManager.delete_slot("auto")
	GameManager.new_game()
