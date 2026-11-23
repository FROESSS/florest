# STATUS (atualizado a cada etapa)

Base: v1.0.0 publicada. Esta rodada: correção/expansão (prompt de aperfeiçoamento). Testes: `godot --headless --path . res://tests/TestRunner.tscn`.

## Etapas
- [x] E1 Diagnóstico (ver histórico da conversa)
- [x] E2 Fundamentos: estados de puzzle, documentos reabríveis/inspeção, morte com retorno seguro (Recovery), save v2 (+migração v1). Testes: `tests/suite_e2.gd`
- [x] E3 Sobrevivência: estamina (18/s, exaustão, regen lenta sob perigo), ferimentos 0–3 (golpe do Morador fere; só ferimento grave + golpe = morte), kits pequeno/grande (H ou inventário), armadilhas sinalizadas, cura natural, 20 kits distribuídos. Testes: `tests/suite_e3.gd`
- [x] E4 Morador: buracos persistentes (cap 8/sala, 24 total, sem duplicar, sem cortar rotas), fuga por luz sustentada/golpe/tempo/zona/escondido, cava a cada 2ª fuga, retorno ≥18 s e ≥130 px com abertura sinalizada, intervalo encurta com mais buracos, save/load. Testes: `tests/suite_e4.gd`
- [x] E5 Visual: zonas de piso (tabuleiro/carpete/concreto), deterioração e rachaduras nas paredes, vigas/canos, teias, crescimento orgânico (tentáculos/veias) por sala, objetos soltos, props com sujeira/ferrugem e novos (mesa redonda, balcão, fogão, planta, buraco, armadilha, kit), sprites com rosto/sombreamento e caminhada/corrida de 6 quadros, Morador com mais detalhes + animação de afundar, lanterna com sombras (oclusores) e poeira. Referência de atmosfera: imagem enviada (sem copiar assets). Testes: `tests/suite_e5.gd`
- [ ] E6 Narrativa e transições
- [ ] E7 Remapeamento de teclas
- [ ] E8 Validação e release

## Decisões técnicas
- Morte NÃO recarrega save: preserva progresso e reposiciona Elias em ponto de recuperação (≥150 px de inimigos, ≥130 px de aberturas do Morador) — `scripts/systems/recovery.gd`; `recovery` por sala em JSON quando os spawns não bastam.
- `once` só vale para itens/baterias/escolhas; documentos, memórias e puzzles nunca são de uso único. Puzzle: `not_started→in_progress→solved|blocked`; `on_solved` roda uma vez, depois `repeat` (ou "Já resolvi isso.").
- Escolhas únicas guardam o índice em `choice_<id>` (pode ser 0: usar `flags.has`, não `has_flag`); `repeatable:true` permite reperguntar.
- Save v2: `puzzles`, `attempts`, `world`, `player`. `_migrate` converte v1.

- Tempo simulado em testes: com `Engine.time_scale=N`, delta físico = N/60 (não usar `get_physics_frames()/60` sem multiplicar).

## Problemas conhecidos
- Nenhum teste manual com jogador humano; áudio não ouvido.

## Próxima tarefa
E6: narrativa (proposta de conexão → documentos/gravações/memórias) e transições de capítulo.
