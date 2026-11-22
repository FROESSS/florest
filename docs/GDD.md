# O ORFANATO DAS COISAS PERDIDAS
## Game Design Document (GDD) — Versão 1.0

**Tipo:** Documento de design de jogo  
**Gênero:** Survival horror, horror psicológico, body horror e investigação  
**Formato:** Jogo single-player 2D  
**Engine recomendada:** Godot 4.x  
**Linguagem:** GDScript  
**Plataforma-alvo inicial:** Windows 10/11 — 64 bits  
**Resolução-base:** 640 × 360, com escala inteira quando possível  
**Perspectiva:** Top-down 2D com cenários de profundidade e composição cinematográfica  
**Estado:** Documento de referência para pré-produção e desenvolvimento

---

# 1. Visão do produto

## 1.1 High concept

O jogador controla Elias, uma criança de 12 anos que desperta em um orfanato isolado, aparentemente abandonado. O local foi usado secretamente por uma organização científica que conduziu experimentos em crianças para estudar memória, consciência e preservação de identidade.

Os experimentos produziram consequências biológicas e neurológicas extremas. A estrutura subterrânea foi contaminada por um sistema orgânico experimental que reage a estímulos e fragmentos de memória. Anos depois, Elias acorda no edifício sem saber como chegou ali — e algumas criaturas parecem reconhecê-lo.

O objetivo é sobreviver, investigar a instituição, compreender o Projeto Lázaro e decidir o destino do que restou dele.

## 1.2 Fantasia do jogador

Sentir-se vulnerável em um lugar que deveria ser seguro, investigar uma tragédia escondida e perceber que o próprio ambiente reage à presença do protagonista. O jogador deve alternar entre exploração cuidadosa, resolução de enigmas, furtividade e fugas intensas.

## 1.3 Pilares de design

1. **Infância corrompida:** quartos, brinquedos e desenhos infantis contrastam com violência e deformação.
2. **Ciência sem limites:** o horror deriva de decisões humanas e experimentos antiéticos.
3. **Memória e identidade:** lembranças podem ser incompletas, manipuladas ou contraditórias.
4. **Ambiente narrativo:** cenários e objetos contam a história sem depender de longas exposições.
5. **Vulnerabilidade e consequência:** Elias não é um combatente; escolhas e recursos limitados importam.
6. **Terror intenso, legível e justo:** ameaças fortes, mas com sinais audiovisuais e oportunidades compreensíveis de reação.

## 1.4 Referência estética

A direção visual busca pixel art sombria, detalhada e atmosférica, com perspectiva top-down, iluminação localizada, cenários decadentes e criaturas grotescas. A referência fornecida pelo usuário é uma inspiração de atmosfera e composição, não um material a ser copiado.

**Não copiar** sprites, personagens, mapas, músicas, interface, código ou assets de Decarnation ou de qualquer outro jogo. Todo conteúdo final deve ser original, licenciado adequadamente ou criado por ferramentas/procedimentos próprios.

---

# 2. Público, experiência e escopo

## 2.1 Público-alvo

Jogadores que apreciam jogos independentes de terror narrativo, exploração, puzzles, perseguições, horror corporal e finais condicionados por escolhas.

## 2.2 Duração pretendida

- Protótipo: 5–10 minutos.
- Vertical slice: 20–35 minutos.
- Versão completa inicial: alvo de 2–4 horas, sujeito a testes e produção de conteúdo.

Esses valores são metas, não promessas. Não prolongar o jogo artificialmente com corredores vazios ou repetição.

## 2.3 Escopo de produção

O projeto deve ser desenvolvido em etapas verificáveis:

- **Etapa A — Fundação:** projeto Godot, configurações, cenas-base, controles, câmera e colisões.
- **Etapa B — Protótipo:** uma sala, corredor, interação, lanterna, esconderijo e inimigo funcional.
- **Etapa C — Vertical slice:** trecho jogável do Capítulo I com arte, áudio, puzzle e perseguição.
- **Etapa D — Produção:** capítulos, personagens, sistemas narrativos e conteúdo.
- **Etapa E — Polimento:** acessibilidade, balanceamento, otimização, testes e exportação.
- **Etapa F — Distribuição:** pacote portable Windows, GitHub Actions e GitHub Release.

Não declarar o jogo completo enquanto existirem capítulos essenciais ausentes, sistemas centrais simulados ou erros impeditivos.

