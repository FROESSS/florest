# O Orfanato das Coisas Perdidas

Survival horror / horror psicológico 2D top-down em pixel art, feito em **Godot 4.4.1 (estável)** com **GDScript**.
Você é **Elias**, 12 anos, que acorda num orfanato isolado e precisa sobreviver, investigar o **Projeto Lázaro** e decidir o destino do que restou dele.

- Plataforma principal: **Windows 10/11 64-bit** (ZIP portable com `Orfanato.exe`).
- Resolução interna: **640×360**, escala por múltiplos inteiros (pixel-perfect).
- Idioma inicial: **pt-BR**. Single-player.
- Arte e áudio: **100% procedurais e originais**, gerados em código (ver `docs/ASSET_LICENSES.md`). Nenhum asset de jogos comerciais.

## Estado real do projeto (v0.9.0)

| Área | Estado |
|---|---|
| 5 capítulos jogáveis (21 salas, objetivos, puzzles, documentos, memórias) | **Concluído** e percorrido de ponta a ponta por teste automatizado |
| 4 finais (Liberdade, Silêncio, Herdeiro, As Coisas Perdidas — secreto) | **Concluído**; condições em `docs/ENDINGS.md`, alcançabilidade testada |
| IA da Cuidadora (Patrol/Suspicious/Investigate/Search/Chase/Attack/Return) | **Concluído** e testado |
| IA do Morador (zonas, aviso de 3 s, surgimento justo, reação à luz, bloqueio/atração) | **Concluído** e testado |
| Salvamento versionado (user://), checkpoints, configurações | **Concluído** e testado |
| Menu, pausa, inventário, diário, puzzles, acessibilidade | **Concluído** |
| Arte procedural (personagens, tiles, props) e áudio sintetizado | **Concluído (nível protótipo avançado)**; não é arte final de estúdio |
| Pipeline GitHub Actions (Windows) + Release | **Configurado**; veja a seção "Build" e o histórico de Actions |
| Testado em Windows real (execução do EXE exportado) | Apenas pelo smoke test na CI do GitHub (runner Windows). Nenhum teste manual com jogador humano foi feito. |

Limitações conhecidas: ver `docs/TEST_PLAN.md` (seção "Limitações").

## Controles

| Tecla | Ação |
|---|---|
| WASD / Setas | mover (8 direções) |
| Shift | correr (mais ruído) |
| E | interagir / confirmar |
| F | lanterna (bateria limitada) |
| Tab | inventário |
| J | diário (documentos, memórias, objetivo) |
| Esc | pausa / voltar |

## Abrir no editor

1. Instale o **Godot 4.4.1 estável** (https://godotengine.org/download/archive/4.4.1-stable/).
2. Abra `project.godot`. Cena principal: `scenes/main/Main.tscn`. Renderer: Compatibility (OpenGL).
3. As ações de entrada são registradas por código em `SettingsManager` (não aparecem no mapa de entradas do editor).

## Executar localmente

```bash
godot --path .                       # joga
godot --headless --path . res://tests/TestRunner.tscn   # roda todos os testes
godot --headless --path . res://tests/TestRunner.tscn -- --suite=walkthrough   # uma suíte
```

## Estrutura

```
project.godot  export_presets.cfg  icon.svg
scenes/        Main, Game, MainMenu (cenas finas; a UI e as salas são montadas por código)
scripts/autoload/  GameManager, SaveManager, AudioManager, SceneManager, NarrativeManager,
                   InventoryManager, SettingsManager, LocalizationManager
scripts/world/     Game, Room, RoomNav (A*), Interactable, EffectRunner
scripts/player/    Player          scripts/enemies/  Caretaker, Resident
scripts/systems/   PixelArt, TileArt (arte procedural)
scripts/ui/        HUD, diálogo, puzzles, livro (inventário/diário), memórias/cutscenes, pausa, menu, config
data/              items, documents, dialogue (memórias/cutscenes/escolhas), puzzles, chapters (5 JSON)
tests/             7 suítes automatizadas + roteiro de QA
docs/              GDD, TECHNICAL_DESIGN, NARRATIVE_BIBLE, ENDINGS, ASSET_LICENSES, TEST_PLAN
tools/             capturas de tela (ShotRunner)
.github/workflows/windows-portable.yml
```

## Build Windows portable e Release

O workflow `Windows Portable` roda em `windows-latest`: baixa o Godot 4.4.1 e os export templates da fonte oficial (SHA-512 verificado), importa, roda os testes, exporta (`Orfanato.exe` com PCK embutido), monta o ZIP portable, executa um smoke test do EXE e publica o artefato. Em tags `v*` cria a GitHub Release com o ZIP e o checksum SHA-256.

- Manual: *Actions → Windows Portable → Run workflow*.
- Release: `git tag v0.9.0 && git push origin v0.9.0`.

## Licença

Código: MIT (`LICENSE`). Conteúdo (texto, arte e áudio procedurais): criado originalmente para este projeto.
