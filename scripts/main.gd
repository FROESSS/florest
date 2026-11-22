extends Node
## Cena de entrada: gera o áudio procedural (tela de carregamento) e vai ao menu.

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var lbl := Label.new()
	lbl.text = LocalizationManager.t("boot.loading")
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.position = Vector2(270, 170)
	layer.add_child(lbl)
	await get_tree().process_frame
	await AudioManager.warm_up()
	SceneManager.goto_menu(true)
