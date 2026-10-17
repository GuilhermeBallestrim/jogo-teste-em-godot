class_name Presentation
extends RefCounted
## Efeitos visuais globais: escala de texto e contraste.
##
## São duas coisas pequenas que, feitas na mão, viram um `if` em cada
## arquivo de interface. Concentradas aqui, o resto do jogo só pergunta "qual
## o valor" e nunca "como aplicar".

## Chave de metadado onde guardamos o tamanho original do texto. Sem ela,
## aplicar a escala duas vezes multiplicaria 1.3 por 1.3 -- e o jogador que
## abre e fecha o painel veria a interface crescer a cada visita.
const ORIGINAL_SIZE := &"presentation_font_size"

const CONTRAST_ON := Color(1.35, 1.35, 1.35)
const CONTRAST_OFF := Color(1, 1, 1)

const METADATA_KEY := &"presentation_contrast"


## Multiplica o tamanho de fonte de todo texto que declara um override.
##
## Acha de funcionar com `content_scale_factor` (que escalaria o mundo junto,
## e a câmera 2D não é UI) e com `Theme.default_font_size` (que o projeto
## ignora, porque cada Label do `.tscn` tem o seu override). Sobra reescrever
## os overrides, guardando o valor original para ser reversível.
static func apply_ui_scale(root: Node, scale: float) -> void:
	if root == null:
		return
	_walk(root, func(node: Node) -> void:
		if node is Label or node is Button or node is RichTextLabel:
			_rescale_label(node as Control, scale)
	)
	root.set_meta(ORIGINAL_SIZE, scale)


## Reescala um controle de texto, guardando o tamanho base.
static func rescale_label(control: Control, scale: float) -> void:
	_rescale_label(control, scale)


## Reescala um controle de texto.
##
## Guarda o tamanho base em metadado na primeira passagem, para que chamar de
## novo não acumule. O botão só existe dentro da preferência do jogador: um
## painel de opções recém-aberto tem os Labels com override do `.tscn` mas sem
## metadado, e aí o que vale é o tamanho do `.tscn`, não o do tema.
static func _rescale_label(control: Control, scale: float) -> void:
	if not control.has_theme_font_size_override(&"font_size"):
		control.add_theme_font_size_override(&"font_size", -1)
	if not control.has_meta(ORIGINAL_SIZE):
		control.set_meta(ORIGINAL_SIZE, control.get_theme_font_size(&"font_size"))
	var base: int = int(control.get_meta(ORIGINAL_SIZE))
	control.add_theme_font_size_override(&"font_size", maxi(8, int(round(base * scale))))


static func reset_ui_scale(root: Node) -> void:
	if root == null:
		return
	_walk(root, func(node: Node) -> void:
		if not node.has_meta(ORIGINAL_SIZE):
			return
		var base: int = int(node.get_meta(ORIGINAL_SIZE))
		if node.has_theme_font_size_override(&"font_size"):
			node.add_theme_font_size_override(&"font_size", base)
		node.remove_meta(ORIGINAL_SIZE)
	)
	root.remove_meta(ORIGINAL_SIZE)


## Contraste alto clareia a cena inteira.
##
## O jogo é escuro sobre escuro (ceu #16181F, personagem #4B9EF5, inimigos de
## cor média) e quem tem baixa visão perde a silhueta na conta do fundo. Um
## `CanvasModulate` clareia tudo de uma vez -- é a alavanca mais forte
## disponível sem pipeline de pós-processamento.
static func set_contrast(scene: Node, enabled: bool) -> void:
	if scene == null:
		return
	var found := scene.get_node_or_null(^"Contrast")
	if found == null:
		var modulate := CanvasModulate.new()
		modulate.name = "Contrast"
		modulate.color = CONTRAST_ON if enabled else CONTRAST_OFF
		modulate.set_meta(METADATA_KEY, true)
		scene.add_child(modulate)
		return
	(found as CanvasModulate).color = CONTRAST_ON if enabled else CONTRAST_OFF


static func has_contrast(scene: Node) -> bool:
	if scene == null:
		return false
	return scene.get_node_or_null(^"Contrast") != null


static func _walk(node: Node, action: Callable) -> void:
	for child in node.get_children():
		action.call(child)
		_walk(child, action)