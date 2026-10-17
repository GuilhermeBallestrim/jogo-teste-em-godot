class_name CameraShake
extends Node2D
## Tremor de camera. Use como filho da Camera2D (e nao nela mesma, senao o
## offset seria somado a posicao de destino a cada frame).
##
##     Camera2D
##     `-- CameraShake   <- este script
##
## Chamada: get_parent().shake_for(1.0)
##
## A amplitude vem de [member Settings.shake_scale]. Ler a preferencia aqui,
## e nao no `Player`, significa que o tremor some em todo lugar de uma vez --
## incluindo o tremor de tela cheia que ninguem se lembra de que existe.

@export var max_offset := Vector2(9.0, 7.0)
## Quanto tempo (em segundos) leva para zerar a intensidade, no maximo.
@export var duration := 0.35
@export var frequency := 34.0

var _strength := 0.0
var _time := 0.0
var _origin := Vector2.ZERO
var _running := false


func _ready() -> void:
	_origin = position


func _process(delta: float) -> void:
	if not _running:
		return
	_time += delta
	_strength = maxf(_strength - delta / maxf(duration, 0.01), 0.0)
	if _strength <= 0.0:
		_running = false
		position = _origin
		return

	var amount := _strength * _preference()
	if amount <= 0.0:
		# Preferencia em zero: some na hora, sem esperar a intensidade
		# decair. Deixar o no tremendo "muito pouco" e o pior dos dois.
		_running = false
		position = _origin
		return

	position = _origin + Vector2(
		sin(_time * frequency) * max_offset.x * amount,
		cos(_time * frequency * 1.37) * max_offset.y * amount
	)


## @param intensity 0.0 = nenhum tremor, 1.0 = tremor maximo.
func shake_for(intensity: float) -> void:
	if intensity <= 0.0 or _preference() <= 0.0:
		return
	_strength = clampf(maxf(_strength, intensity), 0.0, 1.0)
	_running = true


## O tremor esta ativo agora? Usado por teste e por debug: um tremor que nao
## sai e impossivel de diagnosticar de fora.
func is_shaking() -> bool:
	return _running


func stop() -> void:
	_running = false
	_strength = 0.0
	position = _origin


## O autoload pode nao existir em cena de teste isolada; nesse caso vale 1.0
## (sem preferencia = tremor normal), e nao 0.0.
func _preference() -> float:
	var settings := get_tree().root.get_node_or_null(^"Settings")
	if settings == null:
		return 1.0
	return clampf(float(settings.get(&"shake_scale")), 0.0, 1.0)