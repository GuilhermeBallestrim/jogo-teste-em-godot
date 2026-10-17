# Plano de reidealizacao das fases

Refazer as quatro fases do zero, com identidade propria, layout desenhado e
verificado. Este documento e o plano -- a execucao so comeca depois da
aprovacao.

## 1. Princípios de design

**Chao continuo, sem buracos mortais.** O jogador ja pediu "nenhum mapa com
buracos". Entao o chao de cada fase e uma plataforma continua cobrindo toda a
largura. A dificuldade vem das plataformas ACIMA do chao (moedas, inimigos,
itens), nao de cair no vazio. Quem cai de uma plataforma volta para o chao,
e o KillZone so existe para o caso de cair do mundo (hoje mata e respawna).

**Moedas guiam o caminho.** Cada moeda fica no ponto para onde o jogador deve
ir -- em cima de uma plataforma, no fim de um salto, perto de um item. A rota
de moedas e a rota do nivel.

**Inimigo ensina uma mecanica.** Cada fase introduz ou reforca um tipo de
inimigo no contexto em que ele faz sentido:
- Fase 1: slime (basico) + bat (voador, primeira vez).
- Fase 2: bat + archer (atirador, cobertura de chao).
- Fase 3: crawler (cai e volta), bomber (dano em area), guard (espera).
- Fase 4: boss.

**Item antes de precisar.** O item fica no caminho, antes do trecho onde ele
ajuda: potion antes do primeiro inimigo, bomb antes do grupo de bombers,
shield antes da seccao de falls.

**Checkpoint no meio.** Fases longas (3) tem dois checkpoints; as curtas (1, 2)
tem um. Fase 4 (boss) nao precisa.

## 2. Restricoes tecnicas (o teste de balistica)

O teste de balistica valida que toda plataforma e alcancavel a partir do
SpawnPoint, e que toda moeda e alcancavel. Os valores reais de pulo:

| subida | alcance horizontal |
|---|---|
| 0 px (plano) | 289 px |
| 40 px | 18 px |
| 80 px | 39 px |
| 120 px | 61 px |
| 160 px | 85 px |
| 200 px | 114 px |
| 240 px | 150 px |
| 280 px | 205 px |
| 303 px (max) | 0 px |

**Regra de layout: subindo, o voo e curto.** Um degrau de 60 px so passa com
~28 px de voo horizontal; um de 200 px precisa de 114 px. **Descendo, o voo e
largo** -- 289 px no plano, mais ainda descendo.

Na pratica: plataformas empilhadas (subindo) ficam quase em cima uma da outra;
plataformas lado a lado no mesmo nivel podem ter ate 289 px de vao.

**Inimigos nao podem cair.** Patrol bounds sao offsets do spawn, entao cada
inimigo fica na plataforma onde nasceu. O teste "inimigos nao caem" confere.

## 3. Decisoes abertas (preciso da sua resposta)

1. **Buracos no chao?** Voce pediu "nenhum mapa com buracos". As fases novas
   seguem isso (chao continuo)? Ou quer liberar vãos no chao na fase 3 (o
   abismo), ja que cair agora mata e respawna?
2. **Moedas por fase.** Quantas moedas cada fase deve ter? Sugestao: 10 / 12 /
   14 / 0 (boss).
3. **Itens por fase.** Quais itens aparecem onde? Sugestao:
   - Fase 1: pocao, pena.
   - Fase 2: bolsa de moedas, escudo.
   - Fase 3: bomba, ima.
   - Fase 4: pocao (uma, antes do boss).
4. **Habilidades.** As habilidades desbloqueaveis (pulo duplo, dash carregado,
   parry melhorado) entram em alguma fase especifica, ou continuam sendo
   desbloqueadas automaticamente ao vencer?

## 4. As quatro fases

### Fase 1 -- "Planicie dos Comecos" (tutorial)

**Tema:** amanhecer, paleta quente (laranja/ambar). Chao continuo, plataformas
baixas e largas.

**Mecanica foco:** movimento, pulo, dash, ataque basico.

**Layout:**
- Chao continuo em y=40, largura total.
- 8 plataformas baixas (altura 60-120 acima do chao), espalhadas em x de
  -1000 a 1000, cada uma com moedas em cima.
- 3 plataformas altas (200-240) nas pontas, com moedas de valor 2.
- SpawnPoint em x=-1000, y=-40.

**Inimigos:** 2 slimes no chao (patrulha curta), 1 bat voando alto no meio.

