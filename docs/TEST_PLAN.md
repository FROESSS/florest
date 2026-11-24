# Plano de testes

## Automatizados (`godot --headless --path . res://tests/TestRunner.tscn`)
| Suíte | O que verifica |
|---|---|
| `data` | JSON válido; 5 capítulos; todas as referências (itens, documentos, memórias, puzzles, escolhas, portas/spawns, cutscenes, finais) existem |
| `geometry` | Todas as 21 salas constroem; spawns livres e alcançáveis; todo objeto interativo e esconderijo é alcançável (com/sem barreiras); saída de esconderijo livre; patrulhas e aberturas válidas |
| `systems` | Inventário sem duplicação; flags/condições; **UI real de todos os puzzles** (resposta certa/errada); movimento 8 direções, diagonal normalizada, corrida > caminhada; colisões; ruído andar < correr; lanterna/bateria; esconderijo; interação real (lanterna, porta trancada/aberta) |
| `ai` | Cuidadora: patrulha, ruído→Suspicious→Investigate→Search→Return→Patrol, visão (cone, alcance, parede), awareness→Chase, captura, perda justa do alvo, regras de esconderijo (viu/não viu); Morador: aviso antes do surgimento, nunca < 130 px, mais lento que andar, reação à luz, bloqueio/atração por ruído |
| `endings` | Tabela de condições dos 4 finais e consequências (docs/ENDINGS.md) |
| `save` | Ida e volta, tipos, backup, corrompido, versão futura, validação, itens desconhecidos, configurações |
| `e2` | Estados de puzzle (cancelar/errar/sair e voltar/resolvido/bloqueado), releitura de documentos e inspeção, morte sem perder progresso, ponto de retorno seguro em todas as salas, save v2 e migração v1 |
| `e3` | Estamina (consumo, exaustão, recuperação, ritmo sob perigo), ferimentos 0–3, kits, cura natural, golpes do Morador, armadilhas, persistência, distribuição de kits |
| `e4` | Buracos do Morador: regras de criação (sem duplicar, espaçamento, limite 8/24, sem cortar rotas), persistência/save, ciclo fuga→cavar→retorno justo, acúmulo, luz sustentada |
| `e5` | Acabamento visual: paleta/variação das 21 texturas de sala, ausência de props genéricos, 6 quadros de caminhada/corrida, silhuetas distintas |
| `e6` | Pistas distribuídas e dedutíveis de cada puzzle, nenhum documento/memória órfão, revelação gradual da história, transições de capítulo (dados, reprodução real e autosave) |
| `e7` | Remapeamento: InputMap, conflitos, troca, Esc reservada, alternativas, persistência e configuração corrompida, UI de controles, jogabilidade com teclas novas |
| `walkthrough` | Joga os 5 capítulos de ponta a ponta (6 variantes) com as interações reais, confirma portas trancadas, progresso, 10 memórias e que **os 4 finais** são alcançáveis |

A CI (`windows-portable.yml`) roda essas suítes em Windows antes de exportar, e faz um *smoke test* do EXE exportado.

## Roteiro manual (para quem for jogar)
1. Novo jogo → mover/colidir → pegar lanterna → ligar/desligar (F) → Tab/J.
2. Esconder-se (armário) com a Cuidadora longe; com ela te vendo entrar (deve capturar).
3. Cap. I completo: desenhos → caixa de música (3142) → secretaria → fuga pelo salão.
4. Salvar (Esc) em slot; sair; Carregar; Continuar.
5. Configurações: volumes, tela cheia, escala, legendas, reduções de flashes/tremor/distorção.
6. Cap. II–V conforme `docs/NARRATIVE_BIBLE.md`; checar os 4 finais conforme `docs/ENDINGS.md`.

## Walkthrough interno (códigos e rotas)
Caixa de música `3142` · alçapão `271` (diário de Lia + legendas das escadas) · terminal `0712` (memorando, na cirurgia) · cofre `1403` (carta de inauguração, cap. I) · fusíveis: só os de número par (2 e 4) · brinquedos urso→trem→boneca→bola (lembrança + diário de Marta) · válvulas 3→1→2 (manual no reator) · prontuários na ordem do livro de matrícula (L-01, L-04, L-07, L-11).

## Limitações conhecidas
- Remapeamento cobre teclado (sem gamepad).
- Nenhum teste manual com jogadores humanos; balanceamento (bateria, velocidades, tempos) foi calibrado por simulação.
- Arte/áudio procedurais (nível protótipo avançado).
- Inimigos não persistem entre salas; sem gamepad; sem remapeamento; só pt-BR.
- Em CI/headless não há renderização nem áudio real: a aparência foi conferida por capturas locais (xvfb/OpenGL), o som não foi ouvido por humano.
