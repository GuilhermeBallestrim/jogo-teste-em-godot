extends CanvasLayer
## Transicao de cenas com fade.
## Registrado como autoload com o nome `SceneRouter`.
##
## E um CanvasLayer para que o fade seja desenhado acima de qualquer gameplay.

signal scene_changed(scene_id: StringName, scene_path: String)
signal scene_failed(scene_path: String)

const FADE_TIME := 0.25
const FADE_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const TRANSITION_LAYER := 128

var current_scene_id: StringName = &""
var is_transitioning: bool = false

var _fade: ColorRect


func _ready() -> void:
	layer = TRANSITION_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = FADE_COLOR
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_fade.visible = false
	add_child(_fade)
	_fit_fade()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and _fade != null:
		_fit_fade()


## Troca para `scene_path` (ex.: "res://scenes/levels/forest.tscn") com fade.
func goto(scene_path: String, scene_id: StringName = &"", fade_time: float = FADE_TIME) -> void:
	if is_transitioning:
		push_warning("SceneRouter: transicao ignorada (ja em andamento).")
		return
	if not ResourceLoader.exists(scene_path):
		push_error("SceneRouter: cena inexistente -> %s" % scene_path)
		scene_failed.emit(scene_path)
		return

	is_transitioning = true
	_fit_fade()
	_fade.visible = true

	if fade_time > 0.0:
		_fade.modulate.a = 0.0
		await _tween_alpha(0.0, 1.0, fade_time)

	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneRouter: falha ao trocar cena (%d) -> %s" % [err, scene_path])
		scene_failed.emit(scene_path)
		is_transitioning = false
		_fade.visible = false
		return

	current_scene_id = scene_id if scene_id != &"" else StringName(scene_path.get_file().get_basename())
	scene_changed.emit(current_scene_id, scene_path)

	# `change_scene_to_file` so instancia a nova cena no fim do frame.
	await get_tree().process_frame

	if fade_time > 0.0:
		await _tween_alpha(1.0, 0.0, fade_time)

	_fade.visible = false
	is_transitioning = false


## Recarrega a cena atual.
func reload(fade_time: float = FADE_TIME) -> void:
	var current := get_tree().current_scene
	if current == null:
		push_warning("SceneRouter: nao ha cena ativa para recarregar.")
		return
	await goto(current.scene_file_path, current_scene_id, fade_time)


func quit_to_menu() -> void:
	get_tree().quit()


func _fit_fade() -> void:
	if _fade != null:
		_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _tween_alpha(from: float, to: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_fade, "modulate:a", to, duration)
	await tween.finished