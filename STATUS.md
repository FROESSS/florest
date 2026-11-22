# STATUS (atualizado a cada etapa)

Base: v1.0.0 publicada. Esta rodada: correção/expansão (prompt de aperfeiçoamento). Testes: `godot --headless --path . res://tests/TestRunner.tscn`.

## Etapas
- [x] E1 Diagnóstico (ver histórico da conversa)
- [x] E2 Fundamentos: estados de puzzle, documentos reabríveis/inspeção, morte com retorno seguro (Recovery), save v2 (+migração v1). Testes: `tests/suite_e2.gd`
- [ ] E3 Sobrevivência (estamina, ferimentos, kits)
- [ ] E4 Morador (buracos persistentes)
- [ ] E5 Visual
- [ ] E6 Narrativa e transições
- [ ] E7 Remapeamento de teclas
- [ ] E8 Validação e release

## Decisões técnicas
- Morte NÃO recarrega save: preserva progresso e reposiciona Elias em ponto de recuperação (≥150 px de inimigos, ≥130 px de aberturas do Morador) — `scripts/systems/recovery.gd`; `recovery` por sala em JSON quando os spawns não bastam.
- `once` só vale para itens/baterias/escolhas; documentos, memórias e puzzles nunca são de uso único. Puzzle: `not_started→in_progress→solved|blocked`; `on_solved` roda uma vez, depois `repeat` (ou "Já resolvi isso.").
- Escolhas únicas guardam o índice em `choice_<id>` (pode ser 0: usar `flags.has`, não `has_flag`); `repeatable:true` permite reperguntar.
- Save v2: `puzzles`, `attempts`, `world`, `player`. `_migrate` converte v1.

## Problemas conhecidos
- Nenhum teste manual com jogador humano; áudio não ouvido.

## Próxima tarefa
E3: estamina, ferimentos, kits médicos.
