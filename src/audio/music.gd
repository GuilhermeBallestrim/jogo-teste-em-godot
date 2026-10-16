class_name Music
extends RefCounted
## Gera uma trilha sonora em loop no proprio codigo (sem assets).
##
## A progressao e um loop de 4 compassos em Am - F - C - G, com baixo, um pad
## e um arpejo de colcheias. Tudo e sintetizado uma unica vez e reaproveitado.
##
##     Music.play()      # comecar (loop)
##     Music.stop()

const MIX_RATE := 22050
const BPM := 110.0
const BEATS_PER_BAR := 4
const BARS := 4

## Frequencias (Hz) das notas usadas, para escrever a progressao em nomes.
const NOTES := {
	"A2": 110.00, "C3": 130.81, "E3": 164.81, "F2": 87.31,
	"A3": 220.00, "C4": 261.63, "E4": 329.63, "F3": 174.61,
	"G2": 98.00, "B3": 246.94, "D4": 293.66, "G3": 196.00,
}

## Cada compasso: [baixo, acorde (notas do arpejo)]
const PROGRESSION := [
	["A2", ["A3", "C4", "E4"]],
	["F2", ["A3", "C4", "F3"]],
	["C3", ["C4", "E4", "G3"]],
	["G2", ["B3", "D4", "G3"]],
]

static var _cache: AudioStreamWAV = null


## Libera a trilha sintetizada. O [Audio] chama isso ao encerrar para nao
## deixar o AudioStreamWAV pendurado na saida do jogo.
static func clear_cache() -> void:
	_cache = null


static func play(volume_db: float = -8.0) -> void:
	var audio := AudioManager.instance
	if audio == null or not audio.music_enabled:
		return
	audio.play_music(get_stream(), 0.8)


static func stop() -> void:
	var audio := AudioManager.instance
	if audio == null:
		return
	audio.stop_music(0.8)


static func get_stream() -> AudioStreamWAV:
	if _cache != null:
		return _cache

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	var buffer := _mix()
	stream.data = buffer
	stream.loop_begin = 0
	stream.loop_end = int(buffer.size() / 2)

	_cache = stream
	return stream


static func _mix() -> PackedByteArray:
	var beat := 60.0 / BPM
	var bar := beat * BEATS_PER_BAR
	var total_seconds := bar * BARS
	var frames := int(MIX_RATE * total_seconds)

	# Acumulamos em float para poder somar camadas sem clipping intermediario.
	var mix := PackedFloat32Array()
	mix.resize(frames)

	for bar_index in BARS:
		var root_name: String = PROGRESSION[bar_index][0]
		var arp_names: Array = PROGRESSION[bar_index][1]
		var bar_start := int(bar_index * bar * MIX_RATE)

		# Baixo: uma nota longa por tempo forte.
		_add_note(mix, NOTES[root_name], bar_start, beat * 3.6, 0.26, "tri", 0.9)
		_add_note(mix, NOTES[root_name] * 2.0, bar_start + int(beat * 2 * MIX_RATE), beat * 1.4, 0.10, "tri", 0.5)

		# Pad: acorde sustentado, levemente desafinado.
		for note_name: String in arp_names:
			var freq: float = NOTES[note_name] * 0.5
			_add_note(mix, freq, bar_start, bar * 0.98, 0.070, "saw", 1.0)
			_add_note(mix, freq * 1.004, bar_start, bar * 0.98, 0.055, "saw", 1.0)

		# Arpejo de colcheias.
		var step := beat * 0.5
		for i in 8:
			var freq: float = NOTES[arp_names[i % arp_names.size()]]
			var at := bar_start + int(i * step * MIX_RATE)
			var accent := 0.085 if i % 2 == 0 else 0.050
			_add_note(mix, freq * 2.0, at, step * 0.85, accent, "square", 1.0)

	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		# Normaliza com folga e um compressor suave para nao estourar.
		var value: float = tanh(mix[i] * 1.2) * 0.72
		bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	return bytes


static func _add_note(mix: PackedFloat32Array, freq: float, start: int, duration: float, volume: float, wave_kind: String, decay: float) -> void:
	var count := int(duration * MIX_RATE)
	if count <= 0:
		return
	var end: int = mini(start + count, mix.size())
	var phase := 0.0

	for i in range(start, end):
		if i < 0:
			continue
		var t := float(i - start) / float(count)
		phase = fposmod(phase + TAU * freq / float(MIX_RATE), TAU)

		var wave := 0.0
		match wave_kind:
			"square":
				wave = 1.0 if sin(phase) >= 0.0 else -1.0
			"saw":
				wave = phase / PI - 1.0
			_:
				wave = asin(sin(phase)) * (2.0 / PI)

		var envelope: float = clampf(t / 0.06, 0.0, 1.0) * pow(1.0 - t, decay)
		mix[i] += wave * envelope * volume