extends Node
## Preferências do jogador, salvas em `user://settings.cfg`.
## Registrado como autoload com o nome `Settings`.

signal applied

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"
const VIDEO_SECTION := "video"
const ACCESS_SECTION := "accessibilidade"
const INPUT_SECTION := "controles"

## Acoes com remapeamento. Ordem da tela: e a ordem em que o jogador espera
## encontrar, nao a ordem alfabetica.
const REMAPPABLE := [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"jump", &"dash", &"interact", &"attack", &"pause", &"restart",
]

const UI_SCALE_MIN := 0.8
const UI_SCALE_MAX := 1.5

var music_volume: float = 0.7
var sfx_volume: float = 0.9
var fullscreen: bool = false

## --- acessibilidade ---
var ui_scale: float = 1.0
var shake_scale: float = 1.0
var high_contrast: bool = false

## --- controles ---
## Acao -> lista de eventos ja serializados (ver [method _serialize_event]).
var bindings: Dictionary = {}
## Copia imutavel do que veio do `project.godot`. "Restaurar padroes" volta
## para aqui -- sem isso, restaurar seria inventar os valores de novo e eles
## divergiriam do que o jogo realmente usa.
var _defaults: Dictionary = {}


func _ready() -> void:
	_capture_defaults()
	# Os bindings começam como uma cópia do padrão. Sem esta linha, `bindings`
	# ficaria vazio quando não há `settings.cfg`, e `_apply_bindings()` —
	# que apaga os eventos que não são remapeáveis antes de reinserir — apagaria
	# o gamepad inteiro. O jogo rodaria, sem nenhum erro, e o analógico
	# simplesmente pararia de funcionar.
	bindings = _defaults.duplicate(true)
	load_settings()
	apply()


# -------------------------------------------------------------- padroes


func _capture_defaults() -> void:
	_defaults = {}
	for action: StringName in REMAPPABLE:
		_defaults[action] = _serialize_action(action)


func default_binding_text(action: StringName) -> String:
	var list: Array = _defaults.get(action, [])
	return _join_text(list)


# -------------------------------------------------------------- carregar


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	music_volume = _clamp01(float(config.get_value(SECTION, "music", music_volume)))
	sfx_volume = _clamp01(float(config.get_value(SECTION, "sfx", sfx_volume)))
	fullscreen = bool(config.get_value(VIDEO_SECTION, "fullscreen", fullscreen))
	ui_scale = clampf(
		float(config.get_value(ACCESS_SECTION, "ui_scale", ui_scale)),
		UI_SCALE_MIN,
		UI_SCALE_MAX
	)
	shake_scale = _clamp01(float(config.get_value(ACCESS_SECTION, "shake", shake_scale)))
	high_contrast = bool(config.get_value(ACCESS_SECTION, "contraste", high_contrast))

	bindings = {}
	for action: StringName in REMAPPABLE:
		if not config.has_section(INPUT_SECTION):
			continue
		if not config.has_section_key(INPUT_SECTION, String(action)):
			continue
		var raw: Variant = config.get_value(INPUT_SECTION, String(action), [])
		if raw is Array:
			bindings[action] = _sanitize(raw)
	_apply_bindings()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "music", music_volume)
	config.set_value(SECTION, "sfx", sfx_volume)
	config.set_value(VIDEO_SECTION, "fullscreen", fullscreen)
	config.set_value(ACCESS_SECTION, "ui_scale", ui_scale)
	config.set_value(ACCESS_SECTION, "shake", shake_scale)
	config.set_value(ACCESS_SECTION, "contraste", high_contrast)
	for action: StringName in bindings:
		config.set_value(INPUT_SECTION, String(action), bindings[action])
	config.save(SETTINGS_PATH)


# ---------------------------------------------------------------- aplicar


func apply() -> void:
	var audio := _audio()
	if audio != null:
		audio.call(&"set_music_volume", music_volume)
		audio.call(&"set_sfx_volume", sfx_volume)
	_set_fullscreen(fullscreen)
	_apply_bindings()
	applied.emit()


