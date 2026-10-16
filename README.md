# novo jogo

Plataforma 2D em **Godot 4.5** (GDScript, renderer *GL Compatibility*).
Protótipo completo: menu, pausa, opções, combate, inimigos com IA,
checkpoints, coletáveis, save/load e áudio sintetizado.

## Como rodar

**Pelo editor** — abra `project.godot` no Godot 4.5 e aperte `F5`.

**Pela linha de comando**

```powershell
& "C:\Users\Guilherme\Desktop\Godot_v4.5.1.exe" --path "D:\repositorios godot\novo-jogo"
```

Cena principal: `scenes/ui/main_menu.tscn`. Para pular direto para a fase:

```powershell
& "C:\Users\Guilherme\Desktop\Godot_v4.5.1.exe" --path "D:\repositorios godot\novo-jogo" "res://scenes/levels/level_01.tscn"
```

## Controles

| Ação | Teclado | Gamepad |
|---|---|---|
| Mover | `WASD` / setas | analógico esquerdo |
| Pular | `Espaço` | — |
| Dash | `Shift` | — |
| Atacar | botão esquerdo do mouse | — |
| Interagir | `E` | — |
| Pausar | `Esc` | — |
| Reiniciar a fase | `R` | — |

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
│   └── core/            # Layers
├── scenes/
│   ├── actors/
│   │   ├── player/      # player.gd + player.tscn
│   │   └── enemies/     # enemy.gd (FSM), slime.gd + slime.tscn
│   ├── levels/          # level_01.gd + level_01.tscn
│   ├── props/           # platform, coin, checkpoint, kill_zone
│   └── ui/              # main_menu, hud, pause_menu, options_panel, end_screen
├── tests/               # test_runner.gd
├── tools/               # dump_inputmap.gd (diagnostico)
├── docs/                # architecture.md, design.md
└── .github/workflows/   # ci.yml
```

Detalhes em [`docs/architecture.md`](docs/architecture.md) e
[`docs/design.md`](docs/design.md).

## Validação

```powershell
$godot = "C:\Users\Guilherme\Desktop\Godot_v4.5.1.exe"

# 116 verificacoes: Layers, InputMap, GameState, Save, audio e as 11 cenas
& $godot --headless --path . --script res://tests/test_runner.gd

# rodar o jogo 5 segundos sem erros nem avisos
& $godot --headless --path . --quit-after 300

# ver como o Input Map foi interpretado
& $godot --headless --path . --script res://tools/dump_inputmap.gd
```

Todos saem com código 0 quando está tudo certo — é o que o CI usa.

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