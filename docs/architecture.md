# Arquitetura

## Visão geral

O jogo é divided em três camadas que só dependem uma da outra na direção certa:

```
scenes/    ->  src/  ->  autoload/
(cenas)        (sistemas)  (estado global)
```

- **`scenes/`** sabe *que* coisas existem (player, slime, checkpoint) e *quando*
  regras de jogo acontecem (a fase decide quando pausar, vencer ou morrer).
- **`src/`** tem a mecânica reutilizável e não conhece nenhuma cena concreta:
  dano, camadas, tremor de câmera, síntese de áudio.
- **`autoload/`** guarda o estado que precisa sobreviver à troca de cena.

Nenhum script em `src/` referencia uma cena. Nenhuma cena referencia o
`GameState` para fazer algo que não seja valor de jogo (contadores, vida).

## Fluxo de uma cena

```
main_menu.tscn  (cena principal do projeto)
    ├─ SceneRouter.goto("res://scenes/levels/level_01.tscn")
    │     └─ change_scene_to_file() + fade
    │          └─ level_01.tscn
    │               ├─ GameState.reset()        estado limpo a cada fase
    │               ├─ HUD.set_coin_goal(12)
    │               ├─ Player.died  ────────► EndScreen(vitória/derrota)
    │               └─ GameState.coins >= 12 ─► EndScreen
    └─ SceneRouter.goto("res://scenes/levels/level_02.tscn", &"level_02")
          └─ mesma mecânica, id diferente
```

As fases são resolvidas por **id** (`LevelRegistry`), não por caminho. O `Save`
grava `scene_id`, que sobrevive a renomear o arquivo, e o `SceneRouter` registra
todas as fases em um lugar só (`_register_levels()`).

## Autoloads

| Autoload | Classe | Responsabilidade |
|---|---|---|
| `GameState` | — | vida, moedas, pontos, flags. **Emite sinais**; quem quiser saber reage |
| `Save` | — | JSON versionado em `user://saves/<slot>.json`; `peek_level_id()` lê sem aplicar |
| `Settings` | — | preferências em `user://settings.cfg`, aplica no `Audio`/`DisplayServer` |
| `Audio` | `AudioManager` | toca, cria os buses `Music`/`SFX` em runtime |
| `SceneRouter` | — | troca de cena com fade |

`GameState` expõe `to_dict()`/`from_dict()`, então o `Save` não sabe nada sobre
vida ou moedas — só serializa e restaura o dicionário.

## Sistemas de `src/`

### Combate (`src/combat/`)

O padrão é **hitbox/hurtbox com detecção invertida**: a `Hitbox` só existe,
a `Hurtbox` é que monitora a camada e chama `apply_damage()` no dono.

```
Hitbox (layer HITBOX, monitorable ligado por 0.16s)
   -> Hurtbox (layer 0, mask = HITBOX) detecta area_entered
      -> chama owner.apply_damage(dano, fonte, direcao, knockback)
```

Por que invertido? Porque **quem recebe o golpe é quem tem i-frames, equipe e
imortalidade**. Se a Hitbox decidisse, todo inimigo teria que duplicar a
lógica de invulnerabilidade.

`apply_damage()` é duck typing (`has_method`), então qualquer corpo pode
participar sem herdar de nada.

O lado prático dessa escolha: um **projétil** (`scenes/props/projectile.gd`) é
uma `Hitbox` voando e não escreve uma linha de dano — ele se destrói em
`Hitbox.hit`, que é o sinal que a `Hurtbox` emite quando o golpe conecta.

### Camadas (`src/core/layers.gd`)

Constantes que espelham `[layer_names]` do `project.godot`. O teste
`tests/test_runner.gd` falha se as duas tabelas saírem de sincronia.

### Áudio (`src/audio/`)

Não há **nenhum arquivo de áudio no repositório**. `Sfx` e `Music` sintetizam
`AudioStreamWAV` na hora (quadrada/triangular/dente-de-serra/ruído, com
envelope) e guardam em cache estático. `AudioManager` cria os buses `Music` e
`SFX` em runtime, então também não existe `default_bus_layout.tres`.

Vantagens: repositório leve, sem pipeline de importação, e dá para afinar o
jogo mudando uma nota. O custo é que para áudio final gravado você substitui
por `Audio.play_sfx(preload("res://assets/audio/sfx/x.wav"))`.

`Sfx`/`Music` usam `AudioManager.instance` em vez do global `Audio` porque
`class_name` resolve em qualquer contexto, inclusive nos testes headless.

## Máquina de estados do inimigo