## O autoload `Audio`, resolvido por nome.
##
## `Settings` chama `Audio` direto, e isso funciona -- mas o runner de testes
## carrega este arquivo no momento em que o autoload ainda não é identificador
## como identificador, e o `Compile Error: Identifier not found: Audio` sai no
## stderr. O `exportar.ps1` trata qualquer erro de script como motivo para não
## exportar, então o barulho custa o build inteiro.
##
## Pegar pelo nó em vez do identificador resolve: o identificador `Audio` não
## existe no momento em que o runner compila este arquivo, mas o autoload já
## está na árvore. `Engine.get_singleton` também não serve aqui -- autoloads do
## Godot não são singletons do `Engine`, e ele imprime erro ao procurar.
func _audio() -> Node:
	return get_tree().root.get_node_or_null(^"Audio")


## Liga/desliga o `push_error` das recusas de remapeamento.
##
## A recusa e um caminho previsto -- o jogador tentou algo invalido, o teste
## verificou a recusa -- e nao um defeito. Mas enquanto a excecao aparece no
## stderr, o `exportar.ps1` aborta: ele trata qualquer erro de script como
## motivo para nao exportar. O export liga isto; os testes desligam para poder
## exercitar o caminho sem sujar o log.
static var quiet_rejections := false


func _reject(reason: String) -> void:
	if quiet_rejections:
		return
	push_error("Settings: %s" % reason)


