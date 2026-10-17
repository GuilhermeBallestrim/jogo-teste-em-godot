# Design

## Loop

```
Menu ──► escolher fase ──► explorar ──┬──► coletar tudo ──► VITÓRIA
                                       ├──► cair no vazio ──► perde 25 de vida, volta ao checkpoint
                                       └──► tomar dano ─────► i-frames de 1s, perde vida
                                                 │
                                            vida = 0 ──► DERROTA
```

A única condição de vitória é **coletar tudo**. A defeat é perder a vida
inteira (100) sem i-frames estar ativos.

## Sensação de jogo

O que o protótipo procura, em ordem de prioridade:

1. **O dash precisa parecer bom.** É o botão mais satisfying do repertório
   padrão. Por isso ele ignora gravidade e atrito durante 0,14s, dá uma
   arrancada ao final e faz a câmera tremer ao aterrissar forte.
2. **O pulo precisa ser tolerante.** Coyote time (0,10s) e jump buffer (0,12s)
   existem para que o jogador *nunca* sinta que o input foi perdido.
3. **O inimigo precisa dar janela.** O ciclo `AIM → ATTACK → STAGGER` existe
   para que a briga seja rítmica: ele para, encara, ataca, recua — você revida.
   Inimigo que só prende não é divertido, é irritante.
4. **A morte tem que ser barata.** Cair custa 25 de vida e te devolve no
   último checkpoint — sem tela de morte no meio do jogo.

## Números

Todos em `src/player/player_tuning.gd` (movimento do player),
`scenes/actors/enemies/*.gd` e nos `@export` das cenas de inimigo.

| Constante | Valor | Por quê |
|---|---|---|
| `SPEED` | 340 px/s | ~1,7 telas em 1s; responsivo sem parecer instantâneo |
| `JUMP_VELOCITY` | −760 | com o `APEX_GRAVITY_SCALE`, sobe **303 px** |
| `JUMP_CUT` | 0,45 | soltar cedo corta o pulo pela metade: altura variável |
| alcance do pulo, na mesma altura | 289 px | é o número que limita os vãos das fases |
| `DASH_SPEED` × `DASH_TIME` | 980 × 0,14s | +137 px de empurrão |
| `DASH_COOLDOWN` | 0,55s | permite repetir sem virar saída de emergência |
| `IFRAME_TIME` | 1,0s | atravessa a fase sem virar poluição de efeitos |
| `ATTACK_COOLDOWN` | 0,32s | ~3 golpes/s, o bastante para martelar mas não trivializar |
| dano do `KillZone` | 25 | 4 quedas matam de 100 de vida |
| `max_health` do slime | 3 | leva 3 golpes |
| `max_health` do voador | 2 | morre rápido, porque o problema dele é perseguir, não a resistência |
| `max_health` do arqueiro | 3 | e ele dá 0 de dano por contato: mata-se por distância |
| `AIM_TIME` | 0,45s | telegrafia antes do tiro |
| `aim_tolerance` do arqueiro | 90 px | ele só acerta se você estiver na mesma faixa de altura |

**A matemática do pulo, que decide o level design:** a gravidade é 980, mas cai
para 735 quando `|vy| < 220` (o ápice "flutua"). Isso dá 270 px na subida cheia
+ 33 px no trecho flutuante = **303 px de altura**, e **289 px de alcance
horizontal** num pulo que sai e volta à mesma altura.

O detalhe que pega: **subir custa alcance.** Para pousar 200 px acima, o
pulo alcança só 114 px na horizontal — porque você tem que *chegar lá* no
quadrante ascendente, não passar por cima na descida. Por isso os vãos que
*subem* nas fases são curtos (60–100 px) e os vãos largos são sempre
*descendo*. O teste de balística das fases existe para manter essa regra sem
depender de alguém lembrar dela.

## Fases

### Fase 1 — Corredores (`level_01`)

Cinco chão contínuo com quatro plataformas flutuantes entre eles, de `-1200` a
`1800`. Quatro slimes, dois checkpoints, 12 moedas.

A alternância é proposital: chão → torre → chão → torre. Subir é curto,
descer é longo. Quem joga aprende a regra no corpo antes de ler sobre ela.

### Fase 2 — Torres (`level_02`)

O oposto: duas bases e seis torres empilhadas, de `-1200` a `1510`. Um slime
no chão, dois arqueiros nas plataformas, três voadores no alto. 10 moedas, uma
delas de valor 2, para um total de 11 pontos.

Aqui o voador muda a leitura da fase: subir deixa de ser só um problema de
plataforma e vira um problema de *linha de visão*. O arqueiro faz o mesmo pelo
outro lado — ele não se move até você, ele para e espera a linha de altura.

## Legibilidade das ameaças

Três inimigos, três leituras distintas — sem nenhum deles precisar de sprite:

| | Slime | Voador | Arqueiro |
|---|---|---|---|
| **cor** | verde | roxo | azul-acinzentado |
| **movimento** | pula no lugar | ondula, nunca pousa | anda devagar, para e encara |
| **ataque** | avança e recua | o corpo inteiro | tiro, depois recuo de 90 px |
| **aviso** | o avanço | a subida | os 0,45s parado encarando |
| **o que ensina** | timing | linha de visão | distância |

A telegrafia do `AIM` vale para os dois: o slime agora também congela 0,45s
antes de atacar. Deu para o ciclo de todo mundo ficar legível pelo mesmo
gesto.

## O que ainda não existe

Lista honesta do que o protótipo **não** tem:

- Nenhum sprite — tudo é `Polygon2D` com cor chapada
- Nenhuma animação de personagem (o squash do slime é o único tween de feedback)
- Sem chefe
- Sem inventário/itens de consumo — `Coin.value` existe, mas nada é gastável
- Sem menu de remapeamento de teclas (as ações do Input Map já estão prontas
  para isso; falta a UI)
- Sem tela de opções de acessibilidade (tamanho de fonte, contraste)
- Sem áudio gravado — tudo é síntese procedural
- Sem save por slot; há um slot só, e o menu não trava fases por progresso