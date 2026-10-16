# novo jogo

Jogo feito em **Godot 4.5** (GDScript, renderer *GL Compatibility*).

## Como rodar

Abra a pasta raiz no Godot 4.5 e rode (`F5`). A cena principal é
`scenes/main/main.tscn`.

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