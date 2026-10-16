# novo jogo

Jogo feito em **Godot 4.5** (GDScript, renderer *GL Compatibility*).

## Como rodar

Abra a pasta raiz no Godot 4.5 e rode (`F5`). A cena principal é
`scenes/main/main.tscn`, que instancia o nível de protótipo.

## Controles

| Ação | Teclado | Gamepad |
|---|---|---|
| Mover | `WASD` / setas | analógico esquerdo |
| Pular | `Espaço` | — |
| Dash | `Shift` | — |
| Interagir | `E` | — |
| Atacar | botão esquerdo do mouse | — |
| Pausar | `Esc` | — |
| Reiniciar | `R` | — |

## Autoloads

| Nome | Arquivo | Responsabilidade |
|---|---|---|
| `GameState` | `autoload/game_state.gd` | vida, moedas, pontos e flags da sessão, via sinais |
| `Save` | `autoload/save_manager.gd` | persistência em `user://saves/<slot>.json` com versão |
| `Audio` | `autoload/audio_manager.gd` | música com crossfade e pool de 8 vozes de SFX |
| `SceneRouter` | `autoload/scene_router.gd` | troca de cena com fade |

## Validação

Smoke test (não precisa abrir o editor, sai com código != 0 em caso de falha):

```powershell
godot --headless --path . --script res://tools/smoke_test.gd
```

Ele confere o Input Map, os autoloads, o carregamento da cena principal, o
ciclo de sinais do `GameState` e um ida-e-volta de save.

## Estrutura de pastas

```
novo-jogo/
├── assets/              # assets globais compartilhados
│   ├── audio/music/     # músicas de fundo
│   ├── audio/sfx/       # efeitos sonoros
│   ├── fonts/           # fontes (.ttf/.otf)
│   ├── sprites/         # sprites e texturas 2D
│   └── ui/              # imagens, ícones e temas da interface
├── autoload/            # singletons (GameState, Audio, SceneRouter, Save)
├── resources/           # Resources customizados (.tres): itens, quests, config
├── src/                 # código de sistemas reutilizáveis, sem vínculo com cena
├── scenes/
│   ├── main/            # cena principal e menus de topo
│   ├── actors/          # player, inimigos, NPCs (cena + script no mesmo lugar)
│   ├── levels/          # fases
│   ├── props/           # objetos de cenário reutilizáveis
│   └── ui/              # HUD, menus e pop-ups reutilizáveis
├── tests/               # testes automatizados (GUT)
├── tools/               # scripts de editor e de build
├── docs/                # documentação e notas de design
└── addons/              # plugins do Godot
```

**Convenção:** cenas e scripts ficam **co-localizados por feature** dentro de
`scenes/`. Só vai para `src/` o código genérico que não pertence a nenhuma cena.

## Convenções

- **Input** — sempre via `Input.get_vector(&"move_left", &"move_right", ...)`
  usando as ações do Input Map; nunca ler teclas direto.
- **Camadas de física 2D** — `World`, `Player`, `Enemy`, `Interactable`,
  `Hitbox`, `Hurtbox`.
- **GDScript** — nunca combine tipo explícito com `:=` (`var x: int := 5` é
  erro de parse); use `=` com tipo declarado ou `:=` sem tipo.
- **Nomes** — `snake_case` para arquivos e variáveis, `PascalCase` para classes
  e nós de cena (`Player`, `EnemySlime`).
- **Commit** — um commit por mudança coesa.

## Git

```bash
git status
git add .
git commit -m "chore: estrutura inicial do projeto"
```

`.godot/`, builds e arquivos exportados são ignorados — nunca versionar.