# Plano — Etapa 2

Estado atual: 38 arquivos, ~2.720 linhas, 127 testes verdes, 8 commits.
Uma fase, um inimigo, zero assets de arte.

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

## Fase 1 — Conteúdo (3 a 4 dias)

### 1.1 Inimigo voador

O teste mais barato da arquitetura: se `Enemy` aguenta variação sem
reescrita, a arquitetura serve.

Novo `bat.gd` estende `Enemy` sobrescrevendo apenas:
- `_apply_vertical()` — zera a gravidade, aplica sustentação
- `_on_landed()` — não existe para voador, o que prova que o ponto de
  extensão funciona

Adicionar ao `Enemy` um gancho novo: `_can_fly` / `_vertical_mode`, para
não depender de sobrescrever método com nome interno.

### 1.2 Inimigo_atirador

Testa a **outra** metade do sistema de combate: dano à distância em vez de
contato.

Requer: projétil como `Area2D` reaproveitando `Hitbox`, telegrafia (0.4s
parado antes de atirar) e um estado novo `AIM` na FSM.

### 1.3 Segunda fase

O `SceneRouter` tem **um destino só** hoje. Nenhum `goto()` entre duas
fases jamais rodou — é exatamente onde fade travado e save corrompido vão
aparecer.

Nova fase com o oposto da primeira: corredores altos e estreitos, few
plataformas, mais voadores. Usar o `level_base` da 0.2.

Menu passa a ter seletor de fase (mostrar progresso por slot).

### 1.4 Coletável de valor

Hoje `coins_to_win` é um número solto na fase. Com duas fases a contagem
fica frágil — trocar `GameState.reset()` por objetivo declarado no level.

---

## Fase 2 — Sistema (3 a 4 dias)

### 2.1 Inventário e itens

`GameState.coins` é contador puro. Adicionar `items: Array[StringName]`
com um `Resource` de definition por item (nome, ícone, efeito). Isso é o
que transforma "coletável" em "sistema" e dá destino ao slot de save.

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
Fase 0  testes do FSM  ->  base da fase  ->  save/reset
Fase 1  voador -> atirador -> fase 2 -> coletável
Fase 2  inventário -> remapear -> acessibilidade -> i18n
Fase 3  feedback -> stats -> arte
```

Os dois primeiros itens da Fase 1 só fazem sentido depois da Fase 0, e a
Fase 2 inteira depende da Fase 1 existir para ter conteúdo que consuma.

---

## Risco

O item de maior risco é a **Fase 2.4 (i18n)**. É o único que toca todo
arquivo de uma vez e o único em que uma decisão errada (fazer tarde demais)
custa caro. Se o tempo apertar, é o primeiro a cortar — o resto é
adiável sem retrabalho.

O segundo é a **Fase 3.3 (arte)**: se você já tem preferência definida por
ferramenta de arte, o item vira dependência externa e precisa entrar antes.

---

## Sugestão de corte

Se for fazer só uma parte: **Fase 0 completa**. É pequena (1-2 dias) e é
o que permite adicionar conteúdo com segurança depois. Sem ela, cada
inimigo novo é um sistema sem rede.
