class_name DreamerPortrait
extends Control
## Retrato de Kroker para menús. / Kroker portrait for menus.

## "" = pijama (menú principal) / pajamas (main menu)
@export var character_id := ""
var selected := false
var _t := 0.0
var _light := 0.0
static var _glow: GradientTexture2D


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_t = randf() * 10.0
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.9))
		g.set_color(1, Color(1, 1, 1, 0))
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(0.5, 0.0)


func _process(delta: float) -> void:
	_t += delta
	_light = move_toward(_light, 1.0 if selected else 0.0, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x / 200.0, size.y / 300.0)
	var origin := Vector2((size.x - 200.0 * s) / 2.0, (size.y - 300.0 * s) / 2.0)
	# Luz cenital tenue al seleccionar / Faint overhead light when selected
	var c := origin + Vector2(100, 150) * s
	var r := 150.0 * s
	draw_texture_rect(_glow, Rect2(c - Vector2(r, r * 1.1), Vector2(r * 2, r * 2.2)), false,
		Color(UITheme.GOLD, 0.05 + 0.13 * _light))
	# Al elegirlo, Kroker hace una demostración con su arma / When picked, Kroker shows off his weapon
	var demo := 0.0
	if selected:
		demo = maxf(0.0, 1.0 - fposmod(_t, 1.8) * 2.5)
	KrokerArt.draw(self, Transform2D(0.0, Vector2(s, s), 0.0, origin), character_id, _t,
		{"attack": demo, "cast": demo, "sucking": selected})
