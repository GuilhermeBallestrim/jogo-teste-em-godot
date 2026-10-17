# Plano — Etapa 2

Estado atual: duas fases, três inimigos, um bone de 9 poses, zero assets de
arte, 335 verificações verdes.

O objetivo desta etapa é sair de "protótipo demonstrável" para "jogo com
ciclo completo e estrutura que aguenta crescer". A ordem não é decorativa:
cada bloco destrava o próximo, e vários deles só fazem sentido depois do
anterior.

---

## Fase 0 — Fundação — **feito**

### 0.1 Fechar a lacuna de teste do FSM — **feito**

Cinco suítes cobrem IDLE/PATROL, detecção, linha de visão, ataque com dano
confirmado e morte. `EnemyArena` monta chão, parede e player sem cena.

### 0.2 Extrair o fluxo de fase — **feito**

`src/level/level_base.gd` (`LevelBase`) centraliza reset, pausa, vitória,
derrota, reinício e o banner de save. `level_01.gd` caiu para 8 linhas: só
o doc e o `LEVEL_ID`. O layout continua no `.tscn`.

### 0.3 Save com mais de uma fase — **feito**

- `src/level/level_registry.gd` (`LevelRegistry`) mapeia id estável ↔ caminho
- Fase declarada em um lugar só: `_register_levels()` no `SceneRouter`
- Save apontando para cena removida cai na fase padrão e expõe
  `last_scene_missing()`
- `SAVE_VERSION` 1 → 2, com leitura da versão 1 legada

---

## Fase 1 — Conteúdo — **feito**

### 1.1 Inimigo voador — **feito**

`bat.gd` estende `Enemy` sobrescrevendo apenas `_apply_vertical()` e
ligando `flies`. **Não** sobrescreve `_on_landed()`, porque não tem chão.

### 1.2 Inimigo atirador — **feito**

`projectile.gd` é uma `Hitbox` voando sem uma linha de dano própria. O
estado `AIM` na FSM dá 0,45 s de telegrafia — inclusive para o slime.

### 1.3 Segunda fase — **feito**

`level_02.tscn`, registrada no `SceneRouter`. O menu ganhou a lista de
fases com "(continuar)".

### 1.4 Coletável de valor — **feito**

`Coin.tint` + `LevelBase.count_remaining_value()` somando valores.
`_check_goal_is_reachable()` avisa quando a fase pede mais do que a cena tem.

### 1.5 Prova de que o level design funciona — **feito**

Grafo de plataformas por fase, com a balística real do pulo. Achou a fase 1
**invencível** (duas plataformas 342 px e 402 px acima do chão, contra 303 px
de pulo). Refeito.

---

## Fase 2 — Sistema — **feito**

### 2.1 Inventário e itens — **feito**

- `src/items/item_definition.gd` (`ItemDefinition`) é um `Resource` com
  `Effect` (nenhum / cura / pontos). **Não** referencia `GameState`: um
  recurso de dado que puxa autoload deixa de ser dado e quebra o runner de
  testes. Quem tem o estado aplica o efeito.
- `src/items/item_library.gd` (`ItemLibrary`) monta o catálogo em código.
  O método se chama `definition()` e não `get()`: `get` colide com
  `Object.get()` e não compila.
- `GameState` tem `items` (id → quantidade), `add_item`, `remove_item`,
  `use_item`. Item desconhecido no save é descartado, nunca adivinhado.
- `scenes/props/item_pickup.tscn` (`ItemPickup`) é o nó do chão.
- A tecla `interact` (que estava no Input Map sem ninguém consumindo) passou
  a usar o item. Vida cheia **recusa** e não gasta — o som de "não dá"
  importa mais que o de "deu".
- HUD com tira de inventário, ícones desenhados em código.

### 2.2 Remapeamento de teclas — **feito**

- `Settings` guarda `bindings` (ação → eventos) em `settings.cfg` e reescreve
  o `InputMap`.
- Serialização **explícita** (`{"t":"key","c":<código físico>}`), não
  `as_text()`: `as_text()` devolve o rótulo da tecla, que muda com o idioma
  do sistema, e um save feito em português deixaria de funcionar em inglês.
