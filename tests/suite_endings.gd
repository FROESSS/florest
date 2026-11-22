extends Node
## Tabela de condições dos finais (docs/ENDINGS.md). Os 4 finais precisam ser alcançáveis e nenhum depende só da escolha final.
var t

func _opts() -> Array:
	return NarrativeManager.final_options().map(func(o): return o["id"])

func _reset() -> void:
	NarrativeManager.reset()
	InventoryManager.reset()

func run() -> void:
	_reset()
	t.check(_opts().is_empty(), "sem preparação, nenhum final está disponível (a decisão não é de última hora)")
	NarrativeManager.set_flag("escape_tunnel_open")
	t.check(_opts() == ["liberdade"], "túnel aberto → só LIBERDADE")
	_reset()
	NarrativeManager.set_flag("reactor_primed")
	t.check(_opts() == ["silencio"], "reator armado → SILÊNCIO")
	_reset()
	NarrativeManager.set_flag("equipment_destroyed")
	t.check(_opts() == ["silencio"], "equipamento destruído → SILÊNCIO")
	_reset()
	NarrativeManager.set_flag("control_card")
	t.check(_opts() == ["herdeiro"], "cartão de controle → HERDEIRO")
	# secreto: precisa de TUDO
	_reset()
	t.check(not NarrativeManager.secret_available(), "secreto indisponível no início")
	for m in ["ursinho", "foto", "desenho", "aula", "tomas", "cuidadora", "brinquedos", "clara"]:
		NarrativeManager.add_memory(m)
	NarrativeManager.add_counter("clara_trust", 2)
	NarrativeManager.set_flag("keep_elias_record")
	t.check(not NarrativeManager.secret_available(), "secreto exige a memória pré-inauguração")
	NarrativeManager.add_memory("pre_inauguracao")
	t.check(NarrativeManager.secret_available(), "secreto disponível com ≥8 memórias, pré-inauguração, confiança e registro guardado")
	t.check("coisas_perdidas" in _opts(), "opção secreta aparece")
	NarrativeManager.set_flag("equipment_destroyed")
	t.check(not NarrativeManager.secret_available(), "destruir o equipamento impede o secreto (consequência)")
	NarrativeManager.flags.erase("equipment_destroyed")
	NarrativeManager.flags["clara_trust"] = 1
	t.check(not NarrativeManager.secret_available(), "pouca confiança em Clara impede o secreto")
	NarrativeManager.flags["clara_trust"] = 2
	NarrativeManager.flags.erase("keep_elias_record")
	t.check(not NarrativeManager.secret_available(), "destruir o registro de Elias impede o secreto")
	_reset()
	# memórias suficientes mas poucas (7)
	for m in ["ursinho", "foto", "desenho", "aula", "tomas", "cuidadora", "pre_inauguracao"]:
		NarrativeManager.add_memory(m)
	NarrativeManager.add_counter("clara_trust", 3)
	NarrativeManager.set_flag("keep_elias_record")
	t.check(not NarrativeManager.secret_available(), "7 memórias não bastam")
	NarrativeManager.add_memory("brinquedos")
	t.check(NarrativeManager.secret_available(), "8 memórias bastam")
	_reset()
