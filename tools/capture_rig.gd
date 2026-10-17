extends SceneTree
## Ferramenta de captura: desenha o bone do player em cada pose e salva um PNG.
## Nao faz parte do jogo.
##
##   godot --path . --resolution 1400x520 --script res://tools/capture_rig.gd
##
## Existe por um motivo: nenhum bug de personagem se resolve lendo o codigo.
## E a unica forma de conferir se a pose ficou legivel de verdade.
##
## Precisa rodar COM janela (sem `--headless`), porque o renderizador headless
## e um dummio e a imagem sai vazia.

const RIG_SCENE := "res://scenes/actors/player/player_rig.tscn"
const OUT_DIR := "user://capturas"
const STEP := 1.0 / 60.0

## [nome, estado, quantos segundos avancar]
const SHOTS := [
	["01_idle", PlayerRig.State.IDLE, 0.30],
	["02_walk", PlayerRig.State.WALK, 0.18],
	["03_run", PlayerRig.State.RUN, 0.18],
	["04_dash", PlayerRig.State.DASH, 0.05],
	["05_jump", PlayerRig.State.JUMP, 0.10],
	["06_fall", PlayerRig.State.FALL, 0.10],
	["07_attack", PlayerRig.State.ATTACK, 0.06],
	["08_damage", PlayerRig.State.DAMAGE, 0.08],
	["09_death", PlayerRig.State.DEATH, 0.50],
]

var _frames := 0
var _built := false


func _initialize() -> void:
	# Nada aqui: `_initialize()` roda antes de `root` entrar em regime, e um
	# nó adicionado nesse momento só recebe `_ready()` no quadro seguinte.
	# Chamar `play()`/`tick()` antes disso desenharia o rig sem `_nodes` e o
	# bone sairia exatamente como está no .tscn -- que é o que aconteceu na
	# primeira versão desta ferramenta, e parecia um bug de pose.
	var bg := ColorRect.new()
	bg.color = Color(0.086, 0.094, 0.133)
	bg.size = Vector2(1500, 900)
	root.add_child(bg)


func _build() -> void:
	var names := PackedStringArray()
	# As ultimas 5 poses sao repetidas na segunda fileira so para caber.
	for i in SHOTS.size():
		var entry: Array = SHOTS[i]

		# O zoom vive no pai, e não no rig: `PlayerRig.tick()` escreve
		# `scale = Vector2(facing, 1)` todo quadro para espelhar o bone, e um
		# zoom no proprio rig seria apagado no primeiro tick.
		var stand := Node2D.new()
		stand.scale = Vector2(2.6, 2.6)
		var column := i % 5
		var row := i / 5
		stand.position = Vector2(180 + column * 280, 200 + row * 330)
		root.add_child(stand)

		var rig := (load(RIG_SCENE) as PackedScene).instantiate()
		stand.add_child(rig)

		rig.play(entry[1])
		# Avança o suficiente para a pose assentar e a camada procedural entrar
		# em regime: em t=0 sairiam todas iguais bone parado.
		for _f in int(float(entry[2]) / STEP):
			rig.tick(STEP)

		var caption := Label.new()
		caption.position = Vector2(180 + column * 280 - 30, 200 + row * 330 + 100)
		caption.text = "%s\n%s" % [String(entry[0]).substr(3), rig.debug_state()]
		root.add_child(caption)
		names.append(String(entry[0]).substr(3))

	var title := Label.new()
	title.position = Vector2(40, 40)
	title.text = "PlayerRig (%s)" % ", ".join(names)
	root.add_child(title)


## O laço principal do script. Devolve `true` para encerrar.
func _process(_delta: float) -> bool:
	_frames += 1

	if not _built:
		_built = true
		_build()
		return false

	# Espera alguns quadros de verdade: precisa de pelo menos um desenho
	# completo antes de ler a textura do viewport.
	if _frames < 8:
		return false
	_save()
	return true


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var image := root.get_texture().get_image()
	if image == null:
		print("CAPTURA: viewport sem imagem (rode SEM --headless)")
		return

	var path := "%s/player_rig_poses.png" % OUT_DIR
	var err := image.save_png(path)
	if err != OK:
		print("CAPTURA: save falhou com erro ", err)
		return

	# Um PNG em branco "salva" sem erro nenhum, entao conferimos que ha
	# mesmo conteudo antes de dizer que deu certo.
	var distinct := {}
	for y in range(0, image.get_height(), 7):
		for x in range(0, image.get_width(), 7):
			distinct[image.get_pixel(x, y).to_rgba32()] = true

	print("CAPTURA: %s (%dx%d, %d cores distintas)" % [
		ProjectSettings.globalize_path(path),
		image.get_width(),
		image.get_height(),
		distinct.size(),
	])