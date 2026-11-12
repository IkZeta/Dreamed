class_name HudCombo
extends Control
## La racha del HUD: «×12» grande que da un saltito con cada muerte, cambia de color según lo larga
## que sea (hueso, oro, coral, rosa y, a partir de 100, arcoíris de sueño) y debajo una barrita que
## se vacía: si llega al final sin otra muerte, la racha se acaba. En 10, 25, 50, 100 y 200 sale un
## rótulo («¡En racha!», «¡Imparable!»...).
## The HUD streak: a big "×12" that hops with each kill, changes colour with its length (bone,
## gold, coral, pink and, from 100, a dreamy rainbow) and underneath a little bar that drains: if it
## runs out without another kill, the streak ends. At 10, 25, 50, 100 and 200 a caption shows up
## ("On a roll!", "Unstoppable!"...).

const SHOW_FROM := 3
const INK := Color("140e26")

var _n := 0
var _k := 0.0
var _pop := 0.0
var _alpha := 0.0
var _shown := false
var _t := 0.0
var _tag := ""
var _tag_t := 0.0


static func tier_color(n: int) -> Color:
	if n >= 100:
		return Color.from_hsv(fposmod(Time.get_ticks_msec() / 1600.0, 1.0), 0.45, 1.0)
	if n >= 50:
		return Color("ff9fc8")
	if n >= 25:
		return Color("ff9a6a")
	if n >= 10:
		return Color("f6d993")
	return Color("f4f1ea")


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func set_combo(n: int, k: float) -> void:
	if n != _n:
		_pop = 1.0
	_n = n
	_k = k
	_shown = n >= SHOW_FROM


func end_combo() -> void:
	_shown = false


func milestone(idx: int) -> void:
	_tag = tr("STREAK_%d" % idx)
	_tag_t = 1.6
	_pop = 1.6


func _process(delta: float) -> void:
	_t += delta
	_pop = move_toward(_pop, 0.0, delta * 5.0)
	_tag_t = maxf(0.0, _tag_t - delta)
	_alpha = move_toward(_alpha, 1.0 if _shown else 0.0, delta * (6.0 if _shown else 2.0))
	if _alpha > 0.0 or _tag_t > 0.0:
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.0 and _tag_t <= 0.0:
		return
	var col := tier_color(_n)
	var big := UITheme.font("display")
	var caps := UITheme.font("caps")
	var a := _alpha
	var right := size.x
	# Número grande con su sombra / Big number with its shadow
	var scale := 1.0 + 0.35 * _pop
	var fs := int(UITheme.pixel_size(54) * scale)
	var s := "×%d" % _n
	var w := big.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(right - w, 60.0 + 10.0 * _pop * 0.3)
	var wob := Vector2(0, sin(_t * 8.0) * 2.0 * minf(1.0, _n / 50.0))
	draw_string(big, (p + wob + Vector2(4, 5)).round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, 0.6 * a))
	UITheme.ink_text(self, big, (p + wob).round(), s, fs, Color(col, a), 3.0)
	# Brillo que cruza con cada muerte / A shine crossing with each kill
	if _pop > 0.0:
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(p + Vector2(-20, -fs * 0.9), Vector2(w + 40, fs * 1.2)), false, Color(col, 0.25 * _pop * a))
	var lab := tr("STREAK")
	var lfs := UITheme.pixel_size(15)
	var lw := caps.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	UITheme.ink_text(self, caps, Vector2(right - lw, 90).round(), lab, lfs, Color(UITheme.ASH, a), 2.0)
	# Barrita que se vacía / Draining bar
	var bw := 150.0
	draw_rect(Rect2(right - bw - 2, 98, bw + 4, 8), Color(INK, 0.8 * a))
	draw_rect(Rect2(right - bw, 100, bw * clampf(_k, 0.0, 1.0), 4), Color(col, a))
	# Rótulo de los hitos / Milestone caption
	if _tag_t > 0.0:
		var k := minf(1.0, _tag_t / 0.4) * minf(1.0, (1.6 - _tag_t) * 6.0)
		var tfs := int(UITheme.pixel_size(24) * (1.0 + 0.2 * maxf(0.0, _tag_t - 1.2) * 2.5))
		var tw := caps.get_string_size(_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		var tp := Vector2(right - tw, 136)
		UITheme.ink_text(self, caps, tp.round(), _tag, tfs, Color(col, k), 3.0)