```
IDLE ──► PATROL ──► CHASE ──► AIM ──► ATTACK ──► STAGGER ──┐
 ▲         ▲          │                                  │
 └─────────┴──────────┴──────────────────────────────────┘
```

- A detecção exige **distância E linha de visão** (raycast na camada `WORLD`),
  então inimigo atrás de parede não persegue.
- `AIM` é a **telegrafia**: o inimigo congela encarando o alvo por 0,45 s antes
  de `_fire()`. Sem ela o tiro sai no mesmo quadro da decisão e o jogador não
  tem como reagir — isso não é dificuldade, é injustiça.
- `ATTACK` liga a hitbox e dá um `lunge`; ao sair entra em `STAGGER` — a janela
  em que o jogador pode revidar.

Os pontos de extensão são método, não flag: `_apply_vertical()` (como o corpo
sobe/desce), `_on_landed()` (o que fazer ao tocar o chão), `_fire()` (o que o
ataque realmente faz). Cada inimigo novo é uma classe com poucas linhas:

| Inimigo | O que sobrescreve | O que herda |
|---|---|---|
| `slime.gd` | `_apply_vertical()` (pula) e `_on_landed()` | FSM, detecção, linha de visão, combate |
| `bat.gd` | `flies = true` e `_apply_vertical()` (onda senoidal) | idem — e **não** sobrescreve `_on_landed()`, porque não tem chão |
| `archer.gd` | `_fire()` (cria um `Projectile`) e `_chase()` (para fora do alcance de contato) | idem, inclusive a telegrafia |

O `Projectile` (`scenes/props/`) não tem lógica de dano: é uma `Area2D` com uma
`Hitbox` dentro, e o dano chega pelo mesmo caminho do golpe corpo a corpo. Como
a detecção é invertida, ele não escuta `area_entered` — escuta
`Hitbox.hit`.

## Números de movimento (`src/player/player_tuning.gd`)

As constantes de movimento do player vivem fora do `player.gd`, em uma classe
sem autoloads. Dois motivos, ambos práticos:

1. O teste de balítica precisa da velocidade e da altura do pulo. Referenciar
   `Player.SPEED` de um teste arrastaria `player.gd` (que usa `GameState`) para
   dentro da compilação em modo `--script`, onde os autoloads ainda não são
   identificadores — e a carga do runner quebraria.
2. `max_jump_height()` e `jump_reach()` precisam morar junto dos números que
   medem, senão o level design e o teste passam a usar tabelas diferentes.

`player.gd` guarda apelidos (`const SPEED := PlayerTuning.SPEED`) para o corpo
do código continuar legível.

## Prova de que o level design funciona

`tests/test_runner.gd` fecha um grafo das plataformas de cada fase: uma
plataforma alcança outra quando a altura pedida cabe no pulo e o arco
horizontal encosta nela. A fase é considerada jogável quando **todas** as
plataformas e **todas** as moedas são alcançáveis a partir do `SpawnPoint`.

O modelo (`PlayerTuning.jump_reach`) é a balística real do pulo, incluindo o
`APEX_GRAVITY_SCALE`. O que ele ignora é a rampa de aceleração do jogador, que
só ajuda — então um vão acusado como impossível é impossível de verdade.

Esse teste já pegou duas plataformas órfãs na fase 1 que tornavam o jogo
invencível, e ele é verificado por controle negativo: mexer uma moeda de lugar
faz a suíte falhar.

## Decisões e trade-offs

| Decisão | Por quê |
|---|---|
| Co-localizar script e cena em `scenes/` | O script e a cena mudam juntos; nada de `player.gd` apontando para `player.tscn` do outro lado da árvore |
| Cena principal = menu | Evita uma cena de bootstrap que só redireciona |
| `Platform` monta o visual em código | Uma fase com 8 plataformas não vira 8 pares de sub-resources |
| Testes em `tests/`, não GUT | Roteiro próprio, sem dependência externa; roda em qualquer máquina com o binário do Godot |
| Sem assets de áudio | Ver acima. Trocável por `preload()` sem mudar quem chama |
| `Polygon2D` no lugar de sprites | Sem arte no repositório; a troca é substituir o nó `Sprite` e o script lê `$Sprite` |
| Estado do FSM comparado por **nome** | `Enemy.state_name()` sobrevive a reinserir um estado no enum; um índice literal mediria a coisa errada em silêncio |
| Objetivo da fase declarado no Inspector | `coins_to_win` + o guard `_check_goal_is_reachable()` avisam se a fase pede mais do que a cena tem |