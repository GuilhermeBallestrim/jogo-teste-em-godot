# novo jogo

Plataforma 2D em **Godot 4.5** (GDScript, renderer *GL Compatibility*).
Protótipo completo: menu com seletor de fase, pausa, opções, combate, três
tipos de inimigo, checkpoints, coletáveis, save/load e áudio sintetizado.

## Como rodar

**Pelo editor** — abra `project.godot` no Godot 4.5 e aperte `F5`.

**Pela linha de comando**

```powershell
& "C:\Users\Guilherme\Desktop\Godot_v4.5.1.exe" --path "D:\repositorios godot\novo-jogo"
```

Cena principal: `scenes/ui/main_menu.tscn`. Para pular direto para uma fase:

```powershell
& "C:\Users\Guilherme\Desktop\Godot_v4.5.1.exe" --path "D:\repositorios godot\novo-jogo" "res://scenes/levels/level_01.tscn"
& "C:\Users\Guilherme\Desktop\Godot_v4.5.1.exe" --path "D:\repositorios godot\novo-jogo" "res://scenes/levels/level_02.tscn"
```

## Controles

| Ação | Teclado | Gamepad |
|---|---|---|
| Mover | `A` `D` + `W` `S` / setas | analógico esquerdo |
| Pular | `Espaço` ou `W` | — |
| Dash | `Shift` | — |
| Atacar | botão esquerdo do mouse | — |
| Usar item | `E` | — |
| Pausar | `Esc` | — |
| Reiniciar a fase | `R` | — |

> `W` é só pulo. O movimento vertical fica nas setas ↑ ↓ e no analógico —
> evita que andar para cima dispare pulo sem parar.

## Estrutura

```
novo-jogo/
├── assets/              # audio, fontes, sprites (vazio por enquanto)
├── autoload/            # GameState, Save, Settings, Audio, SceneRouter
├── resources/           # ui_theme.tres
├── src/                 # codigo reutilizavel, sem dependencia de cena
│   ├── audio/           # Sfx e Music (sintetizam AudioStreamWAV)
│   ├── camera/          # camera_shake.gd
│   ├── combat/          # Hitbox, Hurtbox
│   ├── core/            # Layers
│   ├── items/           # ItemDefinition, ItemLibrary (catalogo)
│   ├── level/           # LevelBase (fluxo da fase), LevelRegistry (id <-> cena)
│   ├── player/          # PlayerTuning (numeros de movimento + balistica)
│   └── ui/              # Presentation (escala de texto, contraste)
├── scenes/
│   ├── actors/
│   │   ├── player/      # player.gd + player.tscn, player_rig (bone de 9 poses)
│   │   └── enemies/     # enemy.gd (FSM), slime, bat, archer
│   ├── levels/          # level_01, level_02
│   ├── props/           # platform, coin, item_pickup, checkpoint,
│   │                    # kill_zone, projectile, level_bounds
│   └── ui/              # main_menu, hud, pause_menu, options_panel, end_screen
├── tests/               # test_runner.gd + enemy_arena.gd
├── tools/               # dump_inputmap.gd, capture_rig.gd, capture_ui.gd
├── docs/                # architecture.md, design.md, roadmap.md
└── .github/workflows/   # ci.yml
```

Detalhes em [`docs/architecture.md`](docs/architecture.md),
[`docs/design.md`](docs/design.md), [`docs/roadmap.md`](docs/roadmap.md) e
[`docs/plano-evolucao.md`](docs/plano-evolucao.md).

## Validação

```powershell
.\exportar.ps1     # roda os testes e gera o executável -- use este
```

Ou direto:

```powershell
$godot = "C:\Users\Guilherme\Desktop\Godot_v4.5.1.exe"

# 335 verificacoes: Layers, InputMap, GameState, Save, inventario, audio,
# fisica do player, bone (9 poses distintas), FSM dos tres inimigos, guarda de
# borda, remapeamento, acessibilidade, balistica das fases e as cenas
& $godot --headless --path . --script res://tests/test_runner.gd

# rodar o jogo 5 segundos sem erros nem avisos
& $godot --headless --path . --quit-after 300

# ver como o Input Map foi interpretado
& $godot --headless --path . --script res://tools/dump_inputmap.gd
```

### Captura de tela

Duas ferramentas que rodam **sem** `--headless` (o renderizador headless é um
dummio e a imagem sai vazia) e salvam PNG em `user://capturas`:

```powershell
# as 9 poses do bone do player, lado a lado
& $godot --path . --resolution 1500x900 --script res://tools/capture_rig.gd

# menu, as 3 abas de opcoes, a fase, e a fase com texto grande / alto contraste
& $godot --path . --resolution 1280x720 --script res://tools/capture_ui.gd
```

As duas contam cores distintas na imagem salva. Um PNG em branco "salva" sem
erro nenhum, e é a checagem que separa "funcionou" de "funcionou e tem
conteúdo".

Todos saem com código 0 quando está tudo certo — é o que o CI usa.

> O binário do Godot no Windows é *GUI subsystem*: ele não escreve
> `$LASTEXITCODE`. Decida pelo conteúdo da saída (`TESTES: PASSARAM`), não
> pelo código.

## Autoloads

| Nome | Responsabilidade |
|---|---|
| `GameState` | vida, moedas, pontos e flags, propagados por sinais |
| `Save` | JSON versionado em `user://saves/<slot>.json` |
| `Settings` | volume e tela cheia em `user://settings.cfg` |
| `Audio` | toca; cria os buses `Music` e `SFX` em runtime |
| `SceneRouter` | troca de cena com fade |

## Convenções

- **Input** — só pelo Input Map (`Input.get_vector(&"move_left", ...)`),
  nunca teclas cruas.
- **Camadas de física 2D** — `World`, `Player`, `Enemy`, `Interactable`,
  `Hitbox`, `Hurtbox`. As constantes ficam em `src/core/layers.gd` e um teste
  falha se elas saírem de sincronia com o `project.godot`.
- **Dano** — quem *recebe* decide. A `Hitbox` só existe; a `Hurtbox` monitora e
  chama `apply_damage()` no dono.
- **Variação em vez de if** — inimigo novo é subclasse de `Enemy` que
  sobrescreve `_apply_vertical()` / `_on_landed()` / `_fire()`. Nenhum `if
  enemy_type == ...` no meio da FSM.
- **Números compartilhados** — constantes que mais de um arquivo precisa ficam
  em `src/`, não duplicadas. `src/` nunca referencia autoload: um `Resource`
  de dado que puxa `GameState` deixa de ser dado e quebra o runner de testes.
- **Ver o que se fez** — problema de layout, de contraste ou de pose não se
  resolve lendo o código. `tools/capture_*.gd` tira a foto.
- **GDScript** — nunca combine tipo explícito com `:=` (`var x: int := 5` é
  erro de parse; use `=` com tipo declarado ou `:=` sem tipo).
- **Nomes** — `snake_case` em arquivos e variáveis, `PascalCase` em classes e
  nós de cena.
- **Commit** — um commit por mudança coesa.

## Git

```bash
git status
git add .
git commit -m "chore: estrutura inicial do projeto"
```

`.godot/`, builds e arquivos exportados são ignorados — nunca versionar.