func set_music_volume(value: float) -> void:
	music_volume = _clamp01(value)
	var audio := _audio()
	if audio != null:
		audio.call(&"set_music_volume", music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = _clamp01(value)
	var audio := _audio()
	if audio != null:
		audio.call(&"set_sfx_volume", sfx_volume)

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_set_fullscreen(enabled)


func set_ui_scale(value: float) -> void:
	ui_scale = clampf(value, UI_SCALE_MIN, UI_SCALE_MAX)


func set_shake_scale(value: float) -> void:
	shake_scale = _clamp01(value)


func set_high_contrast(enabled: bool) -> void:
	high_contrast = enabled


## Sentido: true = janela cheia. Em plataformas sem troca de modo, nao faz nada.
func _set_fullscreen(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var target := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() == target:
		return
	DisplayServer.window_set_mode(target)


func _clamp01(value: float) -> float:
	return clampf(value, 0.0, 1.0)


# ------------------------------------------------------------- controles


## Escreve as preferencias de teclado/mouse no [InputMap].
##
## Só o que não é gamepad é reescrito. Os eixos do analógico vivem no
## `project.godot` e o remapeamento de teclado não pode apagá-los -- sem esta
## distinção, trocar uma tecla quebraria o gamepad silenciosamente.
func _apply_bindings() -> void:
	for action: StringName in REMAPPABLE:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			# Apaga SO o remapeável. Os eixos de gamepad e o resto do
			# `project.godot` ficam intocados: apagar aqui e o caminho mais
			# curto para um remapeamento de teclado derrubar o controle inteiro
			# sem erro nenhum.
			if _is_remappable(event):
				InputMap.action_erase_event(action, event)
		for raw: Variant in bindings.get(action, []):
			var event := _deserialize_event(raw)
			if event != null:
				InputMap.action_add_event(action, event)


## Acoes de teclado e botao de mouse. Joypad, gamepad motion e `InputEventMouseMotion`
## ficam de fora: remapear "eixo 3" nao faz sentido e o mouse nao tem botao
## de mover.
func _is_remappable(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton


## Texto curto da tecla, para o botao na tela de opcoes.
func binding_text(action: StringName) -> String:
	return _join_text(bindings.get(action, []))


## Define a tecla de uma acao. Substitui todos os eventos de teclado/mouse
## anteriores -- remapear e escolher UM boton, e nao acumular.
func set_binding(action: StringName, event: InputEvent) -> bool:
	if not REMAPPABLE.has(action):
		_reject("acao nao remapeavel -> %s" % action)
		return false
	if not _is_remappable(event):
		_reject("evento nao remapeavel -> %s" % event)
		return false

	bindings[action] = [_serialize_event(event)]
	_apply_bindings()
	return true


## Qual outra acao ja usa este evento? A UI usa para avisar antes de
## sobrescrever, em vez de roubar a tecla silenciosamente.
func conflict_with(event: InputEvent) -> StringName:
	var serial := _serialize_event(event)
	for action: StringName in REMAPPABLE:
		if action == &"":
			continue
		var list: Variant = bindings.get(action, [])
		if list is Array and (list as Array).has(serial):
			return action
	return &""


func reset_bindings() -> void:
	bindings = _defaults.duplicate(true)
	_apply_bindings()


# -------------------------------------------- serializacao dos eventos


## Serializacao explicita, e nao `as_text()`.
##
## `InputEvent.as_text()` serve para exibir, nao para guardar: ele devolve a
## tecla *por rotulo*, e o rotulo muda com o idioma do sistema. Um save feito
## numa maquina em portugues deixaria de funcionar numa em ingles. Guardamos o
## codigo fisico e um tipo -- dado estavel e testavel.
func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		return {
			"t": "key",
			"c": key.physical_keycode if key.physical_keycode != 0 else key.keycode,
			"a": key.ctrl_pressed,
			"s": key.shift_pressed,
			"m": key.alt_pressed,
		}
	if event is InputEventMouseButton:
		return {"t": "mouse", "c": (event as InputEventMouseButton).button_index}
	return {}


func _deserialize_event(raw: Variant) -> InputEvent:
	if not (raw is Dictionary):
		return null
	var data: Dictionary = raw
	match String(data.get("t", "")):
		"key":
			var key := InputEventKey.new()
			var code := int(data.get("c", 0))
			if code == 0:
				return null
			# `physical_keycode` antes de `keycode`: "Espaco" precisa continuar
			# sendo Espaco em teclado com layout diferente.
			key.physical_keycode = code
			key.ctrl_pressed = bool(data.get("a", false))
			key.shift_pressed = bool(data.get("s", false))
			key.alt_pressed = bool(data.get("m", false))
			return key
		"mouse":
			var click := InputEventMouseButton.new()
			click.button_index = int(data.get("c", 0)) as MouseButton
			return click
	return null


func _serialize_action(action: StringName) -> Array:
	var out: Array = []
	if not InputMap.has_action(action):
		return out
	for event in InputMap.action_get_events(action):
		if _is_remappable(event):
			out.append(_serialize_event(event))
	return out


## Descarta entradas nao serializaveis vindas do arquivo de configuracao: um
## `settings.cfg` editado a mao nao pode fazer o InputMap carregar lixo.
func _sanitize(raw: Array) -> Array:
	var out: Array = []
	for entry: Variant in raw:
		if entry is Dictionary and _deserialize_event(entry) != null:
			out.append(entry)
	return out


func _join_text(list: Variant) -> String:
	var parts := PackedStringArray()
	if list is Array:
		for raw: Variant in list:
			var event := _deserialize_event(raw)
			if event != null:
				parts.append(describe_event(event))
	return " / ".join(parts) if not parts.is_empty() else "--"


## Rotulo legivel de um evento. Aqui `as_text()` serve: e so apresentacao, e
## nunca volta para o disco.
func describe_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		# `physical_keycode` guarda posicao fisica; `keycode` guarda o simbolo.
		# Para exibir, queremos o simbolo de `keycode`, que e o que o jogador
		# ve na tecla.
		var code := key.keycode if key.keycode != 0 else key.physical_keycode
		var label := OS.get_keycode_string(code)
		var extra := PackedStringArray()
		if key.ctrl_pressed:
			extra.append("Ctrl")
		if key.alt_pressed:
			extra.append("Alt")
		if key.shift_pressed:
			extra.append("Shift")
		if extra.is_empty():
			return label
		return "%s+%s" % ["+".join(extra), label]
	if event is InputEventMouseButton:
		return "Botao %d" % (event as InputEventMouseButton).button_index
	return "?"
