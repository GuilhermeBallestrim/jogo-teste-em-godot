# Plano — Etapa 2

Estado atual: duas fases, três inimigos, zero assets de arte, 218 verificações
verdes.

O objetivo desta etapa é sair de "protótipo demonstrável" para "jogo com
ciclo completo e estrutura que aguenta crescer". A ordem não é decorativa:
cada bloco destrava o próximo, e vários deles só fazem sentido depois do
anterior.

---

## Fase 0 — Fundação (1 a 2 dias)

### 0.1 Fechar a lacuna de teste do FSM

`Enemy` é o sistema mais complexo do projeto (6 estados, 3 transições
condicionais, detecção por raycast) e **não tem nenhum teste de
comportamento**. Os 127 checks são estruturais — instanciam cenas e medem a
física do player.

Enquanto isso não existir, qualquer inimigo novo entra sem rede.

- Instanciar `slime` e `player` num holder, sem cena
- Player parado perto e longe: verificar IDLE/PATROL → CHASE
- Raycast bloqueado: verificar que não persegue através de parede
- Ataque: verificar que a hitbox liga e que o dano chega ao player
- Morte: verificar `health <= 0` → `State.DEAD`, som pontua

### 0.2 Extrair o fluxo de fase — **feito**

`src/level/level_base.gd` (`LevelBase`) centraliza reset, pausa, vitória,
derrota, reinício e o banner de save. `level_01.gd` caiu para 8 linhas: só
o doc e o `LEVEL_ID`. O layout continua no `.tscn`.

Ponto de extensão para fases especiais: `check_extra_victory()` e
`notify()`.

### 0.3 Save com mais de uma fase — **feito**

- `src/level/level_registry.gd` (`LevelRegistry`) mapeia id estável ↔ caminho.
  O `Save` grava `scene_id`, que sobrevive a renomear o arquivo
- Fase declarada em um lugar só: `_register_levels()` no `SceneRouter`
- Save apontando para cena removida cai na fase padrão e expõe
  `last_scene_missing()`, que o menu usa para avisar em vez de fingir
- `reset_state_on_enter` no `LevelBase` define se a fase limpa o
  `GameState` — a fase 2 continua de onde a 1 parou
- `SAVE_VERSION` 1 → 2, com leitura da versão 1 legada (só tinha `scene_path`)
- `SceneRouter.reload()` resolve o id pelo path quando a cena foi aberta
  direto (F5), onde `current_scene_id` está vazio

---

## Fase 1 — Conteúdo — **feito**

### 1.1 Inimigo voador — **feito**

`scenes/actors/enemies/bat.gd` estende `Enemy` sobrescrevendo apenas
`_apply_vertical()` (onda senoidal em vez de gravidade) e ligando `flies`.
**Não** sobrescreve `_on_landed()`, porque não tem chão — o gancho existe e
fica sem uso, que é exatamente o que a 0.1 promete.

O gancho novo no `Enemy` é a propriedade `flies`: ligada, ela zera o
`floor_snap_length` (sem isso o motor gruda o voador na plataforma mais
próxima) e troca a gravidade por arrasto.

### 1.2 Inimigo atirador — **feito**

`scenes/props/projectile.gd` (`Projectile`) é uma `Area2D` com uma `Hitbox`
dentro: o dano vem do mesmo caminho do golpe corpo a corpo, sem uma linha
duplicada. Ele se destrói em `Hitbox.hit`.

`scenes/actors/enemies/archer.gd` sobrescreve `_fire()` para criar o projétil e
`_chase()` para atacar fora do alcance de contato. O estado novo `AIM` na FSM
(dentro do `Enemy`, não do `archer`) dá os 0,45 s de telegrafia — inclusive
para o slime, que agora mira antes de golpear.

### 1.3 Segunda fase — **feito**

`scenes/levels/level_02.tscn` (`level_02.gd`, 8 linhas) é o oposto da fase 1:
torres empilhadas em vez de corredores. Registrada em
`SceneRouter._register_levels()`.

O menu ganhou a lista de fases, montada a partir do `LevelRegistry` (adicionar
uma fase = uma linha no router). Cada botão que corresponde ao save recebe
"(continuar)", lido por `Save.peek_level_id()` sem carregar o `GameState`.

**Achei um bug grave no caminho:** o teste de balística das fases (ver 1.5)
mostrou que a fase 1 tinha duas plataformas órfãs que a tornavam
**invencível** — `Float2` e `Float4` ficavam 342 px e 402 px acima do chão, e o
pulo do player sobe 303 px. O layout das duas fases foi refeito com a balística
na mão.

### 1.4 Coletável de valor — **feito**

