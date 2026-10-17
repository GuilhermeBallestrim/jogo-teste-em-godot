class_name PlayerRig
extends Node2D
## Bone procedural do player: oito poses legíveis, sem nenhum asset.
##
## O projeto não tem arte no repositório, mas "retângulo azul" é o máximo que
## um `Polygon2D` único entrega. Aqui o corpo é montado por peça -- cabeça,
## tronco, dois braços, duas pernas e um cachecol -- e cada peça gira em torno
## da sua própria articulação. É o que permite que "pulo" e "queda" sejam
## coisas diferentes, e não a mesma imagem um pouco deslocada.
##
##     Player
##       `-- Rig   <- este script
##           |-- LegBack / LegFront   (pivô no quadril)
##           |-- Torso                 (pivô no quadril)
##           |-- Scarf                 (pivô no pescoço)
##           |-- Head / Visor         (pivô no pescoço)
##           `-- ArmBack / ArmFront   (pivô no ombro)
##           `-- Slash                 (só no ataque)
##
## Cada estado é uma pose alvo; a pose atual persegue a alvo com uma
## velocidade própria, e uma camada procedural (respiração, ciclo de passo,
## ondulação do cachecol) entra por cima. Blend entre poses é o que faz a
## transição parecer contínua em vez de um corte.

signal pose_changed(state: StringName)

enum State {
	IDLE, WALK, RUN, DASH, JUMP, FALL, ATTACK, DAMAGE, DEATH,
}

## Partes na ordem de desenho: o que vem antes fica atrás.
const PARTS: Array[String] = [
	"leg_back", "scarf", "leg_front", "arm_back",
	"torso", "arm_front", "head",
]

## Chave da pose -> nome do nó na cena.
##
## Existe porque a pose é identificada em `snake_case` (é uma chave de
## dicionário, e snake_case é o que o resto do projeto usa) enquanto o nó de
## cena leva `PascalCase` (é o que o Godot mostra). Traduzir num lugar só é
## melhor que escolher uma das duas e deixar o outro lugar quebrar em silêncio.
const NODES := {
	"leg_back": &"LegBack",
	"scarf": &"Scarf",
	"leg_front": &"LegFront",
	"arm_back": &"ArmBack",
	"torso": &"Torso",
	"arm_front": &"ArmFront",
	"head": &"Head",
}

const BLEND_IDLE := 12.0
const BLEND_MOVE := 22.0
const BLEND_SNAP := 34.0

# ------------------------------------------------------------------ paleta

const SKIN := Color(0.976, 0.835, 0.702)
const SUIT := Color(0.294, 0.62, 0.961)
const SUIT_DARK := Color(0.184, 0.412, 0.706)
const BOOT := Color(0.145, 0.184, 0.286)
const SCARF := Color(0.949, 0.361, 0.361)
const VISOR := Color(0.055, 0.071, 0.106)
const SLASH := Color(1.0, 0.925, 0.62, 0.85)

# ------------------------------------------------------------------- poses

