extends Control

@export var audio_player: AudioStreamPlayer
@export var bar_container: Container
@export var file_dialog: FileDialog
@export var open_button: Button

# Peak Colors
@export var color_low: Color = Color.GREEN
@export var color_mid: Color = Color.YELLOW
@export var color_peak: Color = Color.RED

const FREQ_MAX = 11000.0
const MIN_DB = 60.0

var spectrum: AudioEffectSpectrumAnalyzerInstance
var bars: Array[Node] = []
var current_heights: Array[float] = []

func _ready() -> void:
	# File loading setup
	if open_button and file_dialog:
		open_button.pressed.connect(func(): file_dialog.popup_centered(Vector2i(700, 500)))
		file_dialog.file_selected.connect(_on_file_selected)

	# Fetch Spectrum Instance (Audio Bus 1)
	spectrum = AudioServer.get_bus_effect_instance(1, 0)

	if bar_container:
		bars = bar_container.get_children()
		current_heights.resize(bars.size())
		current_heights.fill(0.0)
		
		# Force container layout to full screen in code
		bar_container.anchor_left = 0.0
		bar_container.anchor_top = 0.0
		bar_container.anchor_right = 1.0
		bar_container.anchor_bottom = 1.0
		bar_container.offset_left = 0
		bar_container.offset_top = 0
		bar_container.offset_right = 0
		bar_container.offset_bottom = 0

		# Force child flags in code so you don't have to guess in inspector
		for child in bars:
			if child is Control:
				child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				child.size_flags_vertical = Control.SIZE_SHRINK_END

func _on_file_selected(path: String) -> void:
	var stream: AudioStream = null
	var ext = path.get_extension().to_lower()

	match ext:
		"mp3":
			stream = AudioStreamMP3.load_from_file(path)
		"ogg":
			stream = AudioStreamOggVorbis.load_from_file(path)
		"wav":
			stream = AudioStreamWAV.load_from_file(path)

	if stream and audio_player:
		audio_player.stream = stream
		audio_player.play()

func _process(delta: float) -> void:
	if not spectrum or bars.is_empty():
		return

	# Scales bar height to match total screen height
	var max_height: float = get_viewport_rect().size.y
	var num_bars = bars.size()
	var prev_hz = 0.0

	for i in range(num_bars):
		var hz = (i + 1) * FREQ_MAX / num_bars
		var magnitude = spectrum.get_magnitude_for_frequency_range(prev_hz, hz).length()
		var energy = linear_to_db(magnitude)
		var target_factor = clampf((energy + MIN_DB) / MIN_DB, 0.0, 1.0)

		current_heights[i] = lerpf(current_heights[i], target_factor, 15.0 * delta)

		var bar = bars[i] as ColorRect
		if bar:
			bar.custom_minimum_size.y = current_heights[i] * max_height
			bar.color = _get_peak_color(current_heights[i])

		prev_hz = hz

func _get_peak_color(factor: float) -> Color:
	if factor < 0.5:
		return color_low.lerp(color_mid, factor * 2.0)
	else:
		return color_mid.lerp(color_peak, (factor - 0.5) * 2.0)
