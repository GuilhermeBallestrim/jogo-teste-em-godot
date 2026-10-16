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
   └─ SceneRouter.goto("res://scenes/levels/level_01.tscn")
        └─ change_scene_to_file() + fade
             └─ level_01.tscn
                  ├─ GameState.reset()        estado limpo a cada fase
                  ├─ HUD.set_coin_goal(12)
                  ├─ Player.died  ────────► EndScreen(vitória/derrota)
                  └─ GameState.coins >= 12 ─► EndScreen
```

## Autoloads

| Autoload | Classe | Responsabilidade |
|---|---|---|
| `GameState` | — | vida, moedas, pontos, flags. **Emite sinais**; quem quiser saber reage |
| `Save` | — | JSON versionado em `user://saves/<slot>.json` |
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
IDLE ──► PATROL ──► CHASE ──► ATTACK ──► STAGGER ──┐
 ▲         ▲          │                            │
 └─────────┴──────────┴────────────────────────────┘
```

- A detecção exige **distância E linha de visão** (raycast na camada `WORLD`),
  então inimigo atrás de parede não persegue.
- `ATTACK` liga a hitbox e dá um `lunge`; ao sair entra em `STAGGER` — a janela
  em que o jogador pode revidar.
- `slime.gd` herda tudo e só sobrescreve `_apply_vertical()`, trocando
  caminhada por pulos. Outro inimigo de outro tipo é uma classe nova com
  poucas linhas.

## Decisões e trade-offs

| Decisão | Por quê |
|---|---|
| Co-localizar script e cena em `scenes/` | O script e a cena mudam juntos; nada de `player.gd` apontando para `player.tscn` do outro lado da árvore |
| Cena principal = menu | Evita uma cena de bootstrap que só redireciona |
| `Platform` monta o visual em código | Uma fase com 8 plataformas não vira 8 pares de sub-resources |
| Testes em `tests/`, não GUT | Roteiro próprio de ~300 linhas, sem dependência externa; roda em qualquer máquina com o binário do Godot |
| Sem assets de áudio | Ver acima. Trocável por `preload()` sem mudar quem chama |
| `Polygon2D` no lugar de sprites | Sem arte no repositório; a troca é substituir o nó `Sprite` e o script lê `$Sprite` |