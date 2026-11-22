class_name Recovery
extends RefCounted
## Escolha do ponto de retorno após a morte: livre, alcançável e longe de inimigos/aberturas.

const MIN_SAFE_DIST := 150.0   # inimigos que nascem na sala
const MIN_VENT_DIST := 130.0   # aberturas/buracos do Morador (igual ao surgimento justo)

## Posições "perigosas" de uma sala: onde cada inimigo nasce + aberturas do Morador.
static func danger_points(room: Room) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for d in danger_list(room):
		out.append(d["p"])
	return out

static func danger_list(room: Room) -> Array:
	var out: Array = []
	for e in room.spec.get("enemies", []):
		var hunter: bool = str(e.get("type", "")) == "resident" and str(e.get("mode", "hunter")) == "hunter"
		if not hunter and e.has("tile"):
			out.append({"p": room.nav.center_of(Vector2i(e["tile"][0], e["tile"][1])), "r": MIN_SAFE_DIST})
		for v in e.get("vents", []):
			out.append({"p": room.nav.center_of(Vector2i(v[0], v[1])), "r": MIN_VENT_DIST})
	for h in GameManager.world_state.get("holes", {}).get(room.id, []):
		out.append({"p": room.nav.center_of(Vector2i(h["tile"][0], h["tile"][1])), "r": MIN_VENT_DIST})
	return out

static func candidates(room: Room) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for r in room.spec.get("recovery", []):
		out.append(room.nav.center_of(Vector2i(r[0], r[1])))
	for s in room.spec.get("spawns", {}).values():
		out.append(room.nav.center_of(Vector2i(s[0], s[1])))
	return out

## Retorna {"pos": Vector2, "safe": bool, "min_dist": float}.
static func choose(room: Room, death_pos: Vector2, extra_danger: Array = []) -> Dictionary:
	var danger := danger_list(room)
	for p in extra_danger:
		danger.append({"p": p, "r": MIN_SAFE_DIST})
	var first: Vector2 = room.spawn_position(room.spec["spawns"].keys()[0])
	var best_safe := Vector2.ZERO
	var best_safe_d := INF
	var best_any := Vector2.ZERO
	var best_any_m := -1.0
	var have_safe := false
	for c in candidates(room):
		if not room.nav.is_free_point(c) or not room.nav.reachable(first, c):
			continue
		var m := INF
		for d in danger:
			m = minf(m, c.distance_to(d["p"]) - float(d["r"]) + MIN_SAFE_DIST)
		if m >= MIN_SAFE_DIST:
			var dd := c.distance_to(death_pos)
			if dd < best_safe_d:
				best_safe_d = dd
				best_safe = c
				have_safe = true
		if m > best_any_m:
			best_any_m = m
			best_any = c
	if have_safe:
		return {"pos": best_safe, "safe": true, "min_dist": MIN_SAFE_DIST}
	return {"pos": best_any, "safe": false, "min_dist": best_any_m}
