# Plano de evolução

Roadmap de features depois da Fase 2. Nao e promessa -- e ordem sugerida com o

## Status

**Onda 1 (o jogo acorda) esta pronta.** Camera com antecipacao,
hitstop, numero de dano, tremor escalado com o dano, poeira, respingo,
rastro do dash e estouro na morte do inimigo. Tres coisas mudaram de
ideia no meio do caminho -- ver `docs/roadmap.md` secao "Onda 1".

Onda 2 (stats, slots, mais verbos) e Onda 3 (editor de layout, mais
inimigos, mais fases) continuam pendentes.

motivo de cada passo e como verificar que ficou bom.

Tamanhos são relativos: **P** = um dia de trabalho, **M** = dois ou três,
**G** = uma semana. Não são estimativas de calendário: dependem de quantas
horas você quer investir por semana.

---

## A regra que organiza tudo

**Cada onda faz o jogo parecer mais finished, não maior.**

A tentação com feature é crescer de número (mais fases, mais inimigos, mais
itens). O que faz um protótipo virar jogo é o oposto: fechar o que já existe.
Uma câmera que antecipa o movimento vale mais que uma quarta fase, porque
afeta todas elas.

Exceção: quando você tem certeza do que falta é *conteúdo*, pule para a Onda 3.

---

## Onda 1 — O jogo acorda

Nenhuma dependência. Pode começar hoje, em qualquer ordem dentro da onda.
**Comece por A.**

### A. Camera com antecipacao - **feito**

**Por quê.** A `Camera2D` hoje segue o player rigidamente. Antecipar na direção
do movimento e dar um zoom de leve durante o dash é a mudança mais barata que
mais altera a sensação de um jogo de plataforma. Ela afeta todas as fases
existentes.

**Onde.**
- `scenes/actors/player/player.tscn` → `Camera2D`
- `scenes/actors/player/player.gd` → novo `_update_camera(delta)`
- `src/camera/` → um `camera_rig.gd` (PD sobre a posição alvo), no mesmo
  espírito do `camera_shake.gd`

**Decisão.** Antecipação suavizada (lerp até o alvo) ou direta? Direita é mais
snappy e mais fácil de sentir o efeito; suavizada parece mais "cara" e
esconde o movimento. Eu escolheria direta, com limite de distância.

**Verificar.** Não dá para testar antecipação em teste headless — é leitura,
não regra. É captura de tela: `tools/capture_ui.gd` com o player correndo para
a direita e para a esquerda. E é jogar.

**Cuidado.** A antecipação não pode furar os `limit_*` da câmera, nem empurrar
o bone para fora da tela nas bordas estreitas da fase 2.

### B. Feedback de combate - **feito**

**Por quê.** O golpe pega, tira vida e acende uma partícula. Não tem peso.

**Onde.**
- `src/combat/hitbox.gd` → `Hitbox.notify_hit()` é o ponto único onde todo
  golpe conecta. Emitir um sinal novo aqui serve corpo a corpo e projétil sem
  duplicar nada.
- `src/core/` → um `hitstop.gd` (congela a física por N quadros). Precisa
  pausar `_physics_process`, não o `tree` inteiro — pausar tudo quebraria o
  tween da câmera.
- `scenes/actors/player/player.gd` → número decai subindo, e tremor escalando
  com o dano (hoje `shake_for(0.8)` é fixo)

**Ordem dentro do bloco.** Hitstop → número flutuante → tremor escalado.
O número é o mais visível e o mais fácil; faça-o mesmo se o resto atrasar.

**Verificar.** Teste de hitstop (o `Enemy` não anda por 2 quadros após levar
golpe) é determinístico e vale escrever. O número e o tremor são leitura —
captura de tela.

### C. Particulas e efeitos - **feito**

**Por quê.** O único `CPUParticles2D` do projeto é o faísca do golpe do
player. Poeira ao correr, respingo ao aterrissar, rastro no dash e explosão na
morte do inimigo são quatro `CPUParticles2D` — nenhuma lógica nova.

**Onde.** `player.tscn`, `enemy.tscn`, `platform.tscn`.

**Cuidado.** `CPUParticles2D` é mais pesado que `GPUParticles2D` se houver
muitas instâncias. Com o teto de ~10 inimigos da fase 2, não é problema.

**Verificar.** Captura de tela com a fase rodando 15 s (que `capture_ui.gd` já
faz) e contar as partículas na imagem.

---

## Onda 2 — O jogador tem motivo para voltar

### D. Stats de sessão — **M** (roadmap 3.2)

**Por quê.** Hoje a tela de vitória mostra moedas e pontos. Tempo de fase,
mortes e uma avaliação (S/A/B/C) é o que dá vontade de repetir.

**Onde.**
- `src/core/session_stats.gd` (novo) — acumulador puro, sem autoload. Segue o
  mesmo padrão do `PlayerTuning`: dados que o teste usa sem compilar script de
  gameplay.
- `scenes/levels/level_base.gd` → começa a contar em `_ready`, zera em
  `reset_state_on_enter`
- `scenes/ui/end_screen.gd` → mostra as três stats e a avaliação
- `autoload/save_manager.gd` → recordes por nível

**Depende de nada.** Mas vale **depois** de B e C: a tela de vitória fica mais
interessante depois que o combate tem peso.

**Verificar.** Teste puro do `session_stats` (contador, avaliação, freeze de
recorde). A exibição é leitura.

### E. Save por slot e hub — **G**

**Por quê.** Um slot só, sem trava entre fases. É o que impede o jogador de
voltar ao que fez semana passada.

**Onde.**
- `autoload/save_manager.gd` → `list_slots()` já existe e não é usado por
  nada. A infraestrutura de slot está pronta; falta a UI.
- `scenes/ui/main_menu.tscn` → lista de slots, criar/apagar, escolher fase
  inicial e fase final
- `src/level/level_registry.gd` → a fase que destrava a próxima

**Depende de D** no-sequence, não tecnicamente: o hub mostra recordes, então
fica mais útil depois das stats existirem.

**Verificar.** Teste de save por slot (gravar, trocar de slot, voltar, ler de
novo) e a lista aparecer na captura de tela do menu.

### F. Combate com mais verbos — **G**

**Por quê.** O jogo tem pular, dash e um golpe. Falta o que dá decisão dentro
da briga.

**Onde.** `scenes/actors/player/player.gd` e `src/combat/hitbox.gd`. O sistema
já suporta: ataque pesado é o mesmo golpe com mais tempo ativo e mais
knockback; ataque aéreo é um `Hitbox` em posição diferente; parry inverte o
`direction` que a `Hurtbox` passa.

**Depende de B** — sem hitstop, parry nao tem forca nem peso.

**Verificar.** Teste de parry (golpeio no parry inverte o dano e não tira
vida). É a mesma infraestrutura do teste de dano que já existe.

---

## Onda 3 — Duração de conteúdo

**Só entre aqui se você decidir que o problema é ter pouco conteúdo.**

### I. Editor visual de layout — **M** — antes de J e K

**Por quê.** Hoje o teste de balística diz *se* um layout funciona, não *como
consertar*. Uma ferramenta que desenha o arco do pulo sobre a fase converte
"passa/falha" em "olha e ajusta". Sem ela, desenhar 8 plataformas por fase é
tentativa e erro.

**Onde.** `tools/preview_level.gd` (novo), irmão de `capture_*.gd`. Roda com
janela, desenha o arco de cada salto possível a partir de cada plataforma.

**Verificar.** Não precisa de teste. Precisa existir e ser usada.

### J. Mais inimigos — **M** por inimigo

**Por quê.** A arquitetura já provou que aceita variação: `bat` (voa),
`archer` (atira), `slime` (pula). Cada novo é ~20 linhas sobrescrevendo
`_apply_vertical()`, `_fire()` ou `_on_landed()`.

**Candidatos** que exercitam caminhos ainda não testados:
- **Escorre** — ignora `platform_thin`, exige `has_ground_ahead` só para chão
  grosso. Testa o gancho de borda por baixo.
- **Explosivo** — ao morrer, `Area2D` radial com dano. Testa o caminho de dano
  que não vem de `Hitbox`.
- **Guarda** — só ataca quando o jogador está em intervalo, senão patrulha.
  Testa uma IA que espera.

**Depende de I** para o layout da fase continuar fácil de ajustar.

**Verificar.** Uma suíte de FSM por inimigo, como as três existentes. O
`EnemyArena` já monta tudo.

### K. Mais fases — **P** por fase, com layout de dia

**Por quê.** A `LevelBase` + `LevelRegistry` já suportam quantas você quiser.
Adicionar uma fase hoje é: um `.tscn`, um `.gd` de 8 linhas, uma linha no
`SceneRouter`, e o menu passa a pickar automaticamente.

**Depende de I** (validar o layout) e de J (conteúdo para a fase ter ameaça).

**Verificar.** O teste de balística e o de "inimigos não caem" já rodam sobre
`LEVELS` — acrescentar o caminho e pronto.

---

## Investimento em infraestrutura

Custam pouco agora e pagam depois. Vale entrar **antes** da Onda 3: e
ali que eles deixam de ser investimento.

### H. Teste de input real — **M**

**Por quê.** É a maior mentira não coberta do projeto: todo o movimento é
verificado com `Input.get_vector` direto, nunca com teclado de verdade. Todo
comportamento do player passa nos testes, mas "funciona com o teclado" é
afirmação não verificada.

**Onde.** `tests/` — um script que abre uma janela, injeta eventos de teclado
reais e confere o resultado. Precisa rodar fora do `--headless`, como
`capture_*.gd`.

**Verificar.** Ele mesmo: um teste que passa é a prova de que o caminho real
funciona.

### L. Arte — **G** — **decisão antes de começar**

**Por quê.** É a única dependência externa do plano. Se você quer arte real
gerada por IA, ela tem que entrar **antes** da Onda 3, senão o layout das
fases é desenhado para bone de `Polygon2D` e jogado fora.

**Duas saídas, e elas não são equivalentes:**
- **Geométrica em código** (continuar como está): o `PlayerRig` provou que
  9 poses legíveis cabem sem um arquivo de imagem. Inimigo e cenário ainda são
  chapados, e um sistema de desenho com gradiente e curva levaria os dois ao
  mesmo nível do bone.
- **Arte importada**: mais bonito em metade do tempo, e entra uma dependência
  de arquivo que precisa versionar, importar e reexportar.

---

## Ordem sugerida

```
Onda 1   A camera  →  B feedback  →  C particulas
Onda 2   D stats   →  E slots/hub  →  F combate
Onda 3   I editor de layout  →  J inimigos  →  K fases
Paralelo H input real (antes da Onda 3)
Decisao  L arte (antes da Onda 3, se for arte importada)
```

A ordem dentro de cada onda importa menos do que a ordem entre elas: Onda 1
antes de 2 porque 2 muda telas que 1 deixa mais bonitas; Onda 2 antes de 3
porque conteúdo novo em fases sem feedback é conteúdo novo sem motivo para
jogar de novo.

---

## Cortes, em ordem

Se precisar parar no meio, corte nesta ordem — cada um é removível sem
quebrar o que ficou:

1. **L (arte)** — nunca foi prometida, e o bone prova que não é obrigatória.
2. **K (fases)** — a última fase extra é a de menor retorno se as anteriores
   forem boas.
3. **F (combate com mais verbos)** — pular e dash já dão o suficiente.
4. **E (slots)** — um slot só funciona; é comodidade.
5. **C (partículas)** — o jogo funciona sem elas, só fica mais seco.

**Não corte** A, B, D nem H. A e B são o que faz o protótipo parecer jogo; D
e H são o que faz o trabalho ser confiável.

---

## O que fica fora, de propósito

- **Multiplayer.** Não cabe na arquitetura (tudo é estado local num
  `GameState`) e mudaria o modelo de dados do save inteiro.
- **Geração procedural de fase.** O teste de balística valida layouts escritos
  a mão. Fase gerada precisa de validação que não existe ainda.
- **Editor de fases dentro do jogo.** O layout vive no `.tscn` e isso está
  certo: é versionável, revisável e o teste de balística o lê direto.
