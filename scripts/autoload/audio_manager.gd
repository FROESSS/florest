extends Node
## Áudio 100% procedural (sintetizado em código, original). Barramentos: Music, SFX, Ambient.

signal subtitle(text: String, duration: float)

const RATE := 22050
var _cache: Dictionary = {}
var _ambient_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _ui_players: Array[AudioStreamPlayer] = []
var _current_ambient: String = ""
var _rng := RandomNumberGenerator.new()

const SOUND_NAMES := [
	"step_walk", "step_run", "pickup", "error", "confirm", "ui_move", "door_open", "door_locked",
	"hide", "flashlight", "drop", "heartbeat", "whisper", "hum", "screech", "growl", "drag",
	"rumble", "breath", "music_box", "amb_house", "amb_lab", "amb_organic", "memory", "chase_loop",
	"thud", "alarm", "fire", "gasp", "pain", "heal", "hole", "chapter",
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1978
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Ambient"
	add_child(_ambient_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_ui_players.append(p)

func warm_up() -> void:
	for n in SOUND_NAMES:
		get_stream(n)
		await get_tree().process_frame

func get_stream(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var s: AudioStreamWAV = _synth(sound)
	_cache[sound] = s
	return s

# ---------- Reprodução ----------

func play_sfx(sound: String, volume_db: float = 0.0, sub: String = "") -> void:
	var st := get_stream(sound)
	if st == null:
		return
	for p in _ui_players:
		if not p.playing:
			p.stream = st
			p.volume_db = volume_db
			p.play()
			break
	if sub != "":
		subtitle.emit(sub, 2.0)

## Som posicional (usa o mundo do jogo, se existir).
func play_at(sound: String, pos: Vector2, volume_db: float = 0.0, sub: String = "", parent: Node = null) -> AudioStreamPlayer2D:
	var host: Node = parent
	if host == null and GameManager.world != null:
		host = GameManager.world.current_room_node()
	if host == null:
		play_sfx(sound, volume_db, sub)
		return null
	var p := AudioStreamPlayer2D.new()
	p.stream = get_stream(sound)
	p.bus = "SFX"
	p.volume_db = volume_db
	p.max_distance = 360.0
	p.attenuation = 1.6
	p.position = pos
	host.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	if sub != "":
		subtitle.emit(sub, 2.0)
	return p

func set_ambient(sound: String) -> void:
	if sound == _current_ambient:
		return
	_current_ambient = sound
	if sound == "":
		_ambient_player.stop()
		return
	_ambient_player.stream = get_stream(sound)
	_ambient_player.volume_db = -6.0
	_ambient_player.play()

func play_music(sound: String, volume_db: float = -4.0) -> void:
	if sound == "":
		_music_player.stop()
		return
	_music_player.stream = get_stream(sound)
	_music_player.volume_db = volume_db
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

# ---------- Síntese ----------

func _synth(name: String) -> AudioStreamWAV:
	var d := PackedFloat32Array()
	match name:
		"step_walk": d = _noise_burst(0.11, 0.35, 900.0, 18.0)
		"step_run": d = _noise_burst(0.09, 0.55, 1500.0, 22.0)
		"pickup": d = _blips([660.0, 990.0], 0.09, 0.35)
		"confirm": d = _blips([520.0, 700.0], 0.06, 0.3)
		"ui_move": d = _blips([400.0], 0.03, 0.2)
		"error": d = _tone(110.0, 0.28, 0.4, 0, 6.0, 0.7)
		"door_open": d = _door(0.7)
		"door_locked": d = _noise_burst(0.2, 0.7, 260.0, 14.0)
		"hide": d = _noise_burst(0.35, 0.3, 700.0, 5.0)
		"flashlight": d = _noise_burst(0.04, 0.6, 3000.0, 60.0)
		"drop": d = _clatter(0.6)
		"heartbeat": d = _heartbeat()
		"whisper": d = _whisper(1.4)
		"hum": d = _lullaby()
		"screech": d = _screech(0.9)
		"growl": d = _growl(1.2)
		"drag": d = _rumble(0.9, 70.0, 0.5, 9.0)
		"rumble": d = _rumble(1.6, 42.0, 0.7, 3.0)
		"breath": d = _breath(1.4)
		"music_box": d = _music_box()
		"amb_house": d = _ambient(6.0, 55.0, 0.18, true)
		"amb_lab": d = _ambient_lab(6.0)
		"amb_organic": d = _ambient(6.0, 38.0, 0.28, false)
		"memory": d = _memory_tone()
		"chase_loop": d = _chase_loop()
		"thud": d = _tone(60.0, 0.4, 0.9, 0, 8.0, 0.0)
		"alarm": d = _alarm()
		"fire": d = _noise_burst(1.5, 0.35, 600.0, 1.0)
		"gasp": d = _breath(0.7)
		"pain": d = _tone(250.0, 0.32, 0.45, 2, 7.0, 1.2)
		"heal": d = _heal_sound()
		"hole": d = _rumble(1.1, 55.0, 0.6, 6.0)
		"chapter": d = _chapter_sound()
		_: return null
	var loop := name.begins_with("amb_") or name == "chase_loop" or name == "hum" and false
	return _make(d, loop)

func _make(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

func _alloc(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(seconds * RATE))
	return a

func _noise_burst(dur: float, amp: float, cutoff: float, decay: float) -> PackedFloat32Array:
	var a := _alloc(dur)
	var lp := 0.0
	var k := clampf(cutoff / float(RATE) * 6.0, 0.02, 0.95)
	for i in a.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * k
		a[i] = lp * amp * exp(-t * decay / maxf(dur, 0.01) * 1.5)
	return a

func _tone(freq: float, dur: float, amp: float, wave: int, decay: float, vib: float) -> PackedFloat32Array:
	var a := _alloc(dur)
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		ph += TAU * (freq + sin(t * 30.0) * vib * 4.0) / RATE
		var s := sin(ph)
		if wave == 1:
			s = signf(s) * 0.6
		elif wave == 2:
			s = fposmod(ph / TAU, 1.0) * 2.0 - 1.0
		a[i] = s * amp * exp(-t * decay)
	return a

func _blips(freqs: Array, each: float, amp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in freqs:
		out.append_array(_tone(f, each, amp, 0, 9.0, 0.0))
	return out

func _door(dur: float) -> PackedFloat32Array:
	var a := _alloc(dur)
	var ph := 0.0
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 90.0 + 140.0 * sin(t / dur * PI)
		ph += TAU * f / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.08
		var env := sin(t / dur * PI)
		a[i] = (signf(sin(ph)) * 0.18 + lp * 0.5) * env * 0.8
	return a

func _clatter(dur: float) -> PackedFloat32Array:
	var a := _alloc(dur)
	var hits := [0.0, 0.07, 0.13, 0.26, 0.33]
	for h in hits:
		var start := int(h * RATE)
		var f := _rng.randf_range(300.0, 900.0)
		for i in range(0, int(0.1 * RATE)):
			if start + i >= a.size():
				break
			var t := float(i) / RATE
			a[start + i] += (sin(TAU * f * t) * 0.4 + _rng.randf_range(-0.3, 0.3)) * exp(-t * 35.0)
	return a

func _heartbeat() -> PackedFloat32Array:
	var a := _alloc(0.9)
	for beat in [0.0, 0.22]:
		var start := int(beat * RATE)
		for i in range(0, int(0.16 * RATE)):
			var t := float(i) / RATE
			if start + i < a.size():
				a[start + i] += sin(TAU * 55.0 * t) * exp(-t * 22.0) * 0.9
	return a

func _whisper(dur: float) -> PackedFloat32Array:
	var a := _alloc(dur)
	var lp := 0.0
	var hp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var n := _rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.35
		hp += (lp - hp) * 0.05
		var am := (sin(t * 11.0) * 0.5 + 0.5) * (sin(t * 3.1 + 1.0) * 0.5 + 0.5)
		a[i] = (lp - hp) * am * 0.5 * sin(t / dur * PI)
	return a

func _lullaby() -> PackedFloat32Array:
	# Cantiga em tom menor, desafinada e lenta (original).
	var notes := [329.6, 392.0, 440.0, 392.0, 329.6, 293.7, 329.6, 261.6]
	var out := PackedFloat32Array()
	for n in notes:
		var f: float = n * (1.0 + _rng.randf_range(-0.012, 0.012))
		var seg := _alloc(0.42)
		for i in seg.size():
			var t := float(i) / RATE
			var env := exp(-t * 3.0) * minf(1.0, t * 60.0)
			seg[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.005 * t) * 0.15) * env * 0.35
		out.append_array(seg)
	return out

func _screech(dur: float) -> PackedFloat32Array:
	var a := _alloc(dur)
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 700.0 + 1400.0 * (1.0 - exp(-t * 6.0)) + sin(t * 60.0) * 80.0
		ph += TAU * f / RATE
		var s := fposmod(ph / TAU, 1.0) * 2.0 - 1.0
		a[i] = (s * 0.35 + _rng.randf_range(-0.25, 0.25)) * exp(-t * 2.2) * minf(1.0, t * 80.0)
	return a

func _growl(dur: float) -> PackedFloat32Array:
	var a := _alloc(dur)
	var ph := 0.0
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 62.0 + sin(t * 17.0) * 14.0 + sin(t * 3.0) * 10.0
		ph += TAU * f / RATE
		var s := fposmod(ph / TAU, 1.0) * 2.0 - 1.0
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.12
		a[i] = (s * 0.5 + lp * 0.4) * sin(t / dur * PI) * (0.6 + 0.4 * sin(t * 28.0))
	return a

func _rumble(dur: float, freq: float, amp: float, pulse: float) -> PackedFloat32Array:
	var a := _alloc(dur)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.02
		var env := sin(t / dur * PI)
		a[i] = (sin(TAU * freq * t) * 0.6 + lp * 3.0) * amp * env * (0.7 + 0.3 * sin(t * pulse * TAU))
	return a

func _breath(dur: float) -> PackedFloat32Array:
	var a := _alloc(dur)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.18
		a[i] = lp * 0.5 * pow(sin(t / dur * PI), 2.0)
	return a

func _music_box() -> PackedFloat32Array:
	var notes := [523.3, 659.3, 784.0, 659.3, 587.3, 698.5, 880.0, 698.5, 523.3, 440.0, 523.3, 392.0]
	var out := _alloc(0.0)
	var step := 0.4
	var total := _alloc(step * notes.size() + 1.0)
	for idx in notes.size():
		var f: float = notes[idx] * (1.0 + (0.004 if idx % 3 == 1 else 0.0))
		var start := int(idx * step * RATE)
		for i in range(0, int(1.0 * RATE)):
			if start + i >= total.size():
				break
			var t := float(i) / RATE
			total[start + i] += (sin(TAU * f * t) + sin(TAU * f * 3.01 * t) * 0.25) * exp(-t * 4.5) * 0.22
	return total

func _ambient(dur: float, base: float, amp: float, creaks: bool) -> PackedFloat32Array:
	var a := _alloc(dur)
	var lp := 0.0
	var n := a.size()
	for i in n:
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.01
		# frequências inteiras de ciclos no loop para emendar sem estalo
		var f1 := roundf(base * dur) / dur
		var f2 := roundf(base * 1.5 * dur) / dur
		a[i] = (sin(TAU * f1 * t) * 0.5 + sin(TAU * f2 * t) * 0.25) * amp + lp * amp * 2.2
	if creaks:
		var c := int(dur * RATE * 0.4)
		for i in range(0, int(0.25 * RATE)):
			var t2 := float(i) / RATE
			if c + i < n:
				a[c + i] += sin(TAU * (180.0 + 60.0 * t2) * t2) * exp(-t2 * 12.0) * 0.12
	# fade nas bordas para emendar
	var fade := int(0.05 * RATE)
	for i in fade:
		var k := float(i) / fade
		a[i] *= k
		a[n - 1 - i] *= k
	return a

func _ambient_lab(dur: float) -> PackedFloat32Array:
	var a := _alloc(dur)
	for i in a.size():
		var t := float(i) / RATE
		var f := roundf(120.0 * dur) / dur
		a[i] = (sin(TAU * f * t) * 0.10 + sin(TAU * f * 1.5 * t) * 0.04 + sin(TAU * roundf(3.0 * dur) / dur * t) * 0.05)
	return a

func _memory_tone() -> PackedFloat32Array:
	var a := _alloc(2.5)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = (sin(TAU * 220.0 * t) * 0.2 + sin(TAU * 223.0 * t) * 0.2 + sin(TAU * 330.0 * t) * 0.08) * sin(t / 2.5 * PI)
	return a

func _chase_loop() -> PackedFloat32Array:
	var dur := 2.4
	var a := _alloc(dur)
	for beat in 8:
		var start := int(beat * dur / 8.0 * RATE)
		var f := 52.0 if beat % 2 == 0 else 65.0
		for i in range(0, int(0.18 * RATE)):
			var t := float(i) / RATE
			if start + i < a.size():
				a[start + i] += sin(TAU * f * t) * exp(-t * 14.0) * 0.8
	for i in a.size():
		var t3 := float(i) / RATE
		a[i] += sin(TAU * roundf(220.0 * dur) / dur * t3) * 0.04
	return a

func _alarm() -> PackedFloat32Array:
	var a := _alloc(1.2)
	for i in a.size():
		var t := float(i) / RATE
		var f := 520.0 if fmod(t, 0.4) < 0.2 else 390.0
		a[i] = signf(sin(TAU * f * t)) * 0.18
	return a

func _heal_sound() -> PackedFloat32Array:
	var a := _noise_burst(0.35, 0.3, 500.0, 4.0)
	a.append_array(_blips([440.0, 554.0, 659.0], 0.14, 0.22))
	return a

func _chapter_sound() -> PackedFloat32Array:
	# acorde menor lento e grave, para as telas de transição de capítulo
	var a := _alloc(4.0)
	for i in a.size():
		var t := float(i) / RATE
		var env := sin(t / 4.0 * PI)
		a[i] = (sin(TAU * 110.0 * t) * 0.3 + sin(TAU * 130.8 * t) * 0.22 + sin(TAU * 164.8 * t) * 0.18 + sin(TAU * 55.0 * t) * 0.25) * env * 0.7
	return a
