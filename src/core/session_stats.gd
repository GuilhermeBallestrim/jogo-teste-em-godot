class_name SessionStats
extends RefCounted
## Estatisticas de uma tentativa de fase.
##
## Acumulador puro, sem autoload: o teste precisa instanciar e mexer sem
## carregar o resto do jogo, e o `LevelBase` instancia um por tentativa.
## Quem decide se um recorde foi batido e quem guarda e o `Save`; aqui so
## se calcula.

## Identificador da fase tentada.
var level_id: StringName = &""

## Momento em que a tentativa comecou (ms de parede).
var _start_ms: int = 0
## Tempo em que a fase foi concluida, ou 0 se ainda em andamento.
var _end_ms: int = 0

## Mortes do jogador nesta tentativa.
var deaths: int = 0
## Moedas coletadas nesta tentativa.
var coins_collected: int = 0
## Total de moedas que a fase tinha.
var coins_total: int = 0
## Dano causado aos inimigos.
var damage_dealt: int = 0
## Dano recebido pelo jogador.
var damage_taken: int = 0

## Se a tentativa terminou em vitoria.
var victory: bool = false


## Comeca a contar. Chamar de novo reinicia.
func start(id: StringName, total_coins: int) -> void:
	level_id = id
	coins_total = maxi(0, total_coins)
	coins_collected = 0
	deaths = 0
	damage_dealt = 0
	damage_taken = 0
	victory = false
	_start_ms = Time.get_ticks_msec()
	_end_ms = 0


## Registra uma morte do jogador.
func record_death() -> void:
	deaths += 1


## Registra moedas coletadas (valor, nao contagem).
func record_coins(value: int) -> void:
	coins_collected += maxi(0, value)


## Registra dano causado.
func record_damage_dealt(amount: int) -> void:
	damage_dealt += maxi(0, amount)


## Registra dano recebido.
func record_damage_taken(amount: int) -> void:
	damage_taken += maxi(0, amount)


## Marca a tentativa como concluida.
func finish(victory_flag: bool) -> void:
	victory = victory_flag
	if _end_ms == 0:
		_end_ms = Time.get_ticks_msec()


## Tempo decorrido, em segundos. Se a fase ainda nao terminou, usa o agora.
func elapsed_seconds() -> float:
	var end: int = _end_ms if _end_ms > 0 else Time.get_ticks_msec()
	return maxf(0.0, float(end - _start_ms) / 1000.0)


## Moedas por segundo.
func coins_per_second() -> float:
	var t := elapsed_seconds()
	if t <= 0.0:
		return 0.0
	return float(coins_collected) / t


## Nota da tentativa: S, A, B ou C.
##
## S: vitoria, sem mortes, todas as moedas, tempo abaixo do par.
## A: vitoria, no maximo 1 morte.
## B: vitoria com 2+ mortes, ou derrota com progresso.
## C: derrota sem progresso.
func grade(par_seconds: float = 90.0) -> String:
	if not victory:
		if coins_collected > 0 or damage_dealt > 0:
			return "B"
		return "C"
	# Vitoria.
	if deaths == 0 and coins_collected >= coins_total and elapsed_seconds() <= par_seconds:
		return "S"
	if deaths <= 1:
		return "A"
	return "B"


## Resumo em uma linha, para a tela de fim.
func summary() -> String:
	var t := elapsed_seconds()
	return "Tempo: %.1f s   Mortes: %d   Moedas: %d/%d   Nota: %s" % [
		t, deaths, coins_collected, coins_total, grade()
	]