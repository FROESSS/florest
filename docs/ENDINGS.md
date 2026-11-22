# Finais — tabela de condições

O console principal (`c5_controle`) só aceita decisão depois da memória "A última criança". As **opções disponíveis** dependem de preparação ao longo do jogo (nenhum final depende só da última escolha):

| Final | Opção aparece se… | Como obter |
|---|---|---|
| **A LIBERDADE** | `escape_tunnel_open` | Capítulo 5: resolver as válvulas (ordem 3-1-2) no painel do Nível B |
| **O SILÊNCIO** | `reactor_primed` **ou** `equipment_destroyed` | Armar o reator (cap. 5) **ou** destruir o projetor de memórias (cap. 4) |
| **O HERDEIRO** | `control_card` | Cap. 4: resolver o terminal (senha 0712) — cartão de controle |
| **AS COISAS PERDIDAS** (secreto) | ≥ 8 memórias **e** memória `pre_inauguracao` **e** `clara_trust ≥ 2` **e** `keep_elias_record` **e** **não** `equipment_destroyed` | Abrir o cofre (1403) e ouvir a fita, confiar em Clara nas escolhas, guardar o registro L-12 e **não** destruir o projetor |

Escolhas que alteram o estado: confiar em Clara (+1 em cada encontro: cap. 2, 3, 4), ajudar crianças (Tomás, Lia, Beto), guardar/destruir o registro L-12, destruir/poupar o projetor, armar/não armar o reator.

Memórias (10): `ursinho`, `foto`, `desenho`, `tomas`, `aula`, `cuidadora`, `brinquedos`, `clara`, `pre_inauguracao`, `elias`.

Os quatro finais são verificados por `tests/suite_endings.gd` (tabela) e `tests/suite_walkthrough.gd` (jogo completo, variantes A–F).
