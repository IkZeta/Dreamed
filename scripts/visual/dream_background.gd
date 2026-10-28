class_name DreamBackground
extends Control
## Cielo de ensueño: noche muy estrellada con vía láctea, nebulosas suaves,
## estrellas que titilan, estrellas fugaces y una luna luminosa.
## Dreamy sky: a star-filled night with a milky way, soft nebulae, twinkling
## stars, shooting stars and a glowing moon.

@export var halo := Vector2(0.78, 0.2)   # posición de la luna / moon position (0..1)
@export var show_halo := true           # mostrar la luna / show the moon
@export var star_count := 420

const TOP := Color("0a0f33")
const MID := Color("1c2570")
const BOTTOM := Color("4a3a8c")
const HORIZON := Color("8a6fb8")

static var _soft: GradientTexture2D

var _stars: Array[Dictionary] = []
var _nebulae: Array[Dictionary] = []
var _shooting: Array[Dictionary] = []
var _next_shoot := 2.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_soft = soft_texture()
	_rng.seed = 21
	for i in star_count:
		# La mitad de las estrellas se agrupan en la vía láctea (una banda diagonal)
		# Half the stars gather along the milky way (a diagonal band)
		var p: Vector2
		if i % 2 == 0:
			var u := _rng.randf()
			p = Vector2(u, 0.95 - u * 0.75 + _rng.randfn(0.0, 0.07))
		else:
			p = Vector2(_rng.randf(), _rng.randf())
		var big := _rng.randf() < 0.06
		_stars.append({
			"p": p, "r": _rng.randf_range(1.6, 2.8) if big else _rng.randf_range(0.5, 1.5),
			"big": big, "ph": _rng.randf() * TAU, "sp": _rng.randf_range(0.8, 2.6),
			"c": [UITheme.BONE, Color("cfe0ff"), Color("ffe7c2"), Color("e6d4ff")][_rng.randi() % 4],
		})
	var cols := [Color("6b5bd6"), Color("3f8fc9"), Color("c86fb6"), Color("5a7ee8")]
	for i in 6:
		var u := _rng.randf()
		_nebulae.append({
			"p": Vector2(u, 0.9 - u * 0.7 + _rng.randf_range(-0.12, 0.12)),
			"s": _rng.randf_range(0.25, 0.45), "c": cols[i % 4], "a": _rng.randf_range(0.10, 0.18),
			"ph": _rng.randf() * TAU,
		})


static func soft_texture() -> GradientTexture2D:
	if _soft:
		return _soft
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.5))
	_soft = GradientTexture2D.new()
	_soft.gradient = g
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(0.5, 0.0)
	_soft.width = 256
	_soft.height = 256
	return _soft


func _process(delta: float) -> void:
	_t += delta
	_next_shoot -= delta
	if _next_shoot <= 0.0:
		_next_shoot = _rng.randf_range(3.0, 7.0)
		_shooting.append({"p": Vector2(_rng.randf_range(0.1, 0.9), _rng.randf_range(0.05, 0.4)),
			"life": 0.9, "dir": Vector2(-1, 0.45).normalized().rotated(_rng.randf_range(-0.2, 0.2))})
	for i in range(_shooting.size() - 1, -1, -1):
		_shooting[i]["life"] = float(_shooting[i]["life"]) - delta
		if float(_shooting[i]["life"]) <= 0.0:
			_shooting.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var m1 := h * 0.45
	var m2 := h * 0.85
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, m1), Vector2(0, m1)]),
		PackedColorArray([TOP, TOP, MID, MID]))
	draw_polygon(PackedVector2Array([Vector2(0, m1), Vector2(w, m1), Vector2(w, m2), Vector2(0, m2)]),
		PackedColorArray([MID, MID, BOTTOM, BOTTOM]))
	draw_polygon(PackedVector2Array([Vector2(0, m2), Vector2(w, m2), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([BOTTOM, BOTTOM, HORIZON, HORIZON]))

	# Nebulosas y vía láctea / Nebulae and milky way
	for n in _nebulae:
		var p: Vector2 = n["p"]
		var s := float(n["s"]) * w
		var breathe := 1.0 + sin(_t * 0.25 + float(n["ph"])) * 0.06
		draw_texture_rect(_soft, Rect2(p.x * w - s * breathe, p.y * h - s * 0.5, s * 2.0 * breathe, s), false, Color(n["c"], n["a"]))
	draw_set_transform(Vector2(w * 0.5, h * 0.55), -0.6, Vector2.ONE)
	draw_texture_rect(_soft, Rect2(-w * 0.75, -h * 0.12, w * 1.5, h * 0.24), false, Color("c9c4ff", 0.10))
	draw_set_transform(Vector2.ZERO)

	# Estrellas / Stars
	for s in _stars:
		var p: Vector2 = s["p"]
		var tw := 0.55 + 0.45 * sin(_t * float(s["sp"]) + float(s["ph"]))
		var pos := Vector2(p.x * w, p.y * h)
		var col: Color = s["c"]
		if s["big"]:
			draw_star(self, pos, float(s["r"]) * (0.8 + 0.4 * tw), Color(col, 0.6 + 0.4 * tw))
		else:
			draw_circle(pos, s["r"], Color(col, 0.3 + 0.6 * tw))

	# Estrellas fugaces / Shooting stars
	for sh in _shooting:
		var k := float(sh["life"]) / 0.9
		var head := Vector2(sh["p"]) * Vector2(w, h) + Vector2(sh["dir"]) * (1.0 - k) * w * 0.35
		var tail := head - Vector2(sh["dir"]) * 160.0
		draw_line(tail, head, Color(UITheme.BONE, 0.0), 2.0)
		var pts := PackedVector2Array([tail, head])
		draw_polyline_colors(pts, PackedColorArray([Color(UITheme.BONE, 0.0), Color(UITheme.BONE, 0.8 * sin(k * PI))]), 2.0, true)

	# Luna / Moon
	if show_halo:
		var c := Vector2(halo.x * w, halo.y * h)
		var r := h * 0.07
		draw_texture_rect(_soft, Rect2(c - Vector2(r, r) * 5.0, Vector2(r, r) * 10.0), false, Color("cdd8ff", 0.22))
		draw_circle(c, r, Color("fbf4e2"))
		draw_circle(c + Vector2(-r * 0.3, -r * 0.2), r * 0.18, Color("ece2c8"))
		draw_circle(c + Vector2(r * 0.35, r * 0.25), r * 0.12, Color("ece2c8"))
		draw_circle(c + Vector2(r * 0.1, r * 0.45), r * 0.08, Color("ece2c8"))

	# Bruma luminosa en el horizonte / Glowing haze on the horizon
	draw_texture_rect(_soft, Rect2(-w * 0.2, h * 0.8, w * 1.4, h * 0.5), false, Color("b79be0", 0.18))


## Estrella brillante con destellos en cruz / Bright star with cross-shaped glints
static func draw_star(ci: CanvasItem, pos: Vector2, r: float, color: Color) -> void:
	ci.draw_texture_rect(soft_texture(), Rect2(pos - Vector2(r, r) * 4.0, Vector2(r, r) * 8.0), false, Color(color, color.a * 0.35))
	ci.draw_line(pos - Vector2(r * 4.0, 0), pos + Vector2(r * 4.0, 0), Color(color, color.a * 0.5), 1.0, true)
	ci.draw_line(pos - Vector2(0, r * 4.0), pos + Vector2(0, r * 4.0), Color(color, color.a * 0.5), 1.0, true)
	ci.draw_circle(pos, r, color)
