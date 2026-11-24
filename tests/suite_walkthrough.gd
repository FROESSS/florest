extends Node
## Roteiro de QA automatizado: percorre os 5 capítulos de ponta a ponta (interações reais, dados reais)
## e confirma que os 4 finais são alcançáveis com as escolhas/flags corretas.
var t
var game: Game
var tag: String = ""

func run() -> void:
	await _play("A", {"equipamento": 1, "reator": 0, "final": "liberdade"}, "liberdade", true)
	await _play("B", {"equipamento": 1, "reator": 0, "final": "coisas_perdidas"}, "coisas_perdidas", true)
	await _play("C", {"equipamento": 1, "reator": 1, "final": "herdeiro"}, "herdeiro", false)
	await _play("D", {"equipamento": 1, "reator": 0, "final": "silencio"}, "silencio", true)
	await _play("E", {"equipamento": 0, "reator": 1, "final": "silencio"}, "silencio", false)
	await _play("F", {"equipamento": 1, "reator": 0, "registro_elias": 1, "final": "herdeiro"}, "herdeiro", false)

func _settle() -> void:
	for i in 4:
		await get_tree().process_frame
	var guard := 0
	while (game.runner.busy or game.changing_room) and guard < 900:
		await get_tree().process_frame
		guard += 1

func _use(obj_id: String) -> void:
	var o := game.room.find_object(obj_id)
	t.check(o != null, "[%s] objeto '%s' existe em %s" % [tag, obj_id, game.room.id])
	if o == null:
		return
	await game.runner.interact(o)
	await _settle()

func _expect_room(room_id: String) -> void:
	t.check(game.room.id == room_id, "[%s] sala esperada %s (atual %s)" % [tag, room_id, game.room.id])

func _disable_enemies(_id: String) -> void:
	for e in game.room.enemies:
		if is_instance_valid(e):
			e.enabled = false

