# Design técnico

Godot **4.4.1 estável**, GDScript, renderer Compatibility (OpenGL), viewport 640×360, `stretch mode = viewport` + `scale mode = integer` (pixel-perfect), filtro de textura *nearest*, snap 2D a pixel.

## Autoloads (ordem de carga)
| Nome | Responsabilidade |
|---|---|
| `SettingsManager` | Mapa de entradas (registrado em código), volumes/barramentos (Master/Music/SFX/Ambient), tela cheia/escala, acessibilidade; persiste em `user://settings.cfg` |
| `LocalizationManager` | Textos de interface (pt-BR). Conteúdo narrativo está nos JSON |
| `AudioManager` | **Síntese procedural** de todos os sons (AudioStreamWAV gerado em código), ambiência em loop, sons posicionais (`AudioStreamPlayer2D`), legendas |
| `InventoryManager` | Itens-chave, sem duplicação |
| `NarrativeManager` | Carrega os JSON; flags/contadores; documentos; memórias; objetivo; `check(cond)`; tabela de finais |
| `GameManager` | Capítulo/sala, bateria, lanterna, ruído (`noise_emitted`), perseguição, captura, modo de teste |
| `SaveManager` | Save versionado e validado em `user://saves/` |
| `SceneManager` | Fade e troca de cenas |

## Cenas e fluxo
`Main` (gera áudio) → `MainMenu` → `Game`. `Game` (`scripts/world/game.gd`) cria a UI (HUD, diálogo, puzzle, livro, memória, pausa) e o `EffectRunner`, e carrega **uma sala por vez** (`Room`). Cenas `.tscn` são finas; salas e UI são montadas por código a partir de dados.

## Salas (orientadas a dados)
`data/chapters/chapter_N.json` → `rooms{}`: tamanho em tiles (16 px), tema visual, `blocks` (paredes internas), `barriers` (tecido removível por flag), `spawns`, `lights`, `objects`, `triggers`, `enemies`, `clara_talk`. `Room` assa o chão/paredes numa textura (`TileArt`), cria colisões (retângulos mesclados), `RoomNav` (grade lógica: sólido/opaco + A* + linha de visão) e `Interactable`s. Paredes têm face frontal e topo (profundidade); objetos e personagens usam *y-sort* (oclusão).

## Interações e efeitos
Cada objeto tem `requires` (condição), `effects` (lista), `once`, `repeat_text`, `visible_if/hide_if`. `EffectRunner` executa efeitos em sequência, pausa o mundo durante diálogos/puzzles e suporta ramos `if/then/else`.
Efeitos: `text`, `say`, `flag`, `counter`, `give`, `take`, `battery`, `memory`, `doc`, `puzzle`, `choice`, `goto`, `cutscene`, `chapter`, `checkpoint`, `noise`, `sfx`, `force_chase`, `shake`, `wait`, `objective`, `hint`, `clara_talk`, `set_clara`, `final_choice`, `ending`.
Condições: `flags`, `not_flags`, `any_flags`, `items`, `not_items`, `counter`, `memories_min`, `chapter_min`.

## Jogador
`CharacterBody2D`, movimento em 8 direções com vetor normalizado, caminhada 70 px/s e corrida 125 px/s (configuráveis em `settings.cfg`), colisão 8×5 px nos pés. Passos emitem ruído: **andar 55 px**, **correr 150 px**. Lanterna = `PointLight2D` com textura de cone + brilho ambiente; bateria 100% dura ≈ 5,5 min de uso contínuo (pilhas recarregam).

## IA
**Cuidadora** (`caretaker.gd`): estados `PATROL, SUSPICIOUS, INVESTIGATE, SEARCH, CHASE, ATTACK, RETURN`.
- Visão: alcance 120 px (×1.4 com lanterna ligada), cone de 110°, sentido de proximidade 24 px, linha de visão por grade; *awareness* sobe gradualmente (barra + "?" → "!") — nunca captura sem aviso.
- Audição: ruído com raio; atrás de paredes o raio vale 60%.
- Perde o alvo após 3,5 s sem visão (ou 2 s a mais de 240 px) → `SEARCH` em 3 pontos → `RETURN` → `PATROL`.
- Esconderijo: ela só abre se **viu Elias entrar**; caso contrário perde o rastro.
- Sinais: ícone sobre a cabeça, brilho, cantiga distorcida (patrulha), respiração (busca), grito (perseguição), legendas.
**Morador** (`resident.gd`): `hunter` (zona + aberturas planejadas; `DORMANT→WARNING(3 s)→EMERGE→STALK→RETREAT`; nunca surge a < 130 px de Elias; velocidade 58 < 70; reage à luz; desiste se Elias sai da zona/se esconde) e `blocker` (bloqueia corredor até ruído `lure` planejado).
Inimigos existem só na sala atual (decisão de projeto: simples e justo); sua posição não persiste entre salas.

## Salvamento
`user://saves/{auto,slot1,slot2,slot3}.json`: `version`, capítulo, sala, spawn, posição segura, bateria, tempo, inventário, flags/contadores, documentos, memórias, objetivo. Escrita via arquivo temporário + `.bak` do anterior; validação (versão, capítulo, sala, tipos, bateria, itens conhecidos); versão futura é rejeitada; `_migrate` é o ponto de extensão (com `.premigration` de backup). Estado transitório (lanterna ligada, perseguição) não é salvo. Checkpoint automático a cada sala (exceto durante perseguição) e explícito em momentos-chave.

## Desempenho
Textura de sala única por sala; no máx. 8 luzes de ambiente por sala + 2 do jogador; colisões mescladas por linha; A* em grade pequena; áudio sintetizado uma vez na inicialização (~1–2 s).
