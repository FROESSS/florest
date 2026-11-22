extends Node
## Cada sala é construída; objetos, esconderijos, portas e inimigos são alcançáveis a partir dos spawns.
## Barreiras removíveis: sem remover, nada essencial pode ficar preso (só objetos "gated_by_barrier");
## removidas por flag, tudo precisa ficar alcançável.
var t

func run() -> void:
	for rid in NarrativeManager.rooms_db:
		var room := Room.new()
		add_child(room)
		room.build(rid)
		await get_tree().process_frame
		var blocked := _check_room(rid, room, false)
		if not room.barriers.is_empty():
			for b in room.barriers:
				for f in b["spec"].get("removed_if", {}).get("flags", []):
					NarrativeManager.set_flag(f, true)
			room.refresh_dynamic()
			var blocked2 := _check_room(rid + " (sem barreiras)", room, true)
			t.check(blocked2.is_empty(), "%s: nada fica inalcançável sem barreiras (%s)" % [rid, str(blocked2)])
			for id in blocked:
				var o := room.find_object(id)
				t.check(o != null and o.spec.get("gated_by_barrier", false), "%s/%s: inalcançável com barreira mas sem marca gated_by_barrier" % [rid, id])
			NarrativeManager.reset()
		else:
			t.check(blocked.is_empty(), "%s: tudo alcançável (%s)" % [rid, str(blocked)])
		room.queue_free()

func _check_room(rid: String, room: Room, strict: bool) -> Array:
	var blocked: Array = []
	var nav := room.nav
	var spawns: Dictionary = room.spec["spawns"]
	var first: Vector2 = room.spawn_position(spawns.keys()[0])
	for sname in spawns:
		var sp := room.spawn_position(sname)
		t.check(nav.is_free_point(sp), "%s: spawn '%s' em tile livre" % [rid, sname])
		if strict or sname == spawns.keys()[0] or room.barriers.is_empty():
			t.check(nav.reachable(first, sp), "%s: spawn '%s' alcançável" % [rid, sname])
	for o in room.objects:
		var oid := str(o.spec.get("id", "?"))
		var interactive: bool = o.spec.has("effects") or o.spec.has("door") or o.spec.get("hide", false)
		var r := o.rect
		t.check(r.position.x >= 0 and r.position.y >= 0 and r.end.x <= room.pixel_size().x and r.end.y <= room.pixel_size().y, "%s/%s dentro dos limites" % [rid, oid])
		if not interactive:
			continue
		var ok := false
		var c0 := nav.cell_of(r.position) - Vector2i(2, 2)
		var c1 := nav.cell_of(r.end) + Vector2i(2, 2)
		for y in range(c0.y, c1.y + 1):
			for x in range(c0.x, c1.x + 1):
				var c := Vector2i(x, y)
				if nav.is_solid_cell(c):
					continue
				var center := nav.center_of(c)
				for off in [Vector2(0, 0), Vector2(-4, 0), Vector2(4, 0), Vector2(0, -2), Vector2(0, 3), Vector2(0, 5)]:
					if r.grow(8.0).has_point(center + off + Vector2(0, -4)) and nav.reachable(first, center):
						ok = true
		if not ok:
			blocked.append(oid)
		if o.is_hide_spot():
			t.check(nav.is_free_point(o.exit_position()), "%s/%s: saída do esconderijo livre" % [rid, oid])
	for e in room.spec.get("enemies", []):
		var et: Array = e.get("tile", [1, 1])
		var ep := nav.center_of(Vector2i(et[0], et[1]))
		var is_hunter: bool = str(e.get("type", "")) == "resident" and str(e.get("mode", "hunter")) == "hunter"
		if not is_hunter:
			t.check(nav.is_free_point(ep), "%s: inimigo '%s' em tile livre" % [rid, e.get("id", "?")])
			for p in e.get("patrol", []):
				var pp := nav.center_of(Vector2i(p[0], p[1]))
				t.check(nav.is_free_point(pp) and nav.reachable(ep, pp), "%s: ponto de patrulha %s alcançável" % [rid, str(p)])
		for v in e.get("vents", []):
			var vp := nav.center_of(Vector2i(v[0], v[1]))
			t.check(nav.is_free_point(vp), "%s: abertura %s livre" % [rid, str(v)])
			t.check(nav.reachable(first, vp), "%s: abertura %s alcançável" % [rid, str(v)])
	for tr in room.spec.get("triggers", []):
		var rr: Array = tr["rect"]
		t.check(rr[0] >= 1 and rr[1] >= 2 and rr[0] + rr[2] <= room.size_tiles.x and rr[1] + rr[3] <= room.size_tiles.y, "%s: trigger '%s' dentro da sala" % [rid, tr.get("id", "?")])
	return blocked
