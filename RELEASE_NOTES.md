## O Orfanato das Coisas Perdidas v1.1.0 — release portátil para Windows

**Como jogar:** baixe o ZIP, extraia tudo numa pasta e execute `Orfanato.exe`. Não precisa instalar nada.

**Requisitos:** Windows 10/11 64-bit, GPU com OpenGL 3.3, ~200 MB livres.

**Novidades da v1.1.0**
- Morte sem perder progresso (retorno a um ponto seguro); puzzles nunca ficam trancados por cancelar/errar; documentos e gravações podem ser relidos sempre.
- Puzzles mais difíceis, com pistas espalhadas por salas e capítulos diferentes (dedutíveis).
- **Estamina**, **ferimentos** e **kits médicos**; armadilhas sinalizadas.
- **Morador**: cria buracos permanentes ao fugir, que tornam a casa mais perigosa; retorna sempre com aviso.
- Visual mais rico: pisos por cômodo, paredes deterioradas, crescimento orgânico, props detalhados, sprites melhores, sombras da lanterna.
- História expandida (origem do Projeto Lázaro, Clara, Marta, o Morador, por que o orfanato continua) e transições entre capítulos.
- **Remapeamento de teclas**.
- Saves antigos (v1) são migrados automaticamente.

**Conteúdo geral**
- 5 capítulos jogáveis e conectados (21 salas), com puzzles, documentos, memórias e escolhas persistentes.
- 4 finais (um deles secreto), com condições baseadas em exploração e escolhas.
- A Cuidadora (IA com 7 estados) e o Morador (surgimento justo com aviso).
- Salvamento em `%APPDATA%`, checkpoints automáticos, configurações de áudio/tela/acessibilidade.
- Arte e áudio 100% procedurais e originais.

**Verificação:** os testes automatizados (dados, geometria, sistemas, IA, finais, save/load e um roteiro que completa o jogo) rodam na CI antes do build; o EXE exportado passa por um smoke test no runner Windows.

**Limitações conhecidas**
- Arte procedural de nível protótipo avançado (não é arte final de estúdio).
- Não houve teste manual de jogabilidade por pessoas; o balanceamento é estimado por simulação.
- Sem gamepad; idioma apenas pt-BR. Android fica para uma etapa futura.

Controles padrão (remapeáveis): WASD/Setas mover · Shift correr · E interagir · F lanterna · Tab inventário · J diário · H kit médico · Esc pausa.
