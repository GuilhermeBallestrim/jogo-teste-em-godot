class_name HUD
extends CanvasLayer
## HUD do prototipo. Escuta os sinais do `GameState`, entao nao conhece a
## origem dos dados -- so reage as mudancas.

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _score_label: Label = %ScoreLabel

var _coin_goal: int = 0


func _ready() -> void:
	GameState.health_changed.connect(_on_health_changed)
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.score_changed.connect(_on_score_changed)

	_refresh_health(GameState.health, GameState.max_health)
	_on_coins_changed(GameState.coins)
	_on_score_changed(GameState.score)


## Se `goal` for maior que zero, o HUD mostra "Moedas 3/10".
func set_coin_goal(goal: int) -> void:
	_coin_goal = maxi(0, goal)
	_on_coins_changed(GameState.coins)


func _on_health_changed(current: int, maximum: int) -> void:
	_refresh_health(current, maximum)


func _refresh_health(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "Vida %d/%d" % [current, maximum]


func _on_coins_changed(amount: int) -> void:
	if _coin_goal > 0:
		_coins_label.text = "Moedas %d/%d" % [amount, _coin_goal]
	else:
		_coins_label.text = "Moedas %d" % amount


func _on_score_changed(amount: int) -> void:
	_score_label.text = "Pontos %d" % amount