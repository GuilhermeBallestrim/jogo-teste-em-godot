# Plano de correcoes

Bug report do usuario (pos-Onda 6). Antes de executar qualquer codigo,
este documento descreve causa raiz, correcao e verificacao de cada item.

## 1. Sem guia de botoes

**Causa.** Nao existe tela de ajuda. A aba "Controles" do `OptionsPanel`
lista as acoes remapeaveis, mas nao mostra o botao padrao nem as acoes
que nao sao remapeaveis (parry, usar item, pausar, reiniciar). O jogador
nao tem como saber o que cada tecla faz sem abrir o menu de opcoes.

**Correcao.**
- Adicionar uma secao "Como jogar" no menu principal (ou tela dedicada)
  com a lista completa de acoes e seus botoes padrao.
- Atualizar `ACTION_LABELS` no `options_panel.gd` para incluir `parry`
  (hoje falta).
- Adicionar `parry` ao `REMAPPABLE` do `Settings` se ainda nao estiver.

**Arquivos.** `scenes/ui/main_menu.gd`, `scenes/ui/main_menu.tscn`,
`scenes/ui/options_panel.gd`, `autoload/settings_manager.gd`.

**Verificar.** Captura de tela do menu + teste de que todas as acoes
remapeaveis aparecem na lista.

## 2. Fase 2 bloqueada apos completar / 9. Unlock nao persiste

**Causa raiz.** `GameState.reset()` limpa `_completed_levels` e
`_abilities`. Quando o jogador termina uma fase e clica em "Jogar de
novo" (que chama `GameState.reset()`), ou quando volta ao menu, o estado
de progresso e apagado. Alem disso, `is_level_unlocked()` consulta o
GameState em memoria, nao o Save. Se o GameState foi resetado, todos os
niveis voltam a bloqueados.

**Correcao.**
- Separar "estado de sessao" (vida, moedas, score, itens) de "progresso"
  (completed_levels, abilities). `reset()` limpa so a sessao.
- Adicionar `GameState.load_progress_from_save()` que le completed_levels e
  abilities do Save ativo.
- No `_ready()` do MainMenu, carregar o progresso do Save ativo.
- `_build_level_list()` consulta `GameState.is_level_unlocked()` (que agora
  persiste).

**Arquivos.** `autoload/game_state.gd`, `scenes/ui/main_menu.gd`,
`autoload/save_manager.gd`.

**Verificar.** Teste: completar level_01, resetar sessao, verificar que
level_02 continua desbloqueado. Teste de save roundtrip.

## 3. Bossfight desfuncional

