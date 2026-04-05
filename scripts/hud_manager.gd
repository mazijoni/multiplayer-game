extends CanvasLayer
## Builds and updates the in-game HUD at runtime.
## Listens to GameManager signals for stamina, sanity, and death events.

const BAR_W      : float = 160.0
const BAR_H      : float = 10.0
const BAR_MARGIN : float = 20.0

var _sanity_vignette : ColorRect
var _stamina_bg      : ColorRect
var _stamina_fill    : ColorRect
var _death_label     : Label

func _ready() -> void:
	layer = 10
	_build_ui()
	GameManager.stamina_changed.connect(_on_stamina_changed)
	GameManager.sanity_changed.connect(_on_sanity_changed)
	GameManager.player_died.connect(_on_player_died)

func _build_ui() -> void:
	# ── Full-screen sanity vignette ────────────────────────────────────────────
	_sanity_vignette                = ColorRect.new()
	_sanity_vignette.anchor_right   = 1.0
	_sanity_vignette.anchor_bottom  = 1.0
	_sanity_vignette.color          = Color(0.0, 0.0, 0.0, 0.0)
	_sanity_vignette.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	add_child(_sanity_vignette)

	# ── Stamina bar background ─────────────────────────────────────────────────
	_stamina_bg               = ColorRect.new()
	_stamina_bg.anchor_top    = 1.0
	_stamina_bg.anchor_bottom = 1.0
	_stamina_bg.offset_left   = BAR_MARGIN
	_stamina_bg.offset_right  = BAR_MARGIN + BAR_W
	_stamina_bg.offset_top    = -(BAR_MARGIN + BAR_H)
	_stamina_bg.offset_bottom = -BAR_MARGIN
	_stamina_bg.color         = Color(0.08, 0.08, 0.08, 0.70)
	add_child(_stamina_bg)

	# ── Stamina bar fill ───────────────────────────────────────────────────────
	_stamina_fill               = ColorRect.new()
	_stamina_fill.anchor_top    = 1.0
	_stamina_fill.anchor_bottom = 1.0
	_stamina_fill.offset_left   = BAR_MARGIN
	_stamina_fill.offset_right  = BAR_MARGIN + BAR_W
	_stamina_fill.offset_top    = -(BAR_MARGIN + BAR_H)
	_stamina_fill.offset_bottom = -BAR_MARGIN
	_stamina_fill.color         = Color(0.18, 0.82, 0.30, 0.90)
	add_child(_stamina_fill)

	# ── "YOU DIED" death label ─────────────────────────────────────────────────
	_death_label                      = Label.new()
	_death_label.anchor_left          = 0.5
	_death_label.anchor_right         = 0.5
	_death_label.anchor_top           = 0.5
	_death_label.anchor_bottom        = 0.5
	_death_label.offset_left          = -200.0
	_death_label.offset_right         = 200.0
	_death_label.offset_top           = -40.0
	_death_label.offset_bottom        = 40.0
	_death_label.text                 = "YOU DIED"
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.add_theme_font_size_override("font_size", 52)
	_death_label.add_theme_color_override("font_color", Color(0.85, 0.05, 0.05))
	_death_label.visible              = false
	add_child(_death_label)

# ── Signal handlers ───────────────────────────────────────────────────────────
func _on_stamina_changed(ratio: float) -> void:
	if _stamina_fill:
		_stamina_fill.offset_right = BAR_MARGIN + BAR_W * clamp(ratio, 0.0, 1.0)

func _on_sanity_changed(ratio: float) -> void:
	if _sanity_vignette:
		var alpha : float = clampf((1.0 - ratio) * 0.80, 0.0, 0.80)
		_sanity_vignette.color = Color(0.10, 0.00, 0.00, alpha)

func _on_player_died() -> void:
	if _death_label:
		_death_label.visible = true