---

# 3. Universo e narrativa

## 3.1 Premissa

Em 1978, uma instituição privada financiou um orfanato em uma região isolada. Oficialmente, o estabelecimento acolhia crianças sem família e oferecia assistência médica e educação. Secretamente, um laboratório subterrâneo conduzia o Projeto Lázaro.

O projeto buscava registrar, reproduzir e preservar fragmentos da memória humana por meio de procedimentos neurológicos e de um tecido biológico experimental. Crianças foram submetidas a testes inicialmente descritos como avaliações cognitivas. Os procedimentos tornaram-se invasivos e antiéticos.

Algumas crianças passaram a relatar lembranças de acontecimentos que nunca viveram. Outras reproduziam hábitos e falas de pessoas mortas. Alterações físicas e comportamentais surgiram. A equipe perdeu o controle da instalação. O laboratório foi fechado, registros foram destruídos e o orfanato foi declarado desativado.

O sistema biológico permaneceu ativo.

Anos depois, Elias desperta no local.

## 3.2 O Projeto Lázaro

O Projeto Lázaro é uma iniciativa científica humana e fictícia. Seu objetivo era estudar se memórias e padrões de consciência poderiam ser preservados e reproduzidos.

Os experimentos produziram um tecido orgânico experimental que absorve estímulos neurológicos e reproduz fragmentos de experiências. O tecido espalhou-se por áreas da instalação e passou a reagir a pessoas, sons, estímulos e padrões de memória.

Isso explica parte dos fenômenos:
- corredores e salas que parecem se reorganizar;
- vozes e sons de crianças desaparecidas;
- ambientes que reproduzem fragmentos de acontecimentos;
- criaturas com características humanas;
- reações do ambiente à presença de Elias.

A explicação científica deve ser sugerida progressivamente. Não explicar tudo de uma só vez. Alguns fenômenos podem permanecer ambíguos, sem transformar o universo em fantasia sobrenatural genérica.

## 3.3 Tom narrativo

- Terror intenso desde o início.
- Ameaças e situações perturbadoras aparecem cedo.
- O mistério se aprofunda conforme o jogador explora.
- Alternar tensão, perseguições, investigação e breves momentos de respiro.
- Evitar gore gratuito: cada imagem perturbadora deve servir ao tema, à narrativa ou à mecânica.
- Não usar sustos repentinos como único recurso.

## 3.4 Estrutura em cinco capítulos

### Capítulo I — O Despertar
Elias acorda em um quarto infantil. Há objetos espalhados, marcas nas paredes e sinais de que alguém esteve ali recentemente. O jogador aprende movimento, interação, inspeção, lanterna e esconderijo. O capítulo termina com o primeiro encontro completo com A Cuidadora e uma fuga.

Objetivos:
- Encontrar a chave ou mecanismo de saída.
- Investigar o quarto e os primeiros corredores.
- Aprender a esconder-se.
- Encontrar uma fotografia antiga.
- Sobreviver à perseguição.

### Capítulo II — Os Pequenos Habitantes
Elias encontra Clara e registros de outras crianças. Desenhos infantis contêm símbolos que apontam para setores subterrâneos. O jogador passa a distinguir pistas confiáveis de manifestações possivelmente alteradas.

Objetivos:
- Encontrar registros de desaparecimentos.
- Conhecer manifestações de outras crianças.
- Resolver enigmas ambientais.
- Descobrir uma passagem para o subsolo.

### Capítulo III — A Casa Respira
A estrutura apresenta alterações intensas. Tecidos orgânicos bloqueiam caminhos e salas reproduzem memórias. O Morador torna-se uma ameaça central.

Objetivos:
- Sobreviver ao Morador.
- Atravessar áreas contaminadas.
- Investigar a origem das alterações.
- Descobrir pistas sobre A Cuidadora.

### Capítulo IV — O Que Existe Debaixo
Elias chega ao laboratório. Documentos revelam o Projeto Lázaro e os experimentos. O jogador encontra registros relacionados ao protagonista e toma decisões que afetarão os personagens e os finais.

Objetivos:
- Investigar arquivos científicos.
- Entender o propósito do projeto.
- Encontrar registros de Elias.
- Decidir o destino de informações e equipamentos.

