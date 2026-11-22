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
Caixa de música `3142` · alçapão `271` · terminal `0712` · cofre `1403` · fusíveis A✗ B✓ C✓ D✗ · brinquedos urso→trem→boneca→bola · válvulas 3→1→2 · prontuários 14/03 → 02/05 → 19/08 → 30/11.

## Limitações conhecidas
- Nenhum teste manual com jogadores humanos; balanceamento (bateria, velocidades, tempos) foi calibrado por simulação.
- Arte/áudio procedurais (nível protótipo avançado).
- Inimigos não persistem entre salas; sem gamepad; sem remapeamento; só pt-BR.
- Em CI/headless não há renderização nem áudio real: a aparência foi conferida por capturas locais (xvfb/OpenGL), o som não foi ouvido por humano.
