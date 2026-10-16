extends Node
## Estado global da sessao de jogo.
## Registrado como autoload com o nome `GameState`.

signal health_changed(current: int, maximum: int)
signal coins_changed(amount: int)
signal score_changed(amount: int)
signal flag_changed(key: StringName, value: Variant)

var max_health: int = 100
var health: int = 100
var coins: int = 0
var score: int = 0

var _flags: Dictionary = {}


func _ready() -> void:
	reset()


## Zera todo o estado (chamado no inicio de uma partida nova).
func reset() -> void:
	health = max_health
	coins = 0
	score = 0
	_flags.clear()
	_notify_all()


func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)


func heal(amount: int) -> void:
	if amount <= 0:
		return
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	coins_changed.emit(coins)


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


## Guarda uma flag booleana/valor arbitrario usada para comportamento de script.
func set_flag(key: StringName, value: Variant) -> void:
	_flags[StringName(key)] = value
	flag_changed.emit(StringName(key), value)


func get_flag(key: StringName, default_value: Variant = false) -> Variant:
	return _flags.get(StringName(key), default_value)


func is_alive() -> bool:
	return health > 0


func to_dict() -> Dictionary:
	return {
		"max_health": max_health,
		"health": health,
		"coins": coins,
		"score": score,
		"flags": _flags.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	max_health = maxi(1, int(data.get("max_health", 100)))
	health = clampi(int(data.get("health", max_health)), 0, max_health)
	coins = maxi(0, int(data.get("coins", 0)))
	score = maxi(0, int(data.get("score", 0)))
	_flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	_notify_all()


func _notify_all() -> void:
	health_changed.emit(health, max_health)
	coins_changed.emit(coins)
	score_changed.emit(score)