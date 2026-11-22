## O Orfanato das Coisas Perdidas — release portátil para Windows

**Como jogar:** baixe o ZIP, extraia tudo numa pasta e execute `Orfanato.exe`. Não precisa instalar nada.

**Requisitos:** Windows 10/11 64-bit, GPU com OpenGL 3.3, ~200 MB livres.

**Conteúdo desta versão**
- 5 capítulos jogáveis e conectados (21 salas), com puzzles, documentos, memórias e escolhas persistentes.
- 4 finais (um deles secreto), com condições baseadas em exploração e escolhas.
- A Cuidadora (IA com 7 estados) e o Morador (surgimento justo com aviso).
- Salvamento em `%APPDATA%`, checkpoints automáticos, configurações de áudio/tela/acessibilidade.
- Arte e áudio 100% procedurais e originais.

**Verificação:** os testes automatizados (dados, geometria, sistemas, IA, finais, save/load e um roteiro que completa o jogo) rodam na CI antes do build; o EXE exportado passa por um smoke test no runner Windows.

**Limitações conhecidas**
- Arte procedural de nível protótipo avançado (não é arte final de estúdio).
- Não houve teste manual de jogabilidade por pessoas; o balanceamento é estimado por simulação.
- Sem gamepad nem remapeamento de teclas; idioma apenas pt-BR.

Controles: WASD/Setas mover · Shift correr · E interagir · F lanterna · Tab inventário · J diário · Esc pausa.
