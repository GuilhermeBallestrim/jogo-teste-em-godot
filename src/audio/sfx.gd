class_name Sfx
extends RefCounted
## Sintetiza os efeitos sonoros do jogo em tempo de execucao.
##
## O projeto nao tem nenhum arquivo de audio, entao em vez de depender de
## assets os sons sao gerados como [AudioStreamWAV] e cacheados em memoria.
## Isso mantem o repositorio leve e faz o audio funcionar sem importacao.
##
##     Sfx.play(&"coin")
##     Sfx.play(&"jump", -4.0, 1.2)   # volume em dB, pitch 1.2
##
## Para usar sons proprios, placed em assets/audio/sfx e chame
## `Audio.play_sfx(preload("res://assets/audio/sfx/meu.wav"))` normalmente.

const MIX_RATE := 22050

## Cada som e uma lista de notas: [freq_inicio, freq_fim, duracao, onda, volume]
const RECIPES := {
	&"coin": [[1046.0, 1046.0, 0.05, "square", 0.22], [1568.0, 1568.0, 0.12, "square", 0.20]],
	&"jump": [[320.0, 700.0, 0.11, "tri", 0.30]],
	&"land": [[200.0, 120.0, 0.06, "tri", 0.18]],
	&"dash": [[700.0, 180.0, 0.16, "noise", 0.16]],
	&"swing": [[500.0, 260.0, 0.07, "noise", 0.10]],
	&"hurt": [[340.0, 90.0, 0.20, "saw", 0.30]],
	&"enemy_hit": [[420.0, 140.0, 0.09, "square", 0.24]],
	&"enemy_die": [[300.0, 60.0, 0.30, "saw", 0.24]],
	&"checkpoint": [[659.0, 659.0, 0.07, "tri", 0.26], [988.0, 988.0, 0.14, "tri", 0.24]],
	&"select": [[700.0, 900.0, 0.05, "square", 0.18]],
	&"back": [[700.0, 450.0, 0.06, "square", 0.18]],
	&"death": [[440.0, 55.0, 0.60, "tri", 0.30]],
	&"victory": [
		[523.0, 523.0, 0.09, "tri", 0.26],
		[659.0, 659.0, 0.09, "tri", 0.26],
		[784.0, 784.0, 0.09, "tri", 0.26],
		[1046.0, 1046.0, 0.30, "tri", 0.28],
	],
}

static var _cache: Dictionary = {}


## Libera os AudioStreamWAV sintetizados. O [Audio] chama isso ao encerrar para
## nao deixar recursos pendurados na saida do jogo.
static func clear_cache() -> void:
	_cache.clear()


static func play(id: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var audio := AudioManager.instance
	if audio == null or not audio.sfx_enabled:
		return
	audio.play_sfx(get_stream(id), volume_db, pitch_scale)


static func get_stream(id: StringName) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	if not RECIPES.has(id):
		push_warning("Sfx: som desconhecido '%s'" % id)
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = _render(RECIPES[id])
	_cache[id] = stream
	return stream


static func _render(notes: Array) -> PackedByteArray:
	var gap := int(MIX_RATE * 0.012)
	var bytes := PackedByteArray()
	for note: Array in notes:
		var samples := _render_note(note[0], note[1], note[2], note[3], note[4])
		bytes.append_array(samples)
		bytes.resize(bytes.size() + gap * 2)
	return bytes


static func _render_note(freq_start: float, freq_end: float, duration: float, wave_kind: String, volume: float) -> PackedByteArray:
	var count := maxi(1, int(MIX_RATE * duration))
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq_start * 1000.0) + count

	for i in count:
		var t := float(i) / float(count)
		var freq: float = freq_start + (freq_end - freq_start) * t
		phase = fposmod(phase + TAU * freq / float(MIX_RATE), TAU)

		var wave := 0.0
		match wave_kind:
			"square":
				wave = 1.0 if sin(phase) >= 0.0 else -1.0
			"saw":
				wave = phase / PI - 1.0
			"noise":
				wave = rng.randf_range(-1.0, 1.0)
			_:
				wave = asin(sin(phase)) * (2.0 / PI)

		# Envelope: ataque curtissimo + decaimento exponencial.
		var attack: float = clampf(t / 0.05, 0.0, 1.0)
		var envelope: float = attack * pow(1.0 - t, 2.2)
		bytes.encode_s16(i * 2, int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767.0))

	return bytes