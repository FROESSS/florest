extends Node
## Testes automatizados (executar: godot --headless --path . res://tests/TestRunner.tscn).
## Suítes: dados, geometria/alcançabilidade, sistemas, IA, finais, save/load, walkthrough completo.

var failures: Array[String] = []
var passed: int = 0
var suite_filter: String = ""

func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(msg)
		print("  FALHA: ", msg)

func _ready() -> void:
	GameManager.test_mode = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--suite="):
			suite_filter = a.substr(8)
	var wd := Timer.new()
	wd.wait_time = 560.0
	wd.one_shot = true
	wd.timeout.connect(func() -> void:
		print("TIMEOUT: testes excederam o tempo limite")
		get_tree().quit(2))
	add_child(wd)
	wd.start()
	await get_tree().process_frame
	var suites := ["data", "geometry", "systems", "ai", "endings", "save", "e2", "e3", "e4", "walkthrough"]
	for s in suites:
		if suite_filter != "" and suite_filter != s:
			continue
		print("== Suíte: ", s)
		var script: GDScript = load("res://tests/suite_%s.gd" % s)
		if script == null or not script.can_instantiate():
			check(false, "suíte %s não compila" % s)
			continue
		var inst = script.new()
		inst.t = self
		add_child(inst)
		await inst.run()
		inst.queue_free()
	print("\nRESULTADO: %d verificações OK, %d falhas" % [passed, failures.size()])
	for f in failures:
		print(" - ", f)
	get_tree().quit(1 if failures.size() > 0 else 0)
