class_name DreamTitle
extends Control
## El logo del menú: «DREAMED» con las letras cayendo una a una al entrar y luego meciéndose como
## si flotaran, con un resplandor dorado detrás y una «z» que se escapa de la última letra.
## The menu logo: "DREAMED" with the letters dropping in one by one and then swaying as if they
## floated, with a golden glow behind and a "z" escaping from the last letter.

const TEXT := "DREAMED"
var font_size := 150
var _t := 0.0
var _font: Font
var _fs := 0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_font = UITheme.font("display")
	_fs = UITheme.pixel_size(font_size)
	custom_minimum_size = _font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs) + Vector2(60, 24)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var base := _font.get_ascent(_fs) + 12.0
	var soft := DreamBackground.soft_texture()
	var w := _font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x
	var glow := 0.16 + 0.04 * sin(_t * 1.1)
	draw_texture_rect(soft, Rect2(Vector2(-60, -20), Vector2(w + 120, base + 60)), false, Color(UITheme.GOLD, glow * minf(1.0, _t)))
	for i in TEXT.length():
		var x := _font.get_string_size(TEXT.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x
		# Entrada: cae desde arriba con un rebote suave / Entrance: drops from above with a soft bounce
		var k := clampf((_t - 0.15 - i * 0.09) / 0.55, 0.0, 1.0)
		var drop := (1.0 - _ease_out_back(k)) * -60.0
		var sway := sin(_t * 1.3 - i * 0.6) * 5.0 * k
		var p := Vector2(x, base + drop + sway)
		var ch := TEXT[i]
		draw_string_outline(_font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, 10, Color(UITheme.GOLD, 0.1 * k))
		draw_string_outline(_font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, 4, Color(UITheme.MIST, 0.18 * k))
		draw_string(_font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, Color(UITheme.BONE, k))
	# Una «z» pequeña que se escapa de la D y se desvanece / A little "z" escaping the D and fading
	var zk := fposmod(_t * 0.35, 1.0)
	if _t > 1.2:
		var zp := Vector2(w + 6.0 + zk * 30.0, base - _fs * 0.6 - zk * 40.0)
		draw_string(_font, zp, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(_fs * (0.22 + zk * 0.12)), Color(UITheme.GOLD, sin(zk * PI) * 0.8))


static func _ease_out_back(k: float) -> float:
	var c1 := 1.4
	return 1.0 + (c1 + 1.0) * pow(k - 1.0, 3.0) + c1 * pow(k - 1.0, 2.0)
