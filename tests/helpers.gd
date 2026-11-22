class_name TestHelpers
extends RefCounted
## Utilitários de teste: simulação de tempo e criação de arenas.

static func sim(tree: SceneTree, seconds: float) -> void:
	var acc := 0.0
	while acc < seconds:
		await tree.physics_frame
		acc += tree.root.get_physics_process_delta_time() if false else (1.0 / 60.0)

static func make_arena(host: Node, room_id: String, player_tile: Vector2i) -> Dictionary:
	GameManager.test_mode = true
	var room := Room.new()
	host.add_child(room)
	room.build(room_id)
	var player := Player.new()
	room.y_layer.add_child(player)
	player.position = room.nav.center_of(player_tile)
	GameManager.player = player
	GameManager.last_safe_pos = player.position
	GameManager.chasers.clear()
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	return {"room": room, "player": player}
