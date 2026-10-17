extends Node
## Congela o jogo por alguns quadros no instante de um golpe.
##
## É o efeito mais barato que mais muda a sensação de um impacto: os 60ms em
## que nada se move dizem "isto Connectingou", e sem eles o dano vira só um
## número que muda.
##
## Registrado como autoload com o nome `Hitstop`.
##
## ## Por que `Engine.time_scale` e não uma flag que cada corpo consulta
##
## Uma flag exigiria que `Player`, `Enemy` e `Projectile` conferissem todo
## quadro, e as none veriam — é o tipo de coisa que um inimigo novo esquece.
## Congelar o relógio inteiro pega tudo de uma vez, inclusive tweens e
## partículas, que é justamente o que se quer no impacto.
##
## ## Por que o relógio usa tempo real
##
## Com `time_scale = 0`, `delta` é zero e um `Timer` normal nunca vence: o
## hitstop não acabaria nunca e o jogo travaria de verdade. Por isso a
## contagem usa [method Time.get_ticks_msec], que é relógio de parede e não
## para. Este foi o primeiro bug da implementação, e ele é silencioso — o jogo
## simplesmente congela e nunca volta.

## Quadros de congelamento padrão: 2 frames a 60 Hz.
const DEFAULT_FRAMES := 2
## Quanto o relógio desacelera. 0.0 = parada total. Pequeno valor (0.06)
## mantém um tiquinha de movimento e lê como "peso" em vez de "travou".
const DEFAULT_SCALE := 0.06
## Teto: um golpe nunca pode congelar o jogo de forma permanente.
const MAX_FREEZE_SECONDS := 0.12

var _until_ms := 0
var _scale := 1.0
var _running := false


func _ready() -> void:
	# O hitstop precisa contar o tempo com o jogo pausado: morre com o
	# último golpe e a pausa é justamente quando o jogador olha a tela.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if not _running:
		return
	if Time.get_ticks_msec() < _until_ms:
		return
	restore()


## @param frames Quadros a 60 Hz. 2 é o suficiente para "peso" sem virar
##   travamento perceptível.
## @param scale Fator do relógio durante o congelamento.
func trigger(frames: int = DEFAULT_FRAMES, scale: float = DEFAULT_SCALE) -> void:
	if frames <= 0 or scale < 0.0:
		return

	var seconds: float = minf(float(frames) / 60.0, MAX_FREEZE_SECONDS)
	# Com `scale` baixo, o relógio leva mais para chegar em `seconds`. Dividir
	# por `scale` mantém a duração pretendida em tempo de parede.
	_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0 / maxf(scale, 0.01))

	# Um congelamento mais fraco não substitui um mais forte: encadear dois
	# golpes no mesmo quadro deve parecer mais impactante, e não mais rápido.
	if _running and scale >= _scale:
		return

	_scale = scale
	_running = true
	Engine.time_scale = scale


## Encerra o congelamento agora. Usado no fim dos testes: congelar o relógio
## durante um `await` de física prenderia o próprio runner.
func cancel() -> void:
	restore()


func restore() -> void:
	if not _running:
		return
	_running = false
	_until_ms = 0
	Engine.time_scale = 1.0


func is_running() -> bool:
	return _running


## Quanto resta do congelamento, em segundos de parede. Diagnóstico.
func remaining() -> float:
	if not _running:
		return 0.0
	return maxf(0.0, float(_until_ms - Time.get_ticks_msec()) / 1000.0)