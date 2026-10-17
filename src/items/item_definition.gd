class_name ItemDefinition
extends Resource
## Defini��o de um item: o que ele � e o que fazer quando o jogador usa.
##
## `Resource` e n�o um `Dictionary` solto porque d� para salvar, comparar por
## identidade e -- quando vier arte -- apontar para um �cone sem mudar quem
## chama. As inst�ncias reais nascem em c�digo, em [ItemLibrary]: o projeto
## n�o tem pasta de assets e um `.tres` por item seria um arquivo para cada
## linha de dado.

enum Effect {
	## S� conta. N�o faz nada quando usado.
	NONE,
	## Cura o jogador em [member heal_amount].
	HEAL,
	## Soma pontos no [GameState].
	POINTS,
	## Dano radial ao redor do jogador.
	BOMB,
	## Invulnerabilidade por 3 s.
	SHIELD,
	## Atrai moedas num raio por 5 s.
	MAGNET,
}

## Identificador est�vel, gravado no save. N�o � o `display_name`: renomear o
## texto de um item n�o pode invalidar o progresso de quem j� o tinha.
@export var id: StringName = &""
## O que aparece na HUD.
@export var display_name := ""
## Cor do �cone desenhado em c�digo.
@export var tint := Color.WHITE
## Quanto o [GameState] ganha ao coletar.
@export var value := 0
@export var effect: Effect = Effect.NONE
## S� faz sentido para [constant Effect.HEAL].
@export var heal_amount := 0



## O item tem tudo o que o save precisa. Ver [member id] sobre por que isto
## n�o vive em `_init()`.
func is_valid() -> bool:
	return id != &"" and not display_name.is_empty()


func has_use() -> bool:
	return effect != Effect.NONE


## Aplica o efeito. `game_state` e `player` chegam prontos, em vez de vir dos
## autoloads: um `Resource` de dado que puxa `GameState` deixa de ser dado e
## vira um n� do jogo -- e � o que faz o runner de testes n�o conseguir
## carregar esta classe antes dos autoloads existirem.
func apply(game_state: Node, player: Node = null) -> void:
	if game_state == null:
		push_error("ItemDefinition.apply sem GameState -> %s" % id)
		return
	match effect:
		Effect.HEAL:
			game_state.call(&"heal", heal_amount)
		Effect.POINTS:
			game_state.call(&"add_score", value)
		Effect.BOMB:
			if player != null and player.has_method(&"do_bomb"):
				player.call(&"do_bomb")
		Effect.SHIELD:
			if player != null and player.has_method(&"activate_shield"):
				player.call(&"activate_shield")
		Effect.MAGNET:
			if player != null and player.has_method(&"activate_magnet"):
				player.call(&"activate_magnet")
		Effect.NONE:
			return
	# O `Player.on_item_used()` e o gancho de som; nao chamamos `heal()` dele
	if player != null and player.has_method(&"on_item_used"):
		player.call(&"on_item_used", self)


## Texto curto da barra de vida: o jogador precisa saber o que o item faz
## antes de gastar.
func effect_hint() -> String:
	match effect:
		Effect.HEAL:
			return "+%d de vida" % heal_amount
		Effect.POINTS:
			return "+%d de pontos" % value
		Effect.BOMB:
			return "Dano em área"
		Effect.SHIELD:
			return "Invulnerável por 3s"
		Effect.MAGNET:
			return "Atrai moedas 5s"
	return ""