### Capítulo V — A Última Criança
Elias descobre sua ligação com o Projeto Lázaro. O laboratório está em colapso. Clara revela informações que reinterpretam a jornada. O jogador decide o destino do sistema.

Objetivos:
- Alcançar a área central.
- Confrontar a verdade sobre Clara e Elias.
- Tomar a decisão final.
- Desbloquear um dos desfechos conforme ações anteriores.

---

# 4. Personagens

## 4.1 Elias — protagonista

- Idade: 12 anos.
- Aparência: cabelos escuros, roupas simples; camiseta azul sem mangas como referência inicial de design.
- Personalidade: observador, desconfiado e inteligente.
- Função: personagem jogável.
- Objetivo aparente: encontrar uma saída.
- Mistério: sua presença no local não é coincidência; algumas criaturas reagem a ele de forma diferente.

Elias não é um combatente. Seu conjunto de ações prioriza movimento, observação, interação, esconderijo e uso contextual de objetos.

## 4.2 Clara

- Idade aparente: 10 anos.
- Aparência: vestido claro e cabelos escuros.
- Personalidade: silenciosa, inteligente e misteriosa.
- Função: personagem secundária e elo narrativo.
- Objetivo aparente: ajudar Elias a escapar.
- Segredo: sua identidade e relação com o Projeto Lázaro devem ser reveladas no decorrer da campanha.

Clara não deve ser usada apenas como exposição ambulante. Ela precisa ter motivações, ações e contradições próprias.

## 4.3 A Cuidadora

- Antagonista recorrente.
- Figura feminina alta, deformada, com movimentos anormais.
- Patrulha corredores, investiga ruídos e procura crianças escondidas.
- Origem ligada aos primeiros experimentos do Projeto Lázaro.
- Deve possuir linguagem corporal e áudio reconhecíveis.

## 4.4 O Morador

- Criatura principal das áreas contaminadas.
- Massa orgânica de proporções humanas e deformações extremas.
- Utiliza aberturas, estruturas e passagens orgânicas.
- Não deve perseguir o jogador continuamente.
- Sua presença é anunciada por ruídos, vibrações, alterações no ambiente e sinais visuais.

## 4.5 Crianças perdidas

Manifestações e personagens secundários. Algumas ajudam; outras atraem Elias para perigos. Evitar que todas sejam hostis. Suas histórias devem aparecer em desenhos, objetos, gravações e breves encontros.

---

# 5. Cenários e mapa

## 5.1 Macroáreas

1. Quartos infantis.
2. Corredores e escadarias.
3. Refeitório.
4. Sala de recreação e enfermaria.
5. Administração e arquivos.
6. Depósitos e lavanderia.
7. Subsolo técnico.
8. Laboratório do Projeto Lázaro.
9. Núcleo biológico.
10. Área final.

## 5.2 Regras de level design

- Cada sala deve ter função narrativa, mecânica ou ambas.
- Criar marcos visuais para orientar o jogador.
- Evitar labirintos sem pistas.
- Permitir atalhos após exploração, quando apropriado.
- Usar bloqueios visuais e portas para controlar revelações.
- Criar rotas alternativas de furtividade quando viável.
- Toda área obrigatória deve ser legível e navegável.
- Objetos importantes devem se destacar por composição, contraste ou iluminação, sem depender apenas de cor.
- Perseguições devem possuir percurso testado, pontos de leitura e condições claras de sucesso/falha.

## 5.3 Layout de referência

O mapa definitivo deve ser criado como grafo de salas e conexões. Não inventar uma planta incoerente apenas para preencher conteúdo.

Estrutura de alto nível:
- Ala residencial: quartos, recreação, refeitório e enfermaria.
- Ala administrativa: escritórios, arquivos e sala da direção.
- Núcleo de serviço: lavanderia, depósitos, caldeiras e escadaria de acesso.
- Subsolo: recepção técnica, laboratórios, câmaras de observação e núcleo experimental.

As conexões exatas devem ser documentadas em mapa próprio durante a produção.

---

# 6. Loop principal de gameplay

1. Explorar uma área.
2. Observar o ambiente e identificar pistas.
3. Coletar objetos ou documentos.
4. Resolver um obstáculo ou puzzle.
5. Detectar uma ameaça.
6. Escolher entre esconder-se, desviar-se ou fugir.
7. Desbloquear uma nova área ou memória.
8. Registrar consequências narrativas.

