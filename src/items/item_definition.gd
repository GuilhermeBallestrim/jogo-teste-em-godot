class_name ItemDefinition
extends Resource
## Definição de um item: o que ele é e o que fazer quando o jogador usa.
##
## `Resource` e não um `Dictionary` solto porque dá para salvar, comparar por
## identidade e -- quando vier arte -- apontar para um ícone sem mudar quem
## chama. As instâncias reais nascem em código, em [ItemLibrary]: o projeto
## não tem pasta de assets e um `.tres` por item seria um arquivo para cada
## linha de dado.

enum Effect {
	## Só conta. Não faz nada quando usado.
	NONE,
	## Cura o jogador em [member heal_amount].
	HEAL,
	## Soma pontos no [GameState].
	POINTS,
}

## Identificador estável, gravado no save. Não é o `display_name`: renomear o
## texto de um item não pode invalidar o progresso de quem já o tinha.
@export var id: StringName = &""
## O que aparece na HUD.
@export var display_name := ""
## Cor do ícone desenhado em código.
@export var tint := Color.WHITE
## Quanto o [GameState] ganha ao coletar.
@export var value := 0
@export var effect: Effect = Effect.NONE
## Só faz sentido para [constant Effect.HEAL].
@export var heal_amount := 0



## O item tem tudo o que o save precisa. Ver [member id] sobre por que isto
## não vive em `_init()`.
func is_valid() -> bool:
	return id != &"" and not display_name.is_empty()


func has_use() -> bool:
	return effect != Effect.NONE


## Aplica o efeito. `game_state` e `player` chegam prontos, em vez de vir dos
## autoloads: um `Resource` de dado que puxa `GameState` deixa de ser dado e
## vira um nó do jogo -- e é o que faz o runner de testes não conseguir
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
	return ""