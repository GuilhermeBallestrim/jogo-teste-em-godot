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
| Interagir | `E` | — |
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
│   ├── level/           # LevelBase (fluxo da fase), LevelRegistry (id <-> cena)
│   └── player/          # PlayerTuning (numeros de movimento + balistica)
├── scenes/
│   ├── actors/
│   │   ├── player/      # player.gd + player.tscn
│   │   └── enemies/     # enemy.gd (FSM), slime, bat, archer
│   ├── levels/          # level_01, level_02
│   ├── props/           # platform, coin, checkpoint, kill_zone, projectile
│   └── ui/              # main_menu, hud, pause_menu, options_panel, end_screen
├── tests/               # test_runner.gd + enemy_arena.gd
├── tools/               # dump_inputmap.gd (diagnostico)
├── docs/                # architecture.md, design.md, roadmap.md
└── .github/workflows/   # ci.yml
```

Detalhes em [`docs/architecture.md`](docs/architecture.md),
[`docs/design.md`](docs/design.md) e [`docs/roadmap.md`](docs/roadmap.md).

## Validação

```powershell
.\exportar.ps1     # roda os testes e gera o executável -- use este
```

Ou direto:

```powershell
$godot = "C:\Users\Guilherme\Desktop\Godot_v4.5.1.exe"

# 218 verificacoes: Layers, InputMap, GameState, Save, audio, fisica do player,
# FSM dos tres inimigos, balistica das duas fases e as 14 cenas
& $godot --headless --path . --script res://tests/test_runner.gd

# rodar o jogo 5 segundos sem erros nem avisos
& $godot --headless --path . --quit-after 300

# ver como o Input Map foi interpretado
& $godot --headless --path . --script res://tools/dump_inputmap.gd
```

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
  em `src/`, não duplicadas.
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