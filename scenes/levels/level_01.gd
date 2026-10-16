extends Node2D
## Fase 1 -- responsavel pelo fluxo de jogo (reset, pausa, vitoria, derrota).
## A logica de movimento e combate vive no [Player] e no [Enemy]; aqui so
## orquestramos.

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const PAUSE_MENU_SCENE := "res://scenes/ui/pause_menu.tscn"
const END_SCREEN_SCENE := "res://scenes/ui/end_screen.tscn"

@export var coins_to_win := 12
## Limites da camera 2D. Posicao = canto superior esquerdo, size = tamanho.
@export var camera_limits := Rect2(-1240, -780, 2480, 1200)

@onready var _player: Player = $Player
@onready var _hud: HUD = $HUD
@onready var _camera: Camera2D = $Player/Camera2D

var _finished := false
var _pause_menu: PauseMenu = null
var _end_screen: EndScreen = null


func _ready() -> void:
	GameState.reset()
	_apply_camera_limits()
	_hud.set_coin_goal(coins_to_win)
	_player.died.connect(_on_player_died)
	Music.play()


func _process(_delta: float) -> void:
	if _finished:
		return
	if GameState.coins >= coins_to_win:
		_win()


func _apply_camera_limits() -> void:
	_camera.limit_left = int(camera_limits.position.x)
	_camera.limit_top = int(camera_limits.position.y)
	_camera.limit_right = int(camera_limits.end.x)
	_camera.limit_bottom = int(camera_limits.end.y)


# ------------------------------------------------------------------ fluxo


func _win() -> void:
	if _finished:
		return
	_finished = true
	Sfx.play(&"victory")
	Music.stop()
	_show_end_screen(true)


func _on_player_died() -> void:
	if _finished:
		return
	_finished = true
	# Pequena pausa para o jogador ver a animacao antes da tela.
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	_show_end_screen(false)


func _show_end_screen(victory: bool) -> void:
	_end_screen = load(END_SCREEN_SCENE).instantiate()
	_end_screen.configure(victory)
	add_child(_end_screen)
	_end_screen.restart_requested.connect(_restart)
	_end_screen.menu_requested.connect(_go_to_menu)


func _restart() -> void:
	get_tree().paused = false
	SceneRouter.goto(scene_file_path)


func _go_to_menu() -> void:
	get_tree().paused = false
	SceneRouter.goto(MAIN_MENU_SCENE, &"main_menu")


# ------------------------------------------------------------------ pausa


func _open_pause_menu() -> void:
	if get_tree().paused or _finished:
		return
	Sfx.play(&"select")
	get_tree().paused = true
	_pause_menu = load(PAUSE_MENU_SCENE).instantiate()
	add_child(_pause_menu)
	_pause_menu.resume_requested.connect(_resume)
	_pause_menu.restart_requested.connect(_restart)
	_pause_menu.menu_requested.connect(_go_to_menu)


func _resume() -> void:
	if is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	_pause_menu = null
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed(&"pause"):
		_open_pause_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"restart"):
		_restart()
		get_viewport().set_input_as_handled()