# Plano de fechamento

Roadmap de features depois da Onda 3. Nao e promessa -- e ordem sugerida com o
motivo de cada passo e como verificar que ficou bom.

Tamanhos sao relativos: **P** = um dia de trabalho, **M** = dois ou tres,
**G** = uma semana. Nao sao estimativas de calendario: dependem de quantas
horas voce quer investir por semana.

## Status

**Ondas 1, 2 e 3 estao prontas.** Camera, feedback de combate, particulas,
stats, slots, verbos de combate, editor de layout, tres inimigos novos e
fase 3. 425 checagens no testador, sem erros de script.

O que esta lista cobre e o que sobrou depois disso: o clima de "jogo que
fecha" (boss, tela de fim animada) e a infraestrutura que ainda mente
(teste de input real). Tudo o resto e conteudo e polish.

## A regra que organiza tudo

**Fechar antes de crescer.** A tentacao agora e adicionar mais fases, mais
inimigos, mais itens -- e o jogo fica mais largo sem ficar mais fundo. A
ordem abaixo coloca o clima (boss, tela de fim) e a confiabilidade (teste
de input) antes do conteudo, porque conteudo sem clima e conteudo sem
motivo para existir.

Excecao: se o que falta e claramente conteudo (voce ja jogou e quer mais
fase), pule para a Onda de conteudo.

---

## Onda 4 - O jogo fecha

### A. Teste de input real - **M** - **paralelo, antes de tudo**

**Por que.** E a maior mentira nao coberta do projeto: todo o movimento e
verificado com `Input.get_vector` direto, nunca com teclado de verdade.
"Funciona com o teclado" e afirmacao que ninguem verificou. E o item com
melhor custo-beneficio da lista inteira.

**Onde.** `tests/` - um script que abre uma janela, injeta eventos de
teclado reais (via `InputEventKey` em `Input.parse_input_event` ou
`Viewport.push_input`) e confere o resultado. Precisa rodar fora do
`--headless`, como `capture_*.gd`.

**Verificar.** Ele mesmo: um teste que passa e a prova de que o caminho real
funciona. Se falhar, temos um bug real de input para consertar, nao uma
lacuna de teste.

**Cuidado.** `Input.action_press` (que as ferramentas de captura usam) mexe
no estado da acao, nao no fluxo de eventos. O teste real precisa do fluxo
de eventos, senao nao prova o que diz provar.

### B. Boss - **G**

**Por que.** O FSM do inimigo ja suporta estados; um boss e so um inimigo
com mais HP e padroes. Nao existe ainda, e um jogo de plataforma sem boss
nao tem clima. E o item que mais muda a sensacao de "jogo" para "jogo
terminado".

**Onde.**
- `scenes/actors/enemies/boss.gd` (novo) - subclass de `Enemy` com estados
  proprios: IDLE, ATTACK_A, ATTACK_B, VULNERABLE, STAGGER, DEAD. Usa o
  `_think` do base como ponto de partida e sobrescreve.
- `scenes/actors/enemies/boss.tscn` - corpo grande, hitbox ampla, health bar
  visivel.
- `scenes/levels/level_04.tscn` - fase final, com arena de boss (sem
  plataformas, so chao e paredes).

**Padroes sugeridos.** Salto com onda de choque (Area2D radial), rajada de
projeteis (reusa `Projectile`), carga (dash do boss). Cada padrao e um
estado do FSM; o `_think` decide qual entrar.

**Verificar.** Suite de FSM por padrao, como as dos outros inimigos. O
`EnemyArena` ja monta tudo; o boss so precisa de uma arena maior.

**Depende de.** A (input real) e recomendado antes, para ter certeza de que
o jogador consegue esquivar dos padroes.

### C. Tela de fim animada - **M**

**Por que.** Hoje e um `CanvasLayer` estatico com texto. A tela de vitoria
e o que o jogador le depois de tudo; se parece placeholder, o jogo parece
placeholder.

**Onde.**
- `scenes/ui/end_screen.gd` + `.tscn` - animacao de entrada (fade + scale),
  confete/particulas na vitoria, tremor no game over, exibicao dos stats
  (ja existe) com animacao de contagem.
- Reusa `ParticlePreset` para o confete.

**Verificar.** Captura de tela (a animacao e leitura, nao regra). O stats
ja tem teste.

### D. Habilidades desbloqueaveis - **G**

**Por que.** O inventario e consumivel. Falta algo permanente que mude como
o jogador joga: pulo duplo, dash carregado, parry melhorado. E o que da
motivo para voltar.

**Onde.**
- `src/abilities/ability.gd` (novo, Resource) - dados da habilidade.
- `autoload/game_state.gd` - `abilities: Array[StringName]` + `unlock()`,
  `has_ability()`.
- `scenes/actors/player/player.gd` - consulta `GameState.has_ability()` nos
  pontos certos (pulo duplo no `_process_jump`, dash carregado no
  `_start_dash`).
- Save: habilidades desbloqueadas persistem (campo no payload).

**Verificar.** Teste de desbloqueio e de efeito (pulo duplo permite segundo
salto).

**Depende de.** E (hub) para escolher qual habilidade desbloquear, ou
desbloqueio automatico por fase.

### E. Hub com progresso por slot - **G**

**Por que.** A infraestrutura de slots existe (Onda 2) e nao tem tela. O
jogador nao consegue ver o que ja fez.

**Onde.**
- `scenes/ui/hub.gd` + `.tscn` (novo) ou extensao do `main_menu`.
- Mostra: slots, fases destravadas, recordes por fase (tempo, mortes, nota),
  habilidades desbloqueadas.
- Usa `Save.list_slots()`, `Save.peek_level_id()`, `LevelRegistry`.

**Verificar.** Captura de tela + teste de desbloqueio (fase N so aparece
depois de N-1).

**Depende de.** D (habilidades) para mostrar o que foi desbloqueado.

### F. Mais niveis - **P** por nivel, com layout de dia

**Por que.** Tres hoje. Adicionar um e: um `.tscn`, um `.gd` de 8 linhas,
uma linha no `SceneRouter`. O teste de balistica e o de "inimigos nao caem"
ja rodam sobre `LEVELS`.

**Onde.** `scenes/levels/level_04.tscn` (arena do boss) + `level_05.tscn`
(opcional, fase de transicao).

**Verificar.** Adicionar o caminho em `LEVELS` do test runner e rodar.

**Depende de.** I (editor de layout) para validar o layout, B (boss) para a
fase final.

### G. Mais inimigos - **M** por inimigo

**Por que.** A arquitetura ja provou que aceita variacao. Candidatos que
exercitam caminhos ainda nao testados:

- **Escudo** - bloqueia golpes frontais; so toma dano por tras ou por cima.
  Testa a direcao do golpe.
- **Teleportador** - desaparece e reaparece perto do jogador. Testa IA que
  nao patrulha.
- **Mini-boss** - versao menor do boss, para fases intermediarias.

**Onde.** `scenes/actors/enemies/*.gd` + `.tscn`, seguindo o padrao de
subclass.

**Verificar.** Suite de FSM por inimigo, como as existentes. O `EnemyArena`
ja monta tudo.

### H. Mais itens - **P** por item

**Por que.** O inventario existe, mas so tem pocao, bolsa de moedas e pena.
Adicionar item e uma linha no `ItemLibrary` + um `.tscn` de pickup.

**Candidatos.**
- **Bomba** - dano radial ao usar (reusa o codigo do Explosivo).
- **Escudo** - invulnerabilidade por 3 s.
- **Ima** - atrai moedas num raio por 5 s.

**Onde.** `src/items/item_library.gd` + `scenes/props/item_pickup.tscn`.

**Verificar.** Teste de uso (ja existe padrao) + captura de tela.

### I. Mais particulas - **P**

**Por que.** Explosao do inimigo, impacto do golpe, poeira ao correr (ja
tem), particulas de moeda. Pequeno custo, grande sensacao.

**Onde.** `src/fx/particle_preset.gd` (presets novos) + chamadas nos
pontos certos.

**Verificar.** Captura de tela com contagem de pixels, como `capture_feel.gd`.

### J. Transicoes de tela - **P**

**Por que.** O `SceneRouter` ja tem fade, mas nao e usado em tudo. Fase para
fase com fade muda a sensacao de "carregamento" para "continuidade".

**Onde.** `autoload/scene_router.gd` - garantir que todas as transicoes
usam o fade. `LevelBase._show_end_screen` - fade na tela de fim.

**Verificar.** Captura de tela (leitura) + teste de que o fade nao trava o
input.

### K. Musica variavel - **M**

**Por que.** Uma trilha por fase, ou variacao de intensidade. O AudioManager
ja suporta camadas; falta usar.

**Onde.** `autoload/audio_manager.gd` - camadas por fase. `scenes/levels/*.tscn`
- chama `Music.play(track_name)` em `_ready`.

**Verificar.** Captura de... nao da para capturar audio. Teste de que a
camada certa toca (via `AudioManager`).

---

## Investimento em infraestrutura

### H. Teste de input real - **M** - **paralelo**

Ver A. E o mesmo item, listado aqui porque e infraestrutura e nao feature.

### L. Arte - **G** - **decisao antes de comecar**

Ver plano anterior. Continua pendente.

---

## Ordem sugerida

```
Onda 4   A teste de input  ->  B boss  ->  C tela de fim animada
Onda 5   D habilidades  ->  E hub  ->  F niveis
Onda 6   G inimigos  ->  H itens  ->  I particulas  ->  J transicoes  ->  K musica
Paralelo H input real (antes de tudo)  +  L arte (decisao)
```

A ordem dentro de cada onda importa menos do que a ordem entre elas: teste
de input antes do boss, porque o boss depende de esquiva; tela de fim
depois do boss, porque e onde o jogador ve o resultado.

## Cortes, em ordem

Se precisar parar no meio, corte nesta ordem -- cada um e removivel sem
quebrar o que ficou:

1. **K (musica variavel)** - nice-to-have, nao muda o jogo.
2. **J (transicoes)** - o fade ja existe, so nao e usado em tudo.
3. **I (particulas extras)** - o jogo funciona sem elas.
4. **H (itens)** - o inventario ja tem tres.
5. **G (inimigos)** - tres novos ja existem.
6. **F (niveis)** - tres ja existem.
7. **E (hub)** - o menu ja lista fases.
8. **D (habilidades)** - o jogo funciona sem progressao permanente.

**Nao corte** A, B, C. A e o que faz o trabalho ser confiavel; B e C sao
o que faz o jogo parecer terminado.

## O que fica fora, de proposito

- **Multiplayer.** Nao cabe na arquitetura e mudaria o modelo de dados do
  save inteiro.
- **Geracao procedural de fase.** O teste de balistica valida layouts escritos
  a mao.
- **Editor de fases dentro do jogo.** O layout vive no `.tscn` e isso esta
  certo.
- **i18n.** Descartado permanentemente.
- **Save-per-slot com bloqueio de fase.** Voce descartou; se mudar de
  ideia, e trabalho de UI.