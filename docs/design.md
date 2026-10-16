# Design — Fase 1

## Loop

```
Menu ──► explorar a fase ──┬──► coletar as 12 moedas ──► VITÓRIA
                            ├──► cair no vazio ───────► perde 25 de vida, volta ao checkpoint
                            └──► tomar dano de slime ─► i-frames de 1s, perde vida
                                        │
                                   vida = 0 ──► DERROTA
```

Vitória e derrota são ambas **"pegue as 12 moedas"** no mesmo nível: a única
condição de vitória éternal (coletar tudo), a derrota é perder a vida quatro
vezes sem i-frames estar ativos.

## Sensação de jogo

O que o protótipo procura, em ordem de prioridade:

1. **O dash precisa parecer bom.** É o botão mais satisfying do repertório
   padrão. Por isso ele ignora gravidade e atrito durante 0,14s, dá uma
   arrancada ao final e faz a câmera tremer ao aterrissar forte.
2. **O pulo precisa ser tolerante.** Coyote time (0,10s) e jump buffer (0,12s)
   existem para que o jogador *nunca* sinta que o input foi perdido.
3. **O inimigo precisa dar janela.** O ciclo `ATTACK → STAGGER` existe para que
   a briga seja rítmica: ele avança, recua, você revida. Inimigo que só prende
   não é divertido, é irritante.
4. **A morte tem que ser barata.** Cair custa 25 de vida e te devolve no último
   checkpoint em 0,25s — sem tela de morte no meio do jogo.

## Números

Todos em `player.gd` e `enemy.gd`, como constantes no topo do arquivo.

| Constante | Valor | Por quê |
|---|---|---|
| `SPEED` | 340 px/s | ~1.7 telas em 1s; responsivo sem parecer instantâneo |
| `JUMP_VELOCITY` | −820 | ~1,7s de ar, ~570px de alcance — pula os vãos de 160–200px com folga |
| `JUMP_CUT` | 0,45 | soltar cedo corta o pulo pela metade: altura variável |
| `DASH_SPEED` | 980 px/s | ~2,9× a velocidade de corrida |
| `DASH_COOLDOWN` | 0,55s | permite repetir sem virar saída de emergência |
| `IFRAME_TIME` | 1,0s | atravessa a fase sem virar poluição de efeitos |
| `ATTACK_COOLDOWN` | 0,32s | ~3 golpes/s, o bastante para martelar mas não trivializar |
| `max_health` do slime | 3 | leva 3 golpes, ou 1 se acertar durante o `STAGGER` |

**Vantagem do pulo medida:** com `JUMP_VELOCITY = -820` e gravidade 980, o
tempo de voo é `2 × 820 / 980 ≈ 1,67s`, e o alcance horizontal fica em torno
de `340 × 1,67 ≈ 570px`. Todos os vãos da fase têm no máximo 200px — sobra
margem para errar a borda.

## Fases

Três trechos com ameaças diferentes:

- **Início** (`-1200` a `-760`): chão seguro, um slime frouxo e o primeiro
  checkpoint. Espaço para aprender pulo e dash sem pressão.
- **Meio** (`-600` a `360`): três vãos, o mais largo é o do `KillZone`, e as
  plataformas flutuantes levam a moedas fora do caminho. Dois slimes já
  perseguem. É onde o dash compensa.
- **Fim** (`560` a `1200`): chão contínuo, um slime com patrulha de ±240 e a
  plataforma alta com a última moeda. Recompensa por subir.

O segundo checkpoint fica no início do último trecho: morrer no meio do jogo
não joga o jogador de volta ao começo.

## O que ainda não existe

Lista honesta do que o protótipo **não** tem:

- Nenhum sprite — tudo é `Polygon2D` com cor chapada
- Nenhuma animação de personagem (o squash do slime é o único tween de Feedback)
- Sem inimigos voadores, sem chefe, sem chefe final
- Sem fase 2+
- Sem sistema de inventário/equipamento — `GameState.coins` é só um contador
- Sem menu de remapeamento de teclas (as ações do Input Map já estão prontas
  para isso; falta a UI)
- Sem tela de opções de acessibilidade (tamanho de fonte, contraste)