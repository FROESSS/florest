extends Node
## Etapa 5: verificações do acabamento visual (texturas ricas, sem props genéricos, sprites completos).
var t

func _image_stats(img: Image) -> Dictionary:
	var colors := {}
	var sum := 0.0
	var sum2 := 0.0
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			colors[c.to_html(false)] = true
			var l := c.get_luminance()
			sum += l
			sum2 += l * l
			n += 1
	var mean := sum / n
	return {"colors": colors.size(), "std": sqrt(maxf(0.0, sum2 / n - mean * mean))}

func run() -> void:
	GameManager.test_mode = true
	var kinds := {}
	for rid in NarrativeManager.rooms_db:
		var room := Room.new()
		add_child(room)
		room.build(rid)
		var tex: Texture2D = null
		for c in room.get_children():
			if c is Sprite2D and c.z_index == -10:
				tex = c.texture
		t.check(tex != null, "%s: textura de sala existe" % rid)
		if tex != null:
			var st := _image_stats(tex.get_image())
			t.check(st["colors"] >= 50, "%s: paleta rica (%d cores)" % [rid, st["colors"]])
			t.check(st["std"] > 0.03, "%s: sem áreas lisas/repetitivas (desvio %.3f)" % [rid, st["std"]])
		for o in room.spec.get("objects", []):
			kinds[str(o.get("kind", ""))] = o.get("variant", "")
		room.queue_free()
		await get_tree().process_frame
	# nenhum objeto usa o desenho genérico
	var generic := TileArt.prop("zzz_inexistente", 16, 16)
	for k in kinds:
		if k == "npc":
			continue
		var tx := TileArt.prop(k, 16, 16, str(kinds[k]))
		t.check(tx.get_image().get_data() != generic.get_image().get_data(), "objeto '%s' tem arte própria (não genérica)" % k)
	# personagens: quadros completos por direção/animação
	for style in ["elias", "clara", "caretaker", "kid_a", "kid_b", "kid_c"]:
		var sf := PixelArt.character_frames(style)
		for dir in ["down", "up", "left", "right"]:
			t.check(sf.get_frame_count("walk_" + dir) == 6 and sf.get_frame_count("run_" + dir) == 6, "%s/%s: caminhada e corrida com 6 quadros" % [style, dir])
			for a in ["idle", "interact", "hide", "hit"]:
				t.check(sf.has_animation("%s_%s" % [a, dir]), "%s: animação %s_%s" % [style, a, dir])
	# quadros distintos (animação de fato muda)
	var i0 := PixelArt.character_image("elias", "down", "walk", 0).get_data()
	var i1 := PixelArt.character_image("elias", "down", "walk", 3).get_data()
	t.check(i0 != i1, "quadros de caminhada são diferentes entre si")
	var sf2 := PixelArt.resident_frames()
	t.check(sf2.has_animation("sink") and sf2.has_animation("emerge") and sf2.get_frame_count("walk") == 4, "Morador: animações walk/emerge/sink")
	# silhuetas reconhecíveis: Cuidadora bem mais alta que Elias
	var h_elias := _opaque_height(PixelArt.character_image("elias", "down", "idle", 0))
	var h_care := _opaque_height(PixelArt.character_image("caretaker", "down", "idle", 0))
	t.check(h_care >= h_elias + 6, "silhuetas distintas: Cuidadora mais alta (%d vs %d px)" % [h_care, h_elias])
	# luz: texturas existem
	t.check(PixelArt.light_cone(256).get_width() == 256 and PixelArt.vignette() != null, "texturas de luz")

func _opaque_height(img: Image) -> int:
	var top := img.get_height()
	var bottom := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	return bottom - top + 1
