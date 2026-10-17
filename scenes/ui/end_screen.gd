class_name EndScreen
extends CanvasLayer
## Tela de fim de fase, reaproveitada para vitoria e derrota.
## A fase chama [method configure] **antes** de adicionar a cena a arvore.

signal restart_requested
signal menu_requested

@export var is_victory := false

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
var _session: SessionStats = null

@onready var _stats: Label = %StatsLabel
@onready var _restart: Button = %RestartButton
@onready var _menu: Button = %MenuButton


func configure(victory: bool) -> void:
	is_victory = victory

## Recebe as estatisticas da tentativa. Pode ser chamado antes ou depois de
## `_ready` (a fase chama antes de adicionar a cena).
func set_stats(stats: SessionStats) -> void:
	_session = stats
	if is_inside_tree():
		_refresh_stats()



func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS

	if is_victory:
		_title.text = "VITORIA!"
		_title.add_theme_color_override("font_color", Color(0.376, 0.878, 0.612))
		_subtitle.text = "Voce coletou todas as moedas."
	else:
		_title.text = "FIM DE JOGO"
		_title.add_theme_color_override("font_color", Color(0.949, 0.361, 0.361))
		_subtitle.text = "Voce perdeu todas as vidas."

	GameState.coins_changed.connect(_on_coins_changed)
	GameState.score_changed.connect(_on_score_changed)
	_refresh_stats()

	_restart.pressed.connect(_on_restart)
	_menu.pressed.connect(_on_menu)
	_restart.grab_focus()

	GameState.health_changed.connect(func(_c: int, _m: int) -> void: _refresh_stats())


func _refresh_stats() -> void:
	var base := "Moedas: %d        Pontos: %d" % [GameState.coins, GameState.score]
	if _session != null:
		_stats.text = "%s\n%s" % [base, _session.summary()]
	else:
		_stats.text = base


func _on_coins_changed(_amount: int) -> void:
	_refresh_stats()


func _on_score_changed(_amount: int) -> void:
	_refresh_stats()


func _on_restart() -> void:
	Sfx.play(&"select")
	restart_requested.emit()


func _on_menu() -> void:
	Sfx.play(&"back")
	menu_requested.emit()