- Só teclado e botão de mouse são reescritos. Os eixos de gamepad ficam
  intocados — apagar junto é o caminho mais curto para um remapeamento de
  teclado derrubar o controle inteiro **sem erro nenhum**.
- Aba "Controles" no painel: captura a próxima tecla, avisa conflito em vez
  de roubar a tecla, botão de restaurar padrão.
- `bindings` começa como cópia do padrão. Sem isso, `_apply_bindings()` —
  que apaga os eventos remapeáveis antes de reinserir — apaga o gamepad
  inteiro quando não existe `settings.cfg`.

### 2.3 Acessibilidade mínima — **feito**

- **Escala de texto** (80%–150%): reescreve os overrides de
  `theme_override_font_sizes`, guardando o tamanho base em metadado. Não dá
  para usar `content_scale_factor` (escalaria o mundo junto) nem
  `Theme.default_font_size` (que o projeto ignora, porque cada `Label` do
  `.tscn` tem o seu override). O original fica guardado justamente para
  reaplicar não acumular: 1,5 × 1,5 = 2,25 a cada visita ao painel.
- **Tremor de câmera**: `CameraShake` lê `Settings.shake_scale`. Preferência
  zero desliga na hora, sem esperar a intensidade decair.
- **Alto contraste**: um `CanvasModulate` clareia a cena. O jogo é escuro
  sobre escuro, e quem tem baixa visão perde a silhueta na conta do fundo.

---

## Fase 3 — Polish (3.1 feito)

### 3.1 Feedback de combate - **feito**

- Hitstop: congela o relogio por 1 a 4 quadros conforme o dano, com teto de
  120 ms para nenhum golpe travar o jogo
- Numero de dano subindo no ponto do golpe, com contorno, e a cor dizendo de
  quem foi: vermelho no player, verde no inimigo
- Tremor de tela escalando com o dano (0.45 a 1.0), em vez dos 0.8 fixos
- Poeira ao correr, respingo ao pousar, rastro no dash e estouro na morte do
  inimigo

Prova: 399 checagens no testador e 9 capturas medidas por
`tools/capture_feel.gd`. O que a captura **mexeu** no plano: o numero do
inimigo era dourado e sumia entre as moedas, e foi para verde.

### 3.2 Stats de sessão

Tempo de fase, mortes, taxa de vitória, moedas por segundo.

### 3.3 Arte mínima

Continua zero assets. O bone procedural (`PlayerRig`) mostrou que dá para
ter 9 poses legíveis sem um único arquivo de imagem — e que a decisão
"geométrica em código" escala melhor do que se esperava.

---

## Onda 1 -- **pronta**

Camera com antecipacao, feedback de combate e particulas. As tres entraram.
O detalhamento continua em [`plano-evolucao.md`](plano-evolucao.md).

| Item | O que foi | Onde |
|---|---|---|
| Camera | Antecipacao ate 74 px, proporcional a velocidade; estica 1.5x e da zoom no dash; volta ao centro mais rapdo do que sai | `src/camera/camera_look.gd` |
| Hitstop | Congela o relogio por 1-4 quadros conforme o dano, com teto de 120 ms | `autoload/hitstop.gd` |
| Numero de dano | Sobe e some no ponto do golpe; vermelho no player, verde no inimigo | `scenes/ui/floating_number.gd` |
| Tremor | Escala com o dano em vez de valer 0.8 fixo | `src/camera/camera_shake.gd` |
| Particulas | Poeira ao correr, respingo ao pousar, rastro no dash, estouro na morte | `src/fx/particle_preset.gd` |

**Verificacao.** 399 checagens no testador (era 335), mais
`tools/capture_feel.gd`, que tira 9 fotos e mede cada efeito.

Tres coisas mudaram de ideia por causa da verificacao, e nao do plano:

- O numero de dano do inimigo era **dourado** -- a mesma cor das moedas e da
  faixa das plataformas. A captura mostrou o numero sumindo no cenario. Foi
  para verde, que nao existe em lugar nenhum da paleta.
- A antecipacao media **+2.5 px** num dia e **+67.9 px** no seguinte. Nao era
  a camera: era o bone correndo no buraco da fase e voltando do checkpoint. Os
  tiros de camera passaram a rodar na arena plana.
- A ferramenta contava pixels da cor do efeito e dava **"1505 px de
  vermelho"** como prova do numero de dano. Eram o slime. Passou a contar
  diferenca contra um controle.

**O que continua sem prova automatica:** o peso do hitstop. Um instante
congelado e indistinguivel de um instante normal numa foto. So se sente
jogando.

---

## Onda 3 -- **pronta**

Editor visual de layout, mais inimigos e mais fases. As tres entraram.

| Item | O que foi | Onde |
|---|---|---|
| Editor de layout | `tools/preview_level.gd`: desenha o arco do pulo a partir de cada plataforma, com marcador verde/vermelho no ponto final | `tools/preview_level.gd` |
| Escorre | Anda rapido, ignora a borda e cai; a rede de seguranca (`_guard_offscreen`) o traz de volta | `scenes/actors/enemies/crawler.gd` |
| Explosivo | Ao morrer, danifica o jogador num raio de 110 px por caminho direto (sem `Hitbox`) | `scenes/actors/enemies/bomber.gd` |
| Guarda | Nao patrulha: fica no posto e so persegue se o jogador entrar no raio | `scenes/actors/enemies/guard.gd` |
| Fase 3 | Variacao da fase 1 com os tres inimigos novos | `scenes/levels/level_03.tscn` |

**Verificacao.** 411 checagens no testador (era 399): 3 suites novas para os
inimigos, mais a fase 3 nos testes de balistica e de "inimigos nao caem",
mais os smoke tests das tres cenas.

---

## Onda 4 -- **plano**

Tudo o que sobrou depois da Onda 3: teste de input real, boss, tela de fim
animada, habilidades, hub, mais niveis, mais inimigos, mais itens, mais
particulas, transicoes e musica variavel. Detalhamento em
[plano-onda-4.md](plano-onda-4.md).

`
Onda 4  input real -> boss -> tela de fim animada
Onda 5  habilidades -> hub -> niveis
Onda 6  inimigos -> itens -> particulas -> transicoes -> musica
`

---
## Ondas seguintes

```
Onda 2  stats de sessao -> save por slot/hub -> mais verbos de combate
```

O principio que organiza continua o mesmo: **cada onda faz o jogo parecer mais
finished, nao maior.** Camera com antecipacao valeu mais que uma quarta fase
porque afeta todas elas.

---

## Fora do escopo

### i18n — **descartado**

Não vai ser feito. Consequência aceita: todo texto continua hardcoded em
português, e sair do português significa varrer `.tscn` e `.gd`. Fica como
dívida conhecida e documentada.

---

## Ordenação

```
Fase 0  testes do FSM  ->  base da fase  ->  save/reset        [feito]
Fase 1  voador -> atirador -> fase 2 -> coletável            [feito]
Fase 2  inventário -> remapear -> acessibilidade             [feito]
Fase 3  feedback (feito) -> stats -> arte                  [parcial]
```

---

## Risco

### Risco que já virou realidade

**Nível não testado é nível possivelmente impossível.** A fase 1 ficou
semanas sem ninguém perceber que não dava para terminar. O teste de
balística (1.5) existe para isso não voltar: qualquer `position` nova
passa por ele.

A lição prática: o que não tem verificação automatizada precisa de uma
verificação manual — e manual não é o mesmo que feita.

### Risco atual

A **Fase 3.3 (arte)** é a única que pode virar dependência externa: se você
quer arte de verdade gerada por IA, ela precisa entrar antes de começar a
animar personagem, ou o trabalho é jogado fora.

---

## Proximo bloco

O 3.1 (feedback de combate) ja entrou, junto com camera antecipada e
particulas. O que mais rende agora e o **3.2 (stats de sessao)**: e o que da
motivo para rejogar, e a tela de vitoria fica mais interessante agora que o
golpe tem peso.

Antes dele, uma decisao continua pendente: a **3.3 (arte)**. E a unica
dependencia externa do plano, e tem que entrar antes das fases novas se for
arte importada -- senao o layout das fases e desenhado para bone de
`Polygon2D` e jogado fora.
