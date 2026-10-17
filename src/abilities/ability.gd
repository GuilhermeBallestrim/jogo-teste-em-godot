class_name Ability
extends Resource
## Habilidade desbloqueavel.
##
## Dados puros, sem logica de jogo: o `GameState` guarda quais estao
## desbloqueadas e o `Player` consulta. Segue o mesmo padrao do
## `ItemDefinition`.

## Identificador estavel.
@export var id: StringName = &""
## Nome exibido.
@export var display_name: String = ""
## Descricao curta.
@export var description: String = ""
## Custo em pontos (para desbloqueio).
@export var cost: int = 0


static func make(id: StringName, name: String, desc: String, cost: int) -> Ability:
	var a := Ability.new()
	a.id = id
	a.display_name = name
	a.description = desc
	a.cost = cost
	return a