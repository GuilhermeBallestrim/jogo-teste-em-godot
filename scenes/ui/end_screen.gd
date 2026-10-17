class_name EndScreen
extends CanvasLayer
## Tela de fim de fase, reaproveitada para vitoria e derrota.
## A fase chama [method configure] **antes** de adicionar a cena a arvore.

signal restart_requested
signal menu_requested

@export var is_victory := false

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _stats: Label = %StatsLabel
@onready var _restart: Button = %RestartButton
@onready var _menu: Button = %MenuButton

var _session: SessionStats = null


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

	# Comeca invisivel e pequeno: a animacao de entrada e o que separa
	# "tela de fim" de "tela de pause que apareceu do nada".
	_title.modulate.a = 0.0
	_title.scale = Vector2(0.6, 0.6)
	_title.pivot_offset = _title.size * 0.5
	_subtitle.modulate.a = 0.0
	_stats.modulate.a = 0.0
	_restart.modulate.a = 0.0
	_menu.modulate.a = 0.0

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

	# Animacao de entrada.
	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_subtitle, "modulate:a", 1.0, 0.2)
	tween.tween_property(_stats, "modulate:a", 1.0, 0.2)
	tween.tween_property(_restart, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(_menu, "modulate:a", 1.0, 0.15)

	if is_victory:
		_spawn_confetti()
	else:
		_shake_on_defeat()


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


## Confete na vitoria: particulas que caem do topo.
func _spawn_confetti() -> void:
	var colors := [Color(1.0, 0.85, 0.3), Color(0.38, 0.88, 0.61), Color(0.45, 0.78, 1.0), Color(1.0, 0.44, 0.44)]
	for i in 4:
		var p := CPUParticles2D.new()
		p.emitting = true
		p.one_shot = true
		p.explosiveness = 0.3
		p.amount = 24
		p.lifetime = 2.5
		p.direction = Vector2(0, 1)
		p.spread = 180.0
		p.gravity = Vector2(0, 80)
		p.initial_velocity_min = 80.0
		p.initial_velocity_max = 220.0
		p.angular_velocity_min = -180.0
		p.angular_velocity_max = 180.0
		p.scale_amount_min = 3.0
		p.scale_amount_max = 6.0
		p.color = colors[i % colors.size()]
		var layer := CanvasLayer.new()
		layer.layer = 111
		add_child(layer)
		layer.add_child(p)
		p.position = Vector2(get_viewport().get_visible_rect().size.x * (0.2 + 0.2 * i), -20)


## Tremor na derrota: a tela treme um pouco.
func _shake_on_defeat() -> void:
	var tween := create_tween()
	for i in 6:
		tween.tween_property(self, "offset", Vector2(randf_range(-6, 6), randf_range(-4, 4)), 0.05)
	tween.tween_property(self, "offset", Vector2.ZERO, 0.1)