O jogador deve alternar entre investigação e sobrevivência. Não criar combate convencional como sistema central.

---

# 7. Controles

Configuração inicial para teclado e mouse:

| Ação | Tecla |
|---|---|
| Mover | WASD / setas |
| Interagir / confirmar | E |
| Correr | Shift |
| Lanterna | F |
| Inventário | Tab |
| Diário / documentos | J |
| Pausar | Esc |
| Cancelar / voltar | Esc / botão direito |

Requisitos:
- Controles remapeáveis, se possível dentro do escopo.
- Exibir os controles na primeira inicialização e no menu de pausa.
- Permitir avançar diálogos e ler documentos sem pressão de tempo, exceto em sequências explicitamente perigosas.
- Não depender de mouse para ações essenciais.

---

# 8. Sistemas de jogo

## 8.1 Movimento e colisão

- Movimento 8 direções com normalização diagonal.
- Colisões consistentes com paredes, móveis e obstáculos.
- Velocidade de caminhada e corrida configuráveis.
- Animações alinhadas à direção do movimento.
- Pequena aceleração/desaceleração apenas se não prejudicar precisão.
- Sem atravessar paredes ou ficar preso em colisores.

## 8.2 Interação

Objetos interativos devem apresentar indicação visual discreta quando Elias estiver no alcance.

Tipos:
- examinar;
- coletar;
- abrir/fechar;
- ativar;
- inserir item;
- ler documento;
- iniciar memória;
- esconder-se.

A interação deve ser contextual e consistente. Exibir mensagens curtas e claras.

## 8.3 Inventário

- Inventário limitado e legível.
- Itens-chave podem permanecer no inventário sem ocupar espaço, se isso melhorar o fluxo.
- Mostrar nome, ícone original e descrição.
- Itens consumíveis devem ter uso explícito.
- Não permitir duplicação indevida ou perda de item obrigatório.
- Salvar o estado do inventário.

## 8.4 Lanterna

- Cone ou área de iluminação ajustada à direção do personagem.
- Bateria limitada, mas balanceada para não tornar a exploração frustrante.
- Indicação de carga restante.
- Algumas criaturas podem reagir à luz.
- O jogador deve poder desligar a lanterna.
- Não esconder pistas obrigatórias em áreas impossíveis de visualizar.

## 8.5 Furtividade e esconderijos

- Esconderijos: armários, camas, móveis e locais definidos no mapa.
- Entrar/sair por interação.
- Inimigos investigam ruídos e última posição conhecida.
- Não tornar o jogador invulnerável em todo esconderijo: regras devem depender do tipo de ameaça e ser comunicadas.
- A saída do esconderijo deve ser confiável e não causar colisões.

## 8.6 Audição e ruído

Ações produzem níveis de ruído:
- caminhar: baixo;
- correr: alto;
- derrubar objetos: alto;
- abrir mecanismos pesados: variável.

A IA deve investigar a posição aproximada do ruído, sem telepatia ou conhecimento permanente da posição do jogador.

## 8.7 IA inimiga

Implementar IA baseada em estados, com transições explícitas:

- Idle/Patrol;
- Suspicious;
- Investigate;
- Search;
- Chase;
- Attack/Capture;
- Return.

A Cuidadora:
- patrulha pontos configurados;
- percebe o jogador por visão e/ou ruído;
- investiga a última posição conhecida;
- inicia perseguição quando detecta claramente Elias;
- perde o alvo após condições razoáveis;
- retorna à patrulha;
- possui sinais sonoros e visuais de cada estado.

O Morador:
- controla zonas contaminadas;
- emerge em locais definidos ou por condições de gameplay;
- pode bloquear caminhos;
- usa avisos audiovisuais antes de ataques;
- não deve surgir de forma injusta diretamente sobre o jogador.

A IA deve ser testável e configurável por parâmetros. Evitar lógica monolítica.

## 8.8 Sistema de memória

Objetos específicos ativam fragmentos jogáveis ou cenas curtas. Cada memória:
- tem gatilho identificável;
- possui duração controlada;
- apresenta imagem/áudio distintos;
- fornece pista narrativa;
- pode registrar descoberta;
- não deve bloquear o jogador permanentemente;
- pode alterar flags de história.

Memórias podem ser incompletas ou contraditórias. A contradição deve ser intencional e posteriormente contextualizada.