func _play(label: String, choices: Dictionary, expected_ending: String, check_all_endings: bool) -> void:
	tag = label
	GameManager.new_game()
	GameManager.test_mode = true
	GameManager.test_choices = choices
	game = load("res://scenes/main/Game.tscn").instantiate()
	add_child(game)
	game.room_loaded.connect(_disable_enemies)
	await get_tree().process_frame
	await _settle()
	_disable_enemies("")
	_expect_room("c1_quarto")
	# ---------- Capítulo I ----------
	await _use("porta")
	_expect_room("c1_quarto")  # trancada sem lanterna
	await _use("gaveta")
	await _use("ursinho")
	await _use("porta"); _expect_room("c1_corredor")
	await _use("d_salao"); _expect_room("c1_corredor")  # emperrada antes do alarme
	await _use("d_sec"); _expect_room("c1_corredor")      # trancada sem chave
	await _use("d_dorm"); _expect_room("c1_dormitorio")
	await _use("caixa")
	await _use("porta"); _expect_room("c1_corredor")
	await _use("d_sec"); _expect_room("c1_secretaria")
	await _use("gaveta")                                  # sem lembrar da foto: não abre
	t.check(not InventoryManager.has_item("chave_servico"), "[%s] gaveta exige lembrar a fotografia" % tag)
	await _use("foto")
	await _use("gaveta")
	await _use("arquivo")
	t.check(NarrativeManager.has_flag("c1_alarm"), "[%s] alarme dispara ao pegar a chave" % tag)
	t.check(SaveManager.has_slot("auto"), "[%s] checkpoint salvo" % tag)
	await _use("porta"); _expect_room("c1_corredor")
	await _use("d_salao"); _expect_room("c1_saguao")
	await _use("recep")
	await _use("servico")
	_expect_room("c2_dormitorio")
	t.check(GameManager.chapter == 2, "[%s] capítulo 2 iniciado" % tag)
	# ---------- Capítulo II ----------
	await _use("clara")
	t.check(NarrativeManager.has_flag("clara_follows") and game.room.find_object("clara_follow") != null, "[%s] Clara passa a seguir Elias" % tag)
	await _use("desenho")
	await _use("criado")
	await _use("porta"); _expect_room("c2_corredor")
	await _use("d_enf"); _expect_room("c2_corredor")      # trancada
	await _use("d_aula"); _expect_room("c2_aula")
	await _use("quadro")
	await _use("livro")
	await _use("mesa")
	await _use("des_a")
	await _use("des_b")
	await _use("porta"); _expect_room("c2_corredor")
	await _use("alcapao"); _expect_room("c2_corredor")    # sem chave
	await _use("d_enf"); _expect_room("c2_enfermaria")
	await _use("leito_tomas")
	await _use("arquivo")
	await _use("lista")
	await _use("porta"); _expect_room("c2_corredor")
	await _use("d_aula"); _expect_room("c2_aula")
	await _use("tomas")
	t.check(NarrativeManager.has_flag("helped_child_1"), "[%s] ajudar Tomás registra a escolha" % tag)
	await _use("porta"); _expect_room("c2_corredor")
	await _use("alcapao"); _expect_room("c2_alcapao")
	await _use("porta_fundo")
	_expect_room("c3_tunel")
	t.check(GameManager.chapter == 3, "[%s] capítulo 3 iniciado" % tag)
	# ---------- Capítulo III ----------
	await _use("bilhete")
	await _use("mapa")
	await _use("pilha1")
	await _use("d_ref"); _expect_room("c3_refeitorio")
	await _use("painel")
	await _use("tres")
	await _use("arq_necropsia")
	t.check(NarrativeManager.has_flag("tissue_burned"), "[%s] incinerador queima o tecido" % tag)
	await _use("panelas")
	await _use("pilha")
	await _use("bateria")
	t.check(InventoryManager.has_item("bateria_lab"), "[%s] bateria do laboratório coletada" % tag)
	await _use("d_norte"); _expect_room("c3_memoria")
	await _use("bau")
	await _use("prateleira")
	await _use("lia")
	await _use("porta"); _expect_room("c3_refeitorio")
	await _use("d_leste"); _expect_room("c3_caldeira")
	await _use("elevador"); _expect_room("c3_caldeira")   # faltam o cartão
	await _use("mesa")
	await _use("armario")
	await _use("gravador")
	await _use("elevador")
	_expect_room("c4_lab_hall")
	t.check(GameManager.chapter == 4 and NarrativeManager.has_flag("lab_open"), "[%s] capítulo 4 iniciado" % tag)
	t.check(not InventoryManager.has_item("cartao_acesso"), "[%s] componentes consumidos no elevador" % tag)
	# ---------- Capítulo IV ----------
	await _use("elevador"); _expect_room("c4_lab_hall")   # ainda não entendeu o laboratório
	await _use("aviso")
	await _use("contrato")
	await _use("d_clara"); _expect_room("c4_lab_hall")    # trancada antes do terminal
	await _use("d_arq"); _expect_room("c4_arquivos")
	await _use("terminal")
	await _use("arq1")
	await _use("arq2")
	await _use("arq3")
	await _use("cofre")
	await _use("beto")
	await _use("d_este"); _expect_room("c4_lab_hall")
	await _use("d_cir"); _expect_room("c4_cirurgia")
	await _use("projetor")
	await _use("arq_memo")
	await _use("gravador")
	await _use("d_oeste"); _expect_room("c4_lab_hall")
	await _use("d_clara"); _expect_room("c4_clara")
	await _use("cadeira")
	await _use("carta")
	await _use("porta"); _expect_room("c4_lab_hall")
	await _use("elevador")
	_expect_room("c5_colapso")
	t.check(GameManager.chapter == 5, "[%s] capítulo 5 iniciado" % tag)
	# ---------- Capítulo V ----------
	await _use("manual")
	await _use("valvulas")
	await _use("pilha")
	await _use("d_reator"); _expect_room("c5_reator")
	await _use("manual_emerg")
	await _use("foto_func")
	await _use("console")
	await _use("d_oeste"); _expect_room("c5_colapso")
	await _use("d_controle"); _expect_room("c5_controle")
	await _use("gravador")
	await _use("principal"); _expect_room("c5_controle")  # exige lembrar quem é
	t.check(GameManager.ended == "", "[%s] console bloqueado antes da memória de Elias" % tag)
	await _use("cadeira")
	t.check(NarrativeManager.memory_count() >= 1 and NarrativeManager.has_flag("mem_elias"), "[%s] memória final registrada" % tag)
	var opts: Array = NarrativeManager.final_options().map(func(o): return o["id"])
	t.check(expected_ending in opts, "[%s] final '%s' está disponível entre %s" % [tag, expected_ending, str(opts)])
	if check_all_endings:
		t.check(NarrativeManager.memory_count() == 13, "[%s] 13 memórias coletadas (%d)" % [tag, NarrativeManager.memory_count()])
		t.check(opts.size() == 4, "[%s] os 4 finais disponíveis com exploração completa (%s)" % [tag, str(opts)])
	await _use("principal")
	t.check(GameManager.ended == expected_ending, "[%s] final alcançado: %s (esperado %s)" % [tag, GameManager.ended, expected_ending])
	if label == "E":
		t.check(not ("coisas_perdidas" in opts), "[%s] destruir o equipamento remove o final secreto" % tag)
	if label == "F":
		t.check(not ("coisas_perdidas" in opts), "[%s] destruir o registro remove o final secreto" % tag)
	game.queue_free()
	await get_tree().process_frame
	GameManager.test_choices = {}
