extends Node
## Integridade dos dados: JSON válido e todas as referências cruzadas existem.
var t

func run() -> void:
	t.check(NarrativeManager.load_errors.is_empty(), "JSON carrega sem erros: %s" % str(NarrativeManager.load_errors))
	t.check(NarrativeManager.chapters_db.size() == 5, "5 capítulos carregados (%d)" % NarrativeManager.chapters_db.size())
	for n in range(1, 6):
		var ch: Dictionary = NarrativeManager.chapters_db.get(n, {})
		t.check(NarrativeManager.rooms_db.has(str(ch.get("start_room", ""))), "Capítulo %d tem sala inicial válida" % n)
	for rid in NarrativeManager.rooms_db:
		var spec: Dictionary = NarrativeManager.rooms_db[rid]
		var spawns: Dictionary = spec.get("spawns", {})
		t.check(not spawns.is_empty(), "%s tem spawns" % rid)
		var ids := {}
		for o in spec.get("objects", []):
			var oid := str(o.get("id", ""))
			t.check(oid != "" and not ids.has(oid), "%s: id de objeto único '%s'" % [rid, oid])
			ids[oid] = true
			_check_effects(rid, o.get("effects", []))
			_check_cond(rid, o.get("requires", {}))
			if o.has("door"):
				var d: Dictionary = o["door"]
				var dest: Dictionary = NarrativeManager.rooms_db.get(str(d["to"]), {})
				t.check(not dest.is_empty(), "%s/%s: destino da porta existe (%s)" % [rid, oid, d["to"]])
				if not dest.is_empty() and str(d.get("spawn", "")) != "":
					t.check(dest.get("spawns", {}).has(d["spawn"]), "%s/%s: spawn '%s' existe em %s" % [rid, oid, d["spawn"], d["to"]])
		for tr in spec.get("triggers", []):
			_check_effects(rid, tr.get("effects", []))
		for e in spec.get("clara_talk", []):
			_check_effects(rid, e.get("effects", []))
	for cid in NarrativeManager.choices_db:
		for o in NarrativeManager.choices_db[cid]["options"]:
			_check_effects("choice " + cid, o.get("effects", []))
	for k in NarrativeManager.cutscenes_db:
		t.check(NarrativeManager.cutscenes_db[k].has("lines"), "cutscene %s tem linhas" % k)
	for n in range(1, 6):
		t.check(NarrativeManager.cutscenes_db.has("chapter_%d" % n), "cutscene chapter_%d" % n)
	for e in ["liberdade", "silencio", "herdeiro", "coisas_perdidas"]:
		t.check(NarrativeManager.cutscenes_db.has("ending_" + e), "cutscene do final " + e)

func _check_cond(where: String, c: Dictionary) -> void:
	for i in c.get("items", []):
		t.check(NarrativeManager.items_db.has(str(i)), "%s: item '%s' existe" % [where, i])

func _check_effects(where: String, effects: Array) -> void:
	for e in effects:
		if not (e is Dictionary):
			t.check(false, "%s: efeito inválido" % where)
			continue
		if e.has("give"):
			t.check(NarrativeManager.items_db.has(str(e["give"])), "%s: give '%s' existe" % [where, e["give"]])
		if e.has("take"):
			t.check(NarrativeManager.items_db.has(str(e["take"])), "%s: take '%s' existe" % [where, e["take"]])
		if e.has("memory"):
			t.check(NarrativeManager.memories_db.has(str(e["memory"])), "%s: memória '%s' existe" % [where, e["memory"]])
		if e.has("doc"):
			t.check(NarrativeManager.docs_db.has(str(e["doc"])), "%s: documento '%s' existe" % [where, e["doc"]])
		if e.has("puzzle"):
			t.check(NarrativeManager.puzzles_db.has(str(e["puzzle"])), "%s: puzzle '%s' existe" % [where, e["puzzle"]])
			_check_effects(where, e.get("on_solved", []))
			_check_effects(where, e.get("on_fail", []))
		if e.has("choice"):
			t.check(NarrativeManager.choices_db.has(str(e["choice"])), "%s: escolha '%s' existe" % [where, e["choice"]])
		if e.has("cutscene"):
			t.check(NarrativeManager.cutscenes_db.has(str(e["cutscene"])), "%s: cutscene '%s' existe" % [where, e["cutscene"]])
		if e.has("goto"):
			t.check(NarrativeManager.rooms_db.has(str(e["goto"]["room"])), "%s: goto sala '%s' existe" % [where, e["goto"]["room"]])
		if e.has("chapter"):
			t.check(NarrativeManager.chapters_db.has(int(e["chapter"])), "%s: capítulo %s existe" % [where, e["chapter"]])
		if e.has("if"):
			_check_cond(where, e["if"])
			_check_effects(where, e.get("then", []))
			_check_effects(where, e.get("else", []))
