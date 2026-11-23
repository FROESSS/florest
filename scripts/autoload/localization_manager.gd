extends Node
## Textos de interface. Idioma inicial: pt-BR. O conteúdo narrativo está em data/*.json (pt-BR).

var current: String = "pt-BR"

const STRINGS := {
	"pt-BR": {
		"boot.loading": "Carregando...",
		"menu.title": "O ORFANATO DAS COISAS PERDIDAS",
		"menu.new_game": "Novo jogo",
		"menu.continue": "Continuar",
		"menu.load": "Carregar",
		"menu.settings": "Configurações",
		"menu.credits": "Créditos",
		"menu.quit": "Sair",
		"menu.back": "Voltar",
		"menu.no_saves": "Nenhum jogo salvo.",
		"menu.empty_slot": "— vazio —",
		"pause.title": "PAUSA",
		"pause.resume": "Continuar",
		"pause.save": "Salvar jogo",
		"pause.load": "Carregar jogo",
		"pause.settings": "Configurações",
		"pause.menu": "Menu principal",
		"pause.saved": "Jogo salvo.",
		"pause.cant_save": "Não é possível salvar durante uma perseguição.",
		"settings.title": "CONFIGURAÇÕES",
		"settings.master": "Volume geral",
		"settings.music": "Música",
		"settings.sfx": "Efeitos",
		"settings.ambient": "Ambiente",
		"settings.fullscreen": "Tela cheia",
		"settings.scale": "Escala da janela",
		"settings.subtitles": "Legendas",
		"settings.flashes": "Reduzir flashes",
		"settings.shake": "Reduzir tremor de tela",
		"settings.distortion": "Reduzir distorção",
		"settings.language": "Idioma: Português (Brasil)",
		"hud.interact": "[E]",
		"hud.battery": "Bateria",
		"hud.chase": "PERSEGUIÇÃO",
		"hud.item_got": "Item coletado: %s",
		"hud.doc_got": "Documento: %s",
		"hud.memory_got": "Memória: %s",
		"hud.objective": "Novo objetivo registrado (J)",
		"hud.stamina": "Estamina",
		"hud.exhausted": "CANSADO",
		"hud.wound": "Ferimento",
		"hud.healed": "Ferimento tratado.",
		"hud.no_kit": "Não há kit médico.",
		"hud.no_wound": "Elias não está ferido.",
		"hud.flashlight_on": "Lanterna ligada",
		"hud.flashlight_off": "Lanterna desligada",
		"hud.no_battery": "A bateria acabou.",
		"hud.hiding": "Escondido — [E] para sair",
		"inv.title": "INVENTÁRIO",
		"inv.empty": "Nenhum item.",
		"journal.title": "DIÁRIO",
		"journal.docs": "Documentos",
		"journal.memories": "Memórias",
		"journal.objective": "Objetivo",
		"journal.none": "Nada registrado ainda.",
		"puzzle.confirm": "Confirmar",
		"puzzle.cancel": "Esc: sair",
		"puzzle.wrong": "Não funcionou.",
		"puzzle.solved": "Funcionou.",
		"game.captured": "Elias foi capturado...",
		"game.chapter": "Capítulo %d",
		"credits.text": "O ORFANATO DAS COISAS PERDIDAS\n\nProjeto, roteiro, código, arte procedural e áudio sintetizado:\ncriados originalmente para este projeto.\n\nMotor: Godot Engine 4.4.1 (MIT)\n\nNenhum asset de jogos comerciais foi usado.\nVeja docs/ASSET_LICENSES.md.",
		"controls.hint": "WASD/Setas: mover · Shift: correr · E: interagir · F: lanterna · Tab: inventário · J: diário · Esc: pausa",
	}
}

func t(key: String) -> String:
	var table: Dictionary = STRINGS.get(current, STRINGS["pt-BR"])
	return table.get(key, key)

func tf(key: String, args: Array) -> String:
	return t(key) % args