## 8.9 Escolhas e flags

Manter um sistema centralizado de variáveis narrativas. Exemplos:
- `helped_child_x`;
- `kept_laboratory_record`;
- `destroyed_equipment`;
- `trusted_clara`;
- `collected_memory_fragments`.

Não usar nomes genéricos sem documentação. Cada escolha deve ter:
- identificador único;
- momento de ativação;
- consequência imediata ou futura;
- condição de persistência;
- efeito sobre final, diálogo, personagem ou acesso.

## 8.10 Salvamento

- Autosave em pontos seguros e checkpoints.
- Salvamento manual em locais designados, se adequado.
- Salvar capítulo, sala, posição segura, inventário, flags, puzzles, documentos, memória e estado necessário.
- Dados em formato versionado.
- Validar dados ao carregar e fornecer recuperação segura caso o save esteja corrompido.
- Não salvar posição dentro de parede, área de perseguição inválida ou estado transitório de animação.

---

# 9. Puzzles e investigação

## 9.1 Princípios

- Puzzles devem fazer sentido no contexto do orfanato e do laboratório.
- Pistas devem existir no cenário, documentos ou diálogos.
- Evitar soluções que dependam de tentativa aleatória.
- Oferecer feedback de erro e progresso.
- Não exigir pixel hunting extremo.
- Não permitir bloqueio permanente por consumo acidental de item essencial.

## 9.2 Exemplos de puzzles

1. **Desenhos infantis:** combinar símbolos de desenhos com números de quartos.
2. **Arquivo de prontuários:** reconstruir a ordem de registros por datas e códigos.
3. **Painel de energia:** religar circuitos seguindo pistas de cor, símbolo e ruído.
4. **Sala de brinquedos:** posicionar objetos conforme uma memória encontrada.
5. **Acesso ao laboratório:** localizar três componentes e ativar um mecanismo.

As soluções definitivas devem ser documentadas em uma seção de walkthrough interno para testes, não expostas ao jogador.

## 9.3 Documentos

Tipos:
- prontuários;
- relatórios de pesquisa;
- cartas de funcionários;
- desenhos;
- fotografias;
- gravações;
- notas de manutenção.

Cada documento deve acrescentar informação, contradizer uma hipótese ou orientar uma ação. Evitar textos longos sem valor de gameplay.

---

# 10. Finais

O jogo possui quatro finais planejados. Os gatilhos definitivos devem ser implementados por flags acumuladas, pistas e decisões, não apenas por uma escolha no último minuto.

## Final 1 — A Liberdade
Elias escapa e encontra ajuda. Documentos sobre o orfanato foram apagados. Uma pessoa desconhecida observa Elias de dentro de um veículo, sugerindo que o projeto pode ter sobrevivido.

## Final 2 — O Silêncio
Elias destrói o laboratório. Os experimentos são interrompidos, mas as memórias preservadas não podem ser recuperadas. A instituição desaba em um incêndio.

## Final 3 — O Herdeiro
Elias escolhe preservar o sistema. A última cena mostra o protagonista diante da sala de controle enquanto vozes infantis começam a chamá-lo.

## Final 4 — As Coisas Perdidas (secreto)
Elias descobre a verdade sobre Clara, as crianças e a finalidade do sistema. Acessa o arquivo completo do Projeto Lázaro e encontra memórias atribuídas a pessoas que morreram antes da inauguração. A cena final deixa em aberto se Elias esteve fisicamente no orfanato ou se revive uma memória implantada.

O final secreto exige exploração cuidadosa e coleta de evidências distribuídas ao longo dos capítulos.

---

# 11. Direção de arte

## 11.1 Estilo

- Pixel art original, detalhada e legível.
- Perspectiva top-down.
- Cenários com profundidade, oclusão e composição cinematográfica.
- Sprites consistentes em escala e proporção.
- Animações quadro a quadro quando possível.
- Paleta limitada por ambiente.
- Evitar filtro que borre ou destrua a nitidez dos pixels.

## 11.2 Paleta

| Ambiente | Cores |
|---|---|
| Orfanato | verde-musgo, cinza, marrom |
| Quartos | azul desbotado, bege, cinza |
| Laboratório | branco envelhecido, cinza, vermelho de alerta |
| Áreas contaminadas | vermelho escuro, rosa orgânico, preto |
| Memórias | tons dessaturados e luz diferenciada |

## 11.3 Requisitos de arte

- Tileset modular.
- Spritesheets com tamanho de célula consistente.
- Animações de idle, walk, run, interact, hide e hit/capture.
- Variações direcionais quando necessárias.
- Criaturas com silhuetas reconhecíveis.
- Objetos interativos distinguíveis sem parecerem elementos de interface.
- Cenários com detalhes narrativos.

Se não houver assets originais disponíveis, criar arte original por pixel art programática ou ferramentas de desenho. Não utilizar imagens genéricas como substitutos permanentes. Não apresentar arte provisória como arte final. Manter registro das licenças de assets de terceiros.

---

# 12. Iluminação, câmera e renderização

- Resolução interna de referência: 640×360.
- Escalonamento inteiro quando possível.
- Aspect ratio 16:9 com tratamento de barras ou escala adequada para telas diferentes.
- Câmera acompanha Elias suavemente, sem jitter.
- Limites de câmera por sala.
- Iluminação localizada e lanterna.
- Sombras somente se não comprometerem a performance ou a nitidez.
- Elementos essenciais continuam visíveis.
- Efeitos de tela usados com moderação: vinheta, ruído, distorção e transições.
- Opção para reduzir efeitos visuais que possam causar desconforto.

---

# 13. Áudio e música

## 13.1 Princípio

O silêncio é parte do design. Música contínua não deve mascarar os sinais de ameaça.

## 13.2 Camadas

- Ambiência: ventilação, tubulações, água, estalos e ruídos estruturais.
- Personagem: passos, respiração, interação e esforço.
- Criaturas: vocalizações, arrasto, impacto e respiração.
- Interface: confirmação, erro, coleta e menu.
- Música: temas pontuais, perseguições e cenas narrativas.
- Memórias: filtros abafados, reverberação e distorção.

## 13.3 Áudio espacial

- Usar posicionamento estéreo ou espacial quando aplicável.
- Direção aproximada de passos e criaturas.
- Distância afeta volume e filtragem.
- Não depender exclusivamente do áudio para informação essencial.
- Controles separados de volume para música, efeitos e ambiente.

---

# 14. Interface e experiência do usuário

## 14.1 Menu principal

Opções:
- Novo jogo;
- Continuar (quando existir save);
- Carregar jogo;
- Configurações;
- Créditos;
- Sair.

## 14.2 HUD

Minimalista:
- indicação contextual de interação;
- estado da lanterna/bateria;
- feedback de coleta;
- sem minimapa permanente, salvo decisão posterior de design.

## 14.3 Inventário e diário

- Inventário visual simples.
- Documentos legíveis.
- Diário com pistas e memórias encontradas.
- Separação entre itens, documentos e registros.
- Navegação por teclado e mouse.

## 14.4 Configurações

- Volume geral, música, efeitos e ambiente.
- Tela cheia/janela.
- Resolução ou escala quando suportada.
- Remapeamento de teclas, se viável.
- Opção de reduzir tremor, flashes e distorções.
- Idioma: português brasileiro como idioma inicial.
- Legendas e tamanho legível de texto.

## 14.5 Acessibilidade e clareza

- Não comunicar informações essenciais apenas por cor.
- Legendas para falas e sons narrativamente importantes.
- Ajuste de volume.
- Redução de flashes e tremores.
- Indicação visual de interação.
- Opção de pausar fora de sequências explicitamente não pausáveis, se houver justificativa.

---

# 15. Arquitetura técnica recomendada

## 15.1 Engine

Godot 4.x estável, usando GDScript. Fixar a versão utilizada no projeto e documentar o número exato. Não atualizar a engine no meio da produção sem testar o projeto.

## 15.2 Estrutura sugerida

```text
florest/
├── project.godot
├── README.md
├── LICENSE
├── docs/
│   ├── GDD.md
│   ├── TECHNICAL_DESIGN.md
│   ├── NARRATIVE_BIBLE.md
│   ├── ASSET_LICENSES.md
│   └── TEST_PLAN.md
├── scenes/
│   ├── main/
│   ├── player/
│   ├── enemies/
│   ├── rooms/
│   ├── interactables/
│   ├── ui/
│   └── cutscenes/
├── scripts/
│   ├── autoload/
│   ├── player/
│   ├── enemies/
│   ├── systems/
│   ├── narrative/
│   └── ui/
├── assets/
│   ├── sprites/
│   ├── tilesets/
│   ├── backgrounds/
│   ├── audio/
│   ├── fonts/
│   └── shaders/
├── data/
│   ├── dialogue/
│   ├── items/
│   ├── documents/
│   ├── puzzles/
│   └── chapters/
├── tests/
└── .github/
    └── workflows/
        └── windows-portable.yml
```

Adaptar a estrutura ao projeto real, sem criar diretórios vazios desnecessários.

## 15.3 Autoloads/serviços

Serviços sugeridos:
- `GameManager`: estado global e fluxo de jogo.
- `SaveManager`: persistência versionada.
- `AudioManager`: música, ambiente e efeitos.
- `SceneManager`: transições entre salas e capítulos.
- `NarrativeManager`: flags, escolhas e progressão.
- `InventoryManager`: inventário e itens.
- `SettingsManager`: configurações.
- `LocalizationManager`: textos e idioma.

Evitar concentrar toda a lógica em um único script. Usar sinais, recursos de dados e componentes reutilizáveis.

## 15.4 Dados

- Diálogos, itens, documentos, puzzles e flags devem ser dados estruturados quando adequado.
- Identificadores únicos e estáveis.
- Validação de referências.
- Separar lógica de apresentação.
- Evitar caminhos de arquivos frágeis.
- Nenhuma dependência de caminhos absolutos do computador do desenvolvedor.

## 15.5 Performance

- Meta de 60 FPS em hardware modesto compatível com Godot 4.
- Evitar excesso de luzes dinâmicas simultâneas.
- Usar atlas e tilesets.
- Carregar/descarregar cenas e recursos de maneira controlada.
- Evitar alocações desnecessárias em loops frequentes.
- Testar em resolução 1280×720 e 1920×1080.

---

# 16. Salvamento, configurações e dados do usuário

- Saves dentro do diretório de dados do usuário do sistema, não dentro da pasta de instalação.
- Configurações preservadas entre execuções.
- Save com versão de esquema.
- Backup simples antes de atualizar save incompatível.
- Não armazenar credenciais, tokens ou segredos no jogo.
- Não enviar telemetria ou dados pessoais.
- Não exigir conexão à internet para jogar.

---

# 17. Testes e critérios de aceitação

## 17.1 Testes funcionais

- Movimento em oito direções.
- Colisões.
- Interação.
- Inventário.
- Lanterna e bateria.
- Esconderijos.
- Percepção de inimigos.
- Estados de IA.
- Puzzles.
- Memórias.
- Flags narrativas.
- Salvamento e carregamento.
- Menu e configurações.
- Transições entre cenas.

## 17.2 Testes de regressão

Após cada alteração:
- iniciar o projeto;
- verificar erros de parse e recursos ausentes;
- testar a cena alterada;
- testar uma rota completa do capítulo atual;
- verificar se saves antigos continuam válidos ou são migrados;
- confirmar que controles e interface continuam funcionando.

## 17.3 Critérios de aceitação da vertical slice

A vertical slice só será aceita quando:
1. O jogador iniciar um novo jogo.
2. Elias puder caminhar e colidir corretamente.
3. A câmera funcionar.
4. Pelo menos três objetos puderem ser examinados/interagidos.
5. A lanterna funcionar.
6. Um esconderijo funcionar.
7. A Cuidadora patrulhar, investigar e perseguir.
8. O jogador puder escapar da perseguição por uma rota válida.
9. Um puzzle puder ser resolvido.
10. Uma memória puder ser encontrada e reproduzida.
11. O progresso puder ser salvo e carregado.
12. O trecho terminar com uma transição narrativa funcional.

## 17.4 Critérios de aceitação do jogo completo

- Cinco capítulos jogáveis e conectados.
- Personagens e criaturas com comportamentos implementados.
- Puzzles e documentos funcionais.
- Sistema de escolhas persistente.
- Quatro finais desbloqueáveis conforme regras documentadas.
- Menu, opções e salvamento.
- Sem bugs críticos conhecidos.
- Sem referências a assets ausentes.
- Sem telas de placeholder no fluxo final.
- Build portátil testado em Windows.

---

# 18. Distribuição: Windows Portable

## 18.1 Resultado esperado

Gerar um pacote ZIP contendo, no mínimo:

```text
O-Orfanato-das-Coisas-Perdidas-Windows-Portable/
├── Orfanato.exe
├── Orfanato.pck
├── README-PORTABLE.txt
└── (arquivos adicionais exigidos pela exportação)
```

O conteúdo exato depende do modo de exportação do Godot. Se a exportação incorporar os dados ao executável, não exigir um `.pck` separado. Incluir todas as DLLs e recursos necessários quando aplicável.

## 18.2 Regras do modo portable

- Não exigir instalação.
- Não exigir Godot instalado.
- Não exigir Python, Node.js ou ferramentas de desenvolvimento.
- Não depender de arquivos presentes apenas no computador do desenvolvedor.
- Não exigir internet para iniciar ou jogar.
- O usuário deve extrair o ZIP e executar o `.exe`.
- Salvar dados do usuário em pasta apropriada do Windows, separada dos arquivos de instalação.
- Incluir instruções de execução e requisitos mínimos.

## 18.3 GitHub Actions

Criar workflow que:
1. Rode em push de tag de versão e também manualmente.
2. Instale a versão fixada do Godot e os templates de exportação.
3. Importe recursos do projeto.
4. Execute verificações automatizadas disponíveis.
5. Exporte Windows x86_64.
6. Monte a pasta portable.
7. Gere ZIP.
8. Publique o ZIP como artefato do workflow.
9. Em tags de release, crie/atualize um GitHub Release e anexe o ZIP.
10. Falhe claramente se exportação ou validação falhar.

Não publicar um artefato vazio ou build que não foi gerado. Não afirmar que o executável foi testado em Windows real se apenas foi exportado em CI Linux.

## 18.4 Verificação do pacote

- Confirmar que o `.exe` existe e tem tamanho plausível.
- Confirmar que o `.pck` existe quando necessário.
- Validar integridade do ZIP.
- Fazer smoke test da exportação no ambiente disponível.
- Se CI Linux não puder executar o `.exe`, declarar a limitação e oferecer um job/manual de teste Windows.
- Preferir um job Windows para teste de inicialização.
- Verificar que o README de distribuição explica como extrair, executar e onde ficam os saves.

---

# 19. Riscos e decisões de produção

| Risco | Mitigação |
|---|---|
| Escopo excessivo | Vertical slice antes dos cinco capítulos |
| Arte inconsistente | Guia de sprites, paleta e escala |
| IA injusta | Estados explícitos e testes de perseguição |
| Puzzles confusos | Pistas redundantes e walkthrough de QA |
| Perda de saves | Versionamento e backups |
| Performance baixa | Limitar luzes e testar hardware modesto |
| Build quebrado | CI automatizada e smoke test Windows |
| Assets sem licença | Registro de origem e licença |
| História contraditória | Bíblia narrativa e revisão de continuidade |

---

# 20. Definição de pronto

Uma funcionalidade só é considerada concluída quando:
- está implementada no projeto;
- pode ser reproduzida em uma cena jogável;
- não depende de placeholder que simula o comportamento;
- tem tratamento de erros;
- foi testada;
- está documentada;
- não quebra sistemas existentes.

O jogo só pode ser declarado pronto para distribuição quando:
- os cinco capítulos planejados estiverem implementados;
- os quatro finais forem alcançáveis;
- o fluxo principal tiver sido testado;
- não houver bugs críticos conhecidos;
- o pacote portable tiver sido gerado;
- a versão publicada corresponder ao código e à tag;
- as limitações de testes forem declaradas honestamente.

---

# 21. Resumo executivo

**O Orfanato das Coisas Perdidas** é um survival horror 2D de pixel art, com perspectiva top-down e ambientação em um orfanato usado como fachada para experimentos humanos clandestinos.

O jogador controla Elias, uma criança de 12 anos que precisa sobreviver, investigar o Projeto Lázaro e compreender sua ligação com o lugar. A experiência combina exploração, furtividade, puzzles, perseguições, memória, escolhas narrativas e quatro finais.

A estética é sombria, detalhada e atmosférica. O terror é intenso desde o início, mas precisa ser justo e legível. O ambiente conta a história. A ciência humana é a origem central do horror, enquanto algumas manifestações permanecem ambíguas.

A entrega técnica deve ser um jogo Godot 4.x completo, com código organizado, documentação, testes e distribuição Windows portable em ZIP com executável funcional, disponibilizado em GitHub Releases.