## Pose neutra. Todo estado parte daqui e sobrescreve o que muda -- assim uma
## pose nova só declara a diferença, e não os sete campos de novo.
const BASE := {
	"torso": {"rot": 0.0, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
	"head": {"rot": 0.0, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
	"arm_front": {"rot": 0.15, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
	"arm_back": {"rot": -0.15, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
	"leg_front": {"rot": 0.0, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
	"leg_back": {"rot": 0.0, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
	"scarf": {"rot": 0.0, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
}

const POSES := {
	State.IDLE: {
		"torso": {"rot": 0.0, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"head": {"rot": 0.0, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"arm_front": {"rot": 0.18, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"arm_back": {"rot": -0.18, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_front": {"rot": 0.0, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_back": {"rot": 0.0, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"scarf": {"rot": 0.0, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
	},
	State.WALK: {
		"torso": {"rot": 0.06, "off": Vector2(0, 0), "scl": Vector2(1, 0.98)},
		"head": {"rot": -0.04, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"arm_front": {"rot": 0.5, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"arm_back": {"rot": -0.5, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_front": {"rot": -0.1, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_back": {"rot": 0.1, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"scarf": {"rot": 0.0, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
	},
	State.RUN: {
		"torso": {"rot": 0.16, "off": Vector2(1, 0), "scl": Vector2(1, 0.94)},
		"head": {"rot": -0.12, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"arm_front": {"rot": 0.95, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"arm_back": {"rot": -0.95, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_front": {"rot": -0.35, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_back": {"rot": 0.35, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"scarf": {"rot": 0.0, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
	},
	State.DASH: {
		# Inclinado para a frente, pernas para trás, cachecol esticado: a
		# silhueta já diz "não posso desviar agora".
		"torso": {"rot": 0.42, "off": Vector2(2, -2), "scl": Vector2(1.12, 0.9)},
		"head": {"rot": -0.34, "off": Vector2(2, -1), "scl": Vector2(1, 1)},
		"arm_front": {"rot": -1.15, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"arm_back": {"rot": -1.45, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_front": {"rot": 0.95, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_back": {"rot": -0.85, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"scarf": {"rot": 0.0, "off": Vector2(0, 0), "scl": Vector2(1.25, 0.8)},
	},
	State.JUMP: {
		# Pernas recolhidas, braços para cima: quem olha de relance lê "subiu".
		"torso": {"rot": -0.1, "off": Vector2(0, -2), "scl": Vector2(0.94, 1.1)},
		"head": {"rot": -0.16, "off": Vector2(0, -1), "scl": Vector2(1, 1)},
		"arm_front": {"rot": -1.9, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"arm_back": {"rot": -2.1, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_front": {"rot": 0.75, "off": Vector2(0, -2), "scl": Vector2(1, 1)},
		"leg_back": {"rot": 0.2, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"scarf": {"rot": 0.0, "off": Vector2(0, 2), "scl": Vector2(1, 1.3)},
	},
	State.FALL: {
		# Pernas abertas procurando apoio, braços abertos: a diferença em
		# relação ao pulo é toda de silhueta, e é o que o jogador lê.
		"torso": {"rot": 0.14, "off": Vector2(0, 1), "scl": Vector2(1.02, 1.04)},
		"head": {"rot": 0.2, "off": Vector2(0, 1), "scl": Vector2(1, 1)},
		"arm_front": {"rot": -2.5, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"arm_back": {"rot": -2.2, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_front": {"rot": 0.5, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_back": {"rot": -0.45, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"scarf": {"rot": 0.0, "off": Vector2(0, 3), "scl": Vector2(1.1, 1.2)},
	},
	State.ATTACK: {
		# Torção do tronco e o braço da frente estendido. O arco (`Slash`)
		# aparece junto -- o golpe precisa de uma forma, não só de um dano.
		"torso": {"rot": 0.2, "off": Vector2(3, 0), "scl": Vector2(1.06, 0.96)},
		"head": {"rot": -0.14, "off": Vector2(2, 0), "scl": Vector2(1, 1)},
		"arm_front": {"rot": 1.5, "off": Vector2(2, 0), "scl": Vector2(1, 1)},
		"arm_back": {"rot": -0.7, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_front": {"rot": -0.28, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_back": {"rot": 0.32, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"scarf": {"rot": 0.0, "off": Vector2(0, 0), "scl": Vector2(1.15, 0.95)},
	},
	State.DAMAGE: {
		# Recuo: tronco para trás, braços na frente, cabeça puxada. É a pose
		# que o jogador usa para saber que levou dano, mesmo sem HUD.
		"torso": {"rot": -0.36, "off": Vector2(-4, 1), "scl": Vector2(0.92, 1.06)},
		"head": {"rot": 0.3, "off": Vector2(-3, 1), "scl": Vector2(1, 1)},
		"arm_front": {"rot": -2.3, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"arm_back": {"rot": -2.0, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_front": {"rot": 0.4, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"leg_back": {"rot": -0.3, "off": Vector2(0, 0), "scl": Vector2(1, 1)},
		"scarf": {"rot": 0.0, "off": Vector2(2, 2), "scl": Vector2(1, 1)},
	},
	State.DEATH: {
		# Desaba. O `PlayerRig` cuida da rotação final fora da pose.
		"torso": {"rot": 0.5, "off": Vector2(-2, 4), "scl": Vector2(1.1, 0.82)},
		"head": {"rot": 0.5, "off": Vector2(-1, 4), "scl": Vector2(1, 1)},
		"arm_front": {"rot": 0.9, "off": Vector2(0, 2), "scl": Vector2(1, 1)},
		"arm_back": {"rot": -0.9, "off": Vector2(0, 2), "scl": Vector2(1, 1)},
		"leg_front": {"rot": 0.6, "off": Vector2(0, 2), "scl": Vector2(1, 1)},
		"leg_back": {"rot": 0.2, "off": Vector2(0, 2), "scl": Vector2(1, 1)},
		"scarf": {"rot": 0.0, "off": Vector2(3, 3), "scl": Vector2(1, 0.9)},
	},
}

## Ordem de prioridade quando mais de um se aplica. `Player` pergunta o
## contexto e o rig resolve; a ordem está aqui para ser lida num lugar só.
const PRIORITY := [
	State.DEATH, State.DAMAGE, State.DASH, State.ATTACK,
	State.JUMP, State.FALL, State.RUN, State.WALK, State.IDLE,
]

# ------------------------------------------------------------------ estado

var state: State = State.IDLE
## 1.0 = olhando para a direita. `-1` espelha o bone inteiro.
var facing := 1.0:
	set(value):
		facing = -1.0 if value < 0.0 else 1.0

var _nodes := {}
## Pose que esta sendo desenhada agora (a interpolada, nao a alvo).
var _live := {}
var _time := 0.0
## Delta do ultimo `tick`. A camada procedural usa este e nao
## `get_process_delta_time()`: quem manda no bone e quem chama `tick()`, e
## usar o relogio do node faria o ciclo de passo andar na velocidade do jogo
## em vez da frequencia que a pose pediu.
var _delta := 0.0
var _state_timer := 0.0
var _step_phase := 0.0
var _slash_time := 0.0
var _damage_time := 0.0

@onready var _slash: Polygon2D = $Slash


func _ready() -> void:
	for part: String in PARTS:
		# `.get` e nao `[]`: um nó ausente tem de sumir em silencio, e nao
		# derrubar o `tick` inteiro no meio do quadro.
		_nodes[part] = get_node_or_null(NodePath(String(NODES[part])))
	_live = _copy_of(POSES[State.IDLE])


## Quanto tempo cada estado efêmero fica antes de o próximo seibanar:
## dano some rápido (senão vira pose permanente), o golpe tem de acompanhar a
## hitbox, e a morte não tem volta.
const EPHEMERAL := {
	State.DAMAGE: 0.35,
	State.ATTACK: 0.22,
	State.DEATH: 9999.0,
}


func play(next: State) -> void:
	if next == state:
		return
	_state_timer = 0.0
	if next == State.ATTACK:
		_slash_time = EPHEMERAL[State.ATTACK]
	elif next == State.DAMAGE:
		_damage_time = EPHEMERAL[State.DAMAGE]
	state = next
	pose_changed.emit(state_name())


func state_name() -> String:
	return String(State.keys()[state])


## Diagnostico: o arco do golpe esta aparecendo quando nao deveria?
func slash_visible() -> bool:
	return _slash != null and _slash.visible


## Uma linha de tudo que a captura de tela precisa conferir.
func debug_state() -> String:
	return "%s slash_t=%.3f vis=%s nos=%d/%d" % [
		state_name(),
		_slash_time,
		slash_visible(),
		_nodes.size(),
		PARTS.size(),
	]


func is_dead() -> bool:
	return state == State.DEATH


func tick(delta: float) -> void:
	_delta = delta
	_time += delta
	_state_timer += delta
	_slash_time = maxf(_slash_time - delta, 0.0)
	_damage_time = maxf(_damage_time - delta, 0.0)

	# Estado efêmero que expirou volta para o que o contexto mandar.
	if _state_timer >= float(EPHEMERAL.get(state, 0.0)) and state in EPHEMERAL:
		state = State.IDLE
		_state_timer = 0.0

	var rate := _blend_rate()
	for part: String in PARTS:
		var node: Node2D = _nodes.get(part)
		if node == null:
			continue
		_live[part] = _approach(_live[part], POSES[state][part], rate * delta)

	var additive := _additive()
	for part: String in PARTS:
		var node: Node2D = _nodes.get(part)
		if node == null:
			continue
		var live: Dictionary = _live[part]
		var extra: Dictionary = additive.get(part, {})
		node.rotation = live["rot"] + float(extra.get("rot", 0.0))
		node.position = live["off"] + Vector2(extra.get("off", Vector2.ZERO))
		node.scale = live["scl"] * Vector2.ONE * float(extra.get("scl", 1.0))

	scale = Vector2(facing, 1.0)
	_update_slash()


func _blend_rate() -> float:
	match state:
		State.ATTACK, State.DAMAGE:
			return BLEND_SNAP
		State.WALK, State.RUN:
			return BLEND_MOVE
		State.JUMP, State.FALL:
			return BLEND_SNAP
	return BLEND_IDLE


## Movimento por cima da pose: o que faz o personagem parecer vivo em vez de
## articulado.
func _additive() -> Dictionary:
	match state:
		State.IDLE:
			var breath := sin(_time * 2.4)
			return {
				"torso": {"scl": 1.0 + breath * 0.035},
				"head": {"off": Vector2(0, breath * 0.9)},
				"arm_back": {"rot": -breath * 0.05},
				"scarf": {"rot": sin(_time * 1.6) * 0.09},
			}
		State.WALK, State.RUN:
			# A frequência do passo acompanha a velocidade: correr bate mais
			# rápido que andar, sem nenhum número novo no Player.
			var stride: float = 11.0 if state == State.RUN else 8.0
			_step_phase += stride * _delta
			var swing := sin(_step_phase) * (0.42 if state == State.RUN else 0.3)
			var bob := absf(sin(_step_phase))
			return {
				"leg_front": {"rot": swing},
				"leg_back": {"rot": -swing},
				"arm_front": {"rot": -swing * 0.8},
				"arm_back": {"rot": swing * 0.8},
				"torso": {"off": Vector2(0, -bob * (1.6 if state == State.RUN else 1.0))},
				"head": {"off": Vector2(0, -bob * 0.8)},
				"scarf": {"rot": sin(_step_phase * 0.5) * 0.18},
			}
		State.DASH:
			# Tremor curto no corpo, como vibração de velocidade.
			var buzz := sin(_time * 62.0) * 0.02
			return {
				"torso": {"off": Vector2(0, buzz * 14.0)},
				"scarf": {"rot": sin(_time * 34.0) * 0.14},
			}
		State.JUMP:
			return {"scarf": {"rot": sin(_time * 11.0) * 0.14}}
		State.FALL:
			return {"scarf": {"rot": sin(_time * 5.0) * 0.3}}
		State.ATTACK:
			# Estende o braço no começo do golpe e recolhe: a curva do arco
			# é sincronizada com a hitbox, não com o relógio.
			var t: float = clampf(1.0 - _slash_time / EPHEMERAL[State.ATTACK], 0.0, 1.0)
			return {
				"arm_front": {"rot": -0.9 * (1.0 - t)},
				"scarf": {"rot": -0.35 * (1.0 - t)},
			}
		State.DAMAGE:
			var t2: float = clampf(1.0 - _damage_time / EPHEMERAL[State.DAMAGE], 0.0, 1.0)
			return {
				"torso": {"off": Vector2(-2.0 * (1.0 - t2), 0)},
				"head": {"rot": -0.25 * (1.0 - t2)},
			}
		State.DEATH:
			# Tombar de lado, em vez de sumir.
			var fall: float = clampf(_state_timer * 2.2, 0.0, 1.0)
			return {
				"torso": {"rot": fall * 0.9},
				"head": {"rot": fall * 1.1},
			}
	return {}


func _update_slash() -> void:
	if _slash == null:
		return
	if _slash_time <= 0.0:
		_slash.visible = false
		return
	_slash.visible = true
	var t: float = 1.0 - _slash_time / EPHEMERAL[State.ATTACK]
	# O arco nasce largo e fino e encolhe -- o inverso de um borrão comum,
	# porque aqui o golpe é o evento, não o aftermath.
	_slash.scale = Vector2(0.55 + t * 0.65, 1.0)
	_slash.modulate.a = (1.0 - t) * SLASH.a


func _approach(live: Dictionary, target: Dictionary, amount: float) -> Dictionary:
	var k: float = clampf(amount, 0.0, 1.0)
	return {
		"rot": lerp_angle(live["rot"], target["rot"], k),
		"off": (live["off"] as Vector2).lerp(target["off"] as Vector2, k),
		"scl": (live["scl"] as Vector2).lerp(target["scl"] as Vector2, k),
	}


func _copy_of(pose: Dictionary) -> Dictionary:
	var out := {}
	for part: String in PARTS:
		var entry: Dictionary = pose[part]
		out[part] = {
			"rot": entry["rot"],
			"off": entry["off"],
			"scl": entry["scl"],
		}
	return out


## Estado que o contexto do jogador pede, na ordem de prioridade. Concentrar a
## regra aqui significa que o `Player` não conhece a ordem nem o `PRIORITY`.
func resolve(dead: bool, damaged: bool, dashing: bool, attacking: bool,
		on_floor: bool, vertical_speed: float, horizontal_speed: float) -> State:
	if dead:
		return State.DEATH
	if damaged:
		return State.DAMAGE
	if dashing:
		return State.DASH
	if attacking:
		return State.ATTACK
	if not on_floor:
		# `vertical_speed < 0` é subindo, em Godot: y cresce para baixo.
		return State.JUMP if vertical_speed < 0.0 else State.FALL
	if absf(horizontal_speed) > SPEED_THRESHOLD:
		return State.RUN
	if absf(horizontal_speed) > 4.0:
		return State.WALK
	return State.IDLE


## Abaixo disso é "parado com ruído numérico", não caminhada.
const SPEED_THRESHOLD := 120.0