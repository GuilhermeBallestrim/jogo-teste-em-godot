class_name PlayerTuning
extends RefCounted
## Números de movimento do player, em um único lugar.
##
## O [Player] lê daqui e os testes também. Não é preciosismo: o teste que
## valida a balística das fases precisa da velocidade e da altura do pulo, e
## em modo `--script` os autoloads ainda não existem como identificador
## quando o compilador carrega as dependências. Referenciar `Player.SPEED`
## de um teste arrastaria `player.gd` (que usa `GameState`) para dentro dessa
## etapa e a carga falharia. Uma classe sem autoloads não tem esse problema.

# ------------------------------------------------------------------ horizontal

const SPEED := 340.0
const GROUND_ACCELERATION := 2800.0
const AIR_ACCELERATION := 1600.0
const GROUND_FRICTION := 3200.0
const AIR_FRICTION := 900.0

# ---------------------------------------------------------------------- pulo

## Velocidade de subida. Com gravidade 980 e `APEX_GRAVITY_SCALE` 0,75 o pulo
## sobe ~303 px (ver [method max_jump_height]). As plataformas mais altas das
## fases ficam acima disso de propósito: são baitas de salto, com caminho
## feito de plataformas intermediárias.
const JUMP_VELOCITY := -760.0
## Multiplicador aplicado quando o botão é solto no meio do pulo.
## 1.0 = altura fixa; menor = o pulo encurta e o controle fica mais fino.
const JUMP_CUT := 0.45
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
## Multiplicador da gravidade no topo do arco. Abaixo de 1 o jogador "flutua"
## no ápice, o que dá tempo de ajustar a direção no ar -- mas também aumenta
## a altura total do pulo, então baixá-lo para 1.0 encurta o arco sem perder
## o controle no topo.
const APEX_GRAVITY_SCALE := 0.75
const APEX_VELOCITY_THRESHOLD := 220.0
const HARD_LANDING_SPEED := 700.0
## Folga para tirar o pé da superfície antes do impulso do pulo.
const JUMP_CLEARANCE := 1.5

# ---------------------------------------------------------------------- dash

const DASH_SPEED := 980.0
const DASH_TIME := 0.14
const DASH_COOLDOWN := 0.55
const DASH_END_SPEED_RATIO := 0.7

# ------------------------------------------------------------------- combate

const ATTACK_COOLDOWN := 0.32
const ATTACK_ACTIVE_TIME := 0.14
const ATTACK_DAMAGE := 1
const ATTACK_REACH := 28.0

const IFRAME_TIME := 1.0
const HURT_KNOCKBACK := 420.0

## Gravidade aplicada quando `get_gravity()` devolve zero.
##
## `get_gravity()` só funciona se a opção "Custom Gravity" estiver marcada em
## Project Settings > Physics > 2D. Como não queremos depender de uma caixa de
## seleção, lemos o valor nós mesmos. Sem isto o corpo não tem gravidade,
## nunca fica `is_on_floor()` de forma confiável e o coyote time nunca
## preenche -- o que trava o pulo e faz o personagem flutuar.
const DEFAULT_GRAVITY := 980.0


## Altura máxima do pulo, em px, já com o `APEX_GRAVITY_SCALE` aplicado.
##
## Duas fases de gravidade: 980 até `|vy|` passar do limiar, depois 735 no
## ápice. É o número que o level design precisa -- e é o que o teste de
## balística compara com o layout das fases.
static func max_jump_height() -> float:
	var jump := absf(JUMP_VELOCITY)
	var g := DEFAULT_GRAVITY
	var g_apex := g * APEX_GRAVITY_SCALE
	var v_apex := APEX_VELOCITY_THRESHOLD

	# Subida até o limiar do ápice, com a gravidade cheia.
	var rise := (jump * jump - v_apex * v_apex) / (2.0 * g)
	# Do limiar até o topo, com a gravidade reduzida.
	rise += v_apex * v_apex / (2.0 * g_apex)
	return rise


## Distância horizontal máxima, em px, percorrida durante um pulo que
## termina `rise` px acima do ponto de decolagem.
##
## `rise` negativo (pousar mais baixo) devolve mais distância, como deve. Se
## `rise` for maior que [method max_jump_height], não há solução -- o pulo não
## alcança -- e a função devolve 0 para o chamador tratar como impossível.
static func jump_reach(rise: float) -> float:
	if rise > max_jump_height():
		return 0.0

	var jump := absf(JUMP_VELOCITY)
	var g := DEFAULT_GRAVITY
	var v_apex := APEX_VELOCITY_THRESHOLD
	var g_apex := g * APEX_GRAVITY_SCALE

	var t := 0.0
	if rise > 0.0:
		# Subir e parar antes do apice: um quadrante so, com gravidade cheia.
		# Se o alvo estiver acima do limiar do apice este quadrante nao tem
		# solucao -- e nesse caso o unico caminho e subir e voltar, que e
		# sempre mais lento, nunca mais rapido.
		var disc := jump * jump - 2.0 * g * rise
		if disc < 0.0:
			return 0.0
		t = (jump - sqrt(disc)) / g
	else:
		# Pousar mais baixo: sobe ate o apice (gravidade cheia ate o limiar,
		# reduzida depois) e entao desce a altura que falta.
		t = jump / g - v_apex / g + v_apex / g_apex
		t += sqrt(2.0 * g * -rise) / g

	return SPEED * t