`Coin.value` (que já existia) ganhou companhia: `Coin.tint` para o visual
acompanhar, e o `LevelBase` passou a somar **valores** em vez de contar nós
(`count_remaining_value()`). A fase 2 tem 10 moedas, uma delas de valor 2, e
`coins_to_win = 11`.

`LevelBase._check_goal_is_reachable()` avisa no `push_warning` quando a fase
pede mais do que a cena soma: antes isso era um bug silencioso que deixava o
jogador preso para sempre.

### 1.5 Prova de que o level design funciona — **extra**

Não estava no plano, e virou o item mais útil da fase.

`tests/test_runner.gd` fecha um grafo das plataformas de cada fase usando a
balística real do pulo (`PlayerTuning.jump_reach`, que inclui o
`APEX_GRAVITY_SCALE`). Uma fase é jogável quando todas as plataformas e todas
as moedas são alcançáveis a partir do `SpawnPoint`. É um grafo, e não uma
comparação par a par, porque na fase 1 o caminho válido passa por plataformas
que, sozinhas, são altas demais para sair do chão.

Verificado por controle negativo: mover uma moeda 100 px para fora de alcance
faz a suíte falhar com o nome e a posição exatos.

---

## Fase 2 — Sistema (3 a 4 dias)

### 2.1 Inventário e itens

`GameState.coins` é contador puro. Adicionar `items: Array[StringName]`
com um `Resource` de definition por item (nome, ícone, efeito). Isso é o
que transforma "coletável" em "sistema" e dá destino ao slot de save.

O `Coin.value` e o `Coin.tint` da Fase 1.4 já são metade disso: falta a
tabela de itens e o consumo no `Player`.

### 2.2 Remapeamento de teclas

As 10 ações do Input Map já existem; falta a UI. `OptionsPanel` ganha uma
aba que captura o próximo evento e reescreve o InputMap, salvando em
`settings.cfg`.

### 2.3 Acessibilidade mínima

- Escala de UI (afeta `theme_override_font_sizes`)
- Reduzir tremor de câmera
- Modo alto contraste

### 2.4 Internacionalização

Todos os textos estão hardcoded em português. `tr()` + `en.po` + `pt.po`,
com fallback no idioma do sistema.

---

## Fase 3 — Polish (2 a 3 dias)

### 3.1 Feedback de combate

- Hitstop (congelar 2 frames no impacto)
- Knockback já existe; falta número decai no pulo
- Partículas de morte e de coleta
- Tremor de tela escalando com o dano

### 3.2 Stats de sessão

Tempo de fase, mortes, taxa de vitória, moedas por segundo. Guarda recordes
no `Save` e mostra na tela de vitória — é o que dá rejogar.

### 3.3 Arte mínima

Continua zero assets. Duas opcoes sem travar o desenvolvimento:
- **Geométrica em código** — `Polygon2D` com curvas e gradientes, no estilo
  atual, animada por código
- **Arte real** — você gera com IA de imagem, eu integro

Decidir depois que o jogo tiver forma. A troca é barata: o script lê
`$Sprite` por referência.

---

## Ordenação

```
Fase 0  testes do FSM  ->  base da fase  ->  save/reset      [feito]
Fase 1  voador -> atirador -> fase 2 -> coletável          [feito]
Fase 2  inventário -> remapear -> acessibilidade -> i18n
Fase 3  feedback -> stats -> arte
```

Os dois primeiros itens da Fase 1 só fazem sentido depois da Fase 0, e a
Fase 2 inteira depende da Fase 1 existir para ter conteúdo que consuma.

---

## Risco

O item de maior risco é a **Fase 2.4 (i18n)**. É o único que toca todo
arquivo de vez e o único em que uma decisão errada (fazer tarde demais)
custa caro. Se o tempo apertar, é o primeiro a cortar — o resto é
adiável sem retrabalho.

O segundo é a **Fase 3.3 (arte)**: se você já tem preferência definida por
ferramenta de arte, o item vira dependência externa e precisa entrar antes.

### Risco que já virou realidade

**Nível não testado é nível possivelmente impossível.** A fase 1 ficou weeks
sem ninguém perceber que não dava para terminar. O teste de balística (1.5)
existe para isso não voltar: qualquer `position` nova passa por ele.

A lição prática: o que não tem verificação automatizada precisa de uma
verificação manual — e manual não é o mesmo que feita.

---

## Sugestão de corte

A Fase 1 está feita. O próximo bloco que mais rende é a **Fase 2.1
(inventário)**: com três inimigos e um coletável de valor, o save tem um
formato para dar e o `Coin` já é a base do item. O 2.3 (acessibilidade) é o
melhor candidato a corte — nada trava e é adiável.
