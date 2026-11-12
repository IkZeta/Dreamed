class_name HoleTutorial
extends Node2D
## Tutorial integrado del primer agujero: la primera vez que se abre un agujero (Sueño 2) salen
## unos Foox entre Kroker y el agujero, y el agujero brilla con una flecha y un cartel hasta que
## tiras al primero (o pasa un rato). Sin pausas ni ventanas: se aprende jugando.
## Built-in first-hole tutorial: the first time a hole opens (Dream 2) a few Foox spawn between
## Kroker and the hole, and the hole glows with an arrow and a sign until you throw the first one
## in (or a while passes). No pauses or windows: you learn by playing.

const MAX_TIME := 25.0
const FOOX := 3

var run: Run
var hole := Rect2()
var _t := 0.0
var _falls0 := 0
var _out := 0.0


## Solo la primera vez, si el sueño tiene agujero / Only the first time, if the dream has a hole
static func wanted(r: Run) -> bool:
	if GameState.training or GameState.god_mode or int(Progress.stats.get("tut_hole", 0)) > 0:
		return false
	if int(Progress.stats.get("falls", 0)) > 0:
		return false
	return r.room != null and r.room.hole_count() > 0 and not r.room.follows_camera()


static func start(r: Run) -> void:
	var t := HoleTutorial.new()
	t.run = r
	# El agujero más cercano a Kroker / The hole closest to Kroker
	var best := Rect2()
	var list: Array[Rect2] = r.room.holes_list()
	for i in r.room.hole_count():
		var rc := Bedroom.rect_world(list[i])
		if best.size == Vector2.ZERO or rc.get_center().distance_to(r.player.position) < best.get_center().distance_to(r.player.position):
			best = rc
	t.hole = best
	t._falls0 = GameState.run_falls
	t.z_index = 1
	r.fx.get_parent().add_child(t)
	Progress.stats["tut_hole"] = 1
	Progress.save_progress()
	# Foox entre Kroker y el agujero, un poco más cerca del agujero / Foox between Kroker and the hole, a bit nearer the hole
	var c := best.get_center()
	var dir := (r.player.position - c).normalized()
	var side := dir.orthogonal()
	for i in FOOX:
		var p := c + dir * (best.size.length() * 0.5 + 70.0 + 40.0 * i) + side * (i - 1) * 70.0
		r.spawn_enemy_soon("foox", r.clamp_to_arena(p, 30.0), 0.5 + 0.35 * i)


func _process(delta: float) -> void:
	_t += delta
	var done := GameState.run_falls > _falls0 or _t > MAX_TIME or not run.running
	if done:
		_out += delta * 2.5
		if _out >= 1.0:
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	var a := clampf(_t * 2.0, 0.0, 1.0) * (1.0 - clampf(_out, 0.0, 1.0))
	if a <= 0.0:
		return
	var c := hole.get_center()
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var rx := hole.size.x * 0.5 + 18.0 + 10.0 * pulse
	var ry := hole.size.y * 0.5 + 12.0 + 6.0 * pulse
	_ellipse(c, rx, ry, Color(UITheme.GOLD, 0.85 * a), 4.0)
	_ellipse(c, rx + 14.0, ry + 9.0, Color(UITheme.GOLD, 0.3 * a), 2.0)
	# Flecha que bota encima / Bouncing arrow above it
	var tip := c + Vector2(0, -hole.size.y * 0.5 - 26.0 - 12.0 * absf(sin(_t * 4.0)))
	var pts := PackedVector2Array([tip, tip + Vector2(-20, -24), tip + Vector2(-8, -24), tip + Vector2(-8, -50),
		tip + Vector2(8, -50), tip + Vector2(8, -24), tip + Vector2(20, -24)])
	draw_colored_polygon(pts, Color(UITheme.GOLD, a))
	pts.append(tip)
	draw_polyline(pts, Color(UITheme.INK, a), 3.0)
	# Cartel / Sign
	var f := UITheme.font("caps")
	var txt := tr("TUT_HOLE").to_upper()
	var fs := 30
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(c.x - w * 0.5, tip.y - 66.0)
	draw_rect(Rect2(at + Vector2(-14, -fs - 4), Vector2(w + 28, fs + 18)), Color(UITheme.VOID, 0.8 * a))
	UITheme.ink_text(self, f, at.round(), txt, fs, Color(UITheme.GOLD, a), 2.0)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var ang := TAU * i / 40.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_polyline(pts, col, w, true)