**Moedas:** 10 (8 de valor 1 + 2 de valor 2).

**Itens:** pocao no comeco (x=-900), pena no meio (x=0).

**Checkpoint:** 1 em x=0.

**coins_to_win:** 10.

### Fase 2 -- "Torres do Vento" (vertical)

**Tema:** ceu, paleta fria (azul/ciano). Torres empilhadas, escalada.

**Mecanica foco:** pulo vertical + dash para voos largos.

**Layout:**
- Chao continuo em y=40 (a base).
- 3 torres de plataformas empilhadas (subidas de 200-280), uma no inicio,
  uma no meio, uma no fim. Cada torre sobe ~280 px por degrau, quase em cima.
- Plataformas de ligacao no alto (mesmo nivel, vao de ~200 px) entre torres.
- O objetivo e subir ate o topo da ultima torre.

**Inimigos:** 2 bats (alto, entre torres), 2 archers (base, cobrindo o chao).

**Moedas:** 12 (nas ledges altas, recompensando a subida).

**Itens:** bolsa de moedas (base), escudo (antes da ultima torre).

**Checkpoint:** 1 no meio da subida.

**coins_to_win:** 12.

### Fase 3 -- "Abismo de Pedra" (tensao)

**Tema:** pedra escura, paleta roxa/cinza. Planaltos altos com degraus.

**Mecanica foco:** bomb (dano em area) + parry + leitura de inimigos.

**Layout:**
- Chao continuo em y=40.
- 3 planaltos altos (altura 240-280) separados por degraus de 60-100 px
  (subindo devagar). Moedas nos planaltos.
- Plataformas flutuantes baixas (altura 60) com moedas de valor 2.
- Se houver vãos no chao (decisao aberta 1), ficam entre os planaltos.

**Inimigos:** 1 crawler (patrulha o planalto), 2 bombers (um por planalto),
1 guard (espera no planalto final).

**Moedas:** 14.

**Itens:** bomba (antes do primeiro bomber), ima (antes dos planaltos).

**Checkpoints:** 2 (um por planalto).

**coins_to_win:** 14.

### Fase 4 -- "Coracao do Rei" (boss)

**Tema:** vermelho/escuro. Arena plana.

**Mecanica foco:** boss fight (o boss redesenhado).

**Layout:**
- Chao continuo em y=40, arena de ~1200 px de largura.
- 3 plataformas baixas (altura 80-120) nas laterais e no meio, para desviar
  dos ataques do boss.
- Sem moedas (coins_to_win = 0).

**Inimigos:** 1 boss no centro.

**Itens:** 1 pocao antes da arena (x=-500).

**Checkpoint:** nenhum (a arena e curta).

**Condicao de vitoria:** derrotar o boss (nao moedas). Precisa de override de
`check_extra_victory()` na fase 4, ouvindo o sinal `died` do boss e chamando
`_win()`.

## 5. Implementacao, passo a passo

1. **Fase 1** -- escrever `level_01.tscn` (chao, plataformas, inimigos,
   moedas, itens, checkpoint, bounds, killzone). Atualizar `level_01.gd`.
2. Rodar o teste de balistica. Iterar o layout ate passar.
3. Repetir para fases 2, 3, 4.
4. Fase 4: adicionar `check_extra_victory()` e conectar o boss `died`.
5. Atualizar o parallax de fundo por fase (cor do ceu/montanhas).
6. Capturas de tela de cada fase (`capture_ui.gd`).
7. Commit por fase (ou por par de fases).

## 6. Verificacao

- **Teste de balistica:** toda plataforma e moeda alcancavel.
- **Teste "inimigos nao caem":** nenhum inimigo cai no KillZone.
- **Teste de cenas:** as 4 fases instanciam sem erro.
- **Capturas:** uma por fase, conferidas visualmente.
- **450+ checagens verdes.**

## 7. Riscos

- **Layout inalcancavel:** o teste de balistica pega e eu ajusto. Cada iteracao
  e rapida (rodar o teste, ler o erro, mover a plataforma).
- **Inimigo fora da plataforma:** o teste "inimigos nao caem" pega.
- **Fase 4 sem vitoria:** precisa do override de vitoria por boss. E o unico
  ponto que muda logica de jogo, nao so layout.
- **Tempo:** 4 fases com layout desenhado e validado e trabalho de algumas
  horas. Vou fazer uma fase por vez e mostrar o resultado.