**Causa.** O boss entra em CHASE e nao sai (o teste mostrou "ultimo
estado: CHASE" com 300 frames). A IA provavelmente nao transiciona para
ATTACK/AIM porque `_target` e null ou `_sees_target` retorna false, ou o
`_state_timer` nao avanca.

Alem disso, o jogador "nao consegue atacar" -- provavelmente porque o
boss esta em CHASE e o player nao tem como acertar (boss se move rapido
ou a hitbox nao conecta).

**Correcao.**
- Revisar o `_think` do boss: garantir que IDLE -> proximo padrao acontece.
- Garantir que o boss nao se move durante ATTACK/AIM (velocity = 0).
- Garantir que a hitbox do player alcanca o boss (posicao, alcance).
- Adicionar telegraph visual claro (cor/escala) antes de cada ataque.
- Reduzir a velocidade do charge.

**Arquivos.** `scenes/actors/enemies/boss.gd`, `scenes/actors/enemies/boss.tscn`.

**Verificar.** Teste de FSM do boss (ja existe, mas falha). Captura de
tela da bossfight.

## 4. Hitboxes confusas

**Causa.** As hitboxes sao `Area2D` invisiveis. O jogador e os inimigos
nao conseguem ver onde o golpe conecta. A confusao vem de:
- Hitbox do player em `position.x = ATTACK_REACH * facing` (offset invisivel).
- Hitbox do inimigo em `position.x = 26` (offset invisivel).
- Nenhum indicador visual de alcance.

**Correcao.**
- Adicionar visual debug (Polygon2D semi-transparente) nas hitboxes quando
  em modo debug, ou sempre em desenvolvimento.
- Alternativa: tornar a hitbox visivel com uma cor sutil (azul para player,
  vermelho para inimigo) com alpha baixo.
- Garantir que a hitbox do player tem o mesmo alcance visual do swing.

**Arquivos.** `src/combat/hitbox.gd`, `scenes/actors/player/player.tscn`,
`scenes/actors/enemies/*.tscn`.

**Verificar.** Captura de tela com hitbox visivel. Teste de que o golpe
conecta no alcance certo.

## 5. Botao "Jogar" nao funciona + refazer menu

**Causa.** `_on_play()` chama `GameState.reset()` e `SceneRouter.goto()`.
Pode falhar se `LevelRegistry.default_id()` retornar vazio ou se o path
nao existir. Alem disso, o menu mistura slots, niveis, play, continue e
opcoes sem hierarquia clara.

**Correcao.**
- Refazer o menu principal: hierarquia clara (Jogar, Continuar, Slots,
  Opcoes, Sair). Remover a lista de niveis do menu (mover para o hub).
- Corrigir `_on_play()` para ir para a primeira fase desbloqueada.
- Adicionar feedback visual (botao desabilitado quando nao ha save para
  "Continuar").

**Arquivos.** `scenes/ui/main_menu.gd`, `scenes/ui/main_menu.tscn`.

**Verificar.** Teste de que "Jogar" leva para level_01. Captura de tela.

## 6. Nao morre ao cair + mapas retos

**Causa.** `KillZone._on_body_entered` chama `GameState.take_damage(damage)`.
Se `health <= 0`, `take_damage` retorna cedo e nao respawna. O jogador
fica preso na zona de morte.

Alem disso, os niveis tem buracos (gaps entre plataformas) onde o jogador
pode cair.

**Correcao.**
- KillZone: se health <= 0 apos o dano (ou se ja era 0), chamar
  `_player._die()` ou emitir `died`. Sempre respawnar se sobreviver.
- Tornar as fases "retas": ground continuo cobrindo toda a largura, sem
  gaps onde o jogador pode cair e ficar preso. Plataformas flutuantes
  podem existir, mas o chao principal e continuo.
- Remover ou reduzir buracos nos 4 niveis.

**Arquivos.** `scenes/props/kill_zone.gd`, `scenes/levels/level_*.tscn`.

**Verificar.** Teste: cair no buraco com 1 HP -> morrer. Teste: cair no
buraco com 100 HP -> respawn com 75 HP. Captura de tela dos niveis.

## 7. Inimigos morrem sozinhos

**Causa.** Possivelmente o `_guard_offscreen` teleportando o inimigo
para casa (parece morte visual). Ou o dano acumulado de um hit que tira
metade da vida + o knockback empurrando para um buraco onde o KillZone
mata. Ou um bug no stagger onde o inimigo entra em DEAD sem health <= 0.

**Correcao.**
- Investigar: adicionar log temporario em `_die` para ver quando e por
  que morre.
- Verificar se `health` esta sendo decrementado corretamente.
- Se for knockback + queda, a correcao #6 (mapas retos) resolve.

**Arquivos.** `scenes/actors/enemies/enemy.gd`.

**Verificar.** Teste: bater no inimigo uma vez, esperar 5s, verificar que
health nao mudou.

## 8. Itens confusos

**Causa.** Os itens tem `effect_hint()` mas pode nao estar sendo exibido.
A funcao do item nao e clara no pickup nem na HUD.

**Correcao.**
- Mostrar `effect_hint()` no pickup (label flutuante) e na HUD (tooltip).
- Adicionar icones visuais distintos por item (cor + forma).
- Adicionar descricao curta no pickup.

**Arquivos.** `src/items/item_definition.gd`, `scenes/props/item_pickup.tscn`,
`scenes/ui/hud.gd`.

**Verificar.** Captura de tela do pickup e da HUD.

## 10. Slots de save confusos

**Causa.** A UI de slots e basica: lista de nomes + "x" + "+ Novo slot".
Nao mostra qual slot tem progresso, qual e o ativo, nem permite renomear.

**Correcao.**
- Mostrar informacao util por slot: nome, fase atual, nota, data.
- Destacar o slot ativo visualmente.
- Permitir renomear (ou gerar nomes mais descritivos).
- Remover a secao de slots do menu principal se for muito confuso; mover
  para uma tela dedicada "Gerenciar saves".

**Arquivos.** `scenes/ui/main_menu.gd`, `scenes/ui/main_menu.tscn`.

**Verificar.** Captura de tela do menu.

## 11. Sem acentuacao

**Causa.** Todos os strings no codigo e nas cenas usam ASCII (sem
acentos). E uma escolha inicial que agora o usuario quer corrigir.

**Correcao.**
- Passar por todos os `.gd` e `.tscn` e adicionar acentos nos strings
  visiveis ao jogador.
- Arquivos mais afetados: `end_screen.gd`, `main_menu.gd`, `hud.gd`,
  `options_panel.gd`, `level_base.gd` (warnings), `item_definition.gd`
  (hints), `enemy.gd` (nomes), `floating_number.gd`.
- ~200 strings para revisar. Mecanico, mas tedioso.

**Verificar.** Captura de tela + busca por strings sem acento em textos
visiveis.

---

## Ordem sugerida

1. **Acentuacao (11)** - mecanico, sem risco, melhora tudo.
2. **Progresso persistente (2, 9)** - bug real, afeta a experiencia.
3. **Mapas retos + morte ao cair (6)** - bug real + mudanca de design.
4. **Inimigos morrem sozinhos (7)** - depende de #6.
5. **Bossfight (3)** - bug real de gameplay.
6. **Hitboxes (4)** - melhoria de clareza.
7. **Menu principal (5)** - refazer.
8. **Guia de botoes (1)** - depende do menu.
9. **Itens claros (8)** - melhoria de UX.
10. **Slots de save (10)** - melhoria de UX.

## O que NAO vou fazer sem aprovacao

- Mudar a mecanica de combate (dano, cooldown, etc.).
- Adicionar novos inimigos ou itens (isso e conteudo, nao correcao).
- Refatorar a arquitetura (esta estavel, 450 testes verdes).