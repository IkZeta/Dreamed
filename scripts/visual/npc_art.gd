class_name NpcArt
extends RefCounted
## Dibuja a los personajes del plano astral: Svinho, Stolk y Silly.
## Mismo lienzo que Kroker (200 x 300, pies en y = 288) y la misma luz suave.
## Draws the astral plane characters: Svinho, Stolk and Silly.
## Same canvas as Kroker (200 x 300, feet at y = 288) and the same soft light.

static var _ci: CanvasItem
static var _xf: Transform2D


static func draw(ci: CanvasItem, xf: Transform2D, who: String, t: float) -> void:
	_ci = ci
	var breath := 1.0 + sin(t * 1.6) * 0.01
	_xf = xf * Transform2D(0.0, Vector2(1.0, breath), 0.0, Vector2(0, 288.0 * (1.0 - breath)))
	_ci.draw_set_transform_matrix(_xf)
	match who:
		"svinho": _svinho(t)
		"stolk": _stolk(t)
		"silly": _silly(t)
		"doc": _doc(t)
		"charo": _charo(t)
		"ad": _ad(t)
	_ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# --- Personajes en pixel art (tools/make_sprites.py) con detalles animados encima
# --- Pixel-art characters (tools/make_sprites.py) with animated details on top

static func _svinho(t: float) -> void:
	Sprites.draw(_ci, "npc_svinho")
	# Balón botando / Bouncing ball
	var bounce := absf(sin(t * 3.2))
	var ball := Vector2(150, 274 - bounce * 40.0)
	_ci.draw_colored_polygon(_ellipse(Vector2(150, 286), Vector2(12 - bounce * 4.0, 3)), Color(0, 0, 0, 0.25))
	_ci.draw_set_transform_matrix(_xf * Transform2D(t * 3.0, ball))
	Sprites.draw(_ci, "npc_ball")
	_ci.draw_set_transform_matrix(_xf)


## Mr. Ad: sus carteles parpadean como neones / Mr. Ad: his signs blink like neon
static func _ad(t: float) -> void:
	Sprites.draw(_ci, "npc_ad")
	var blink := fmod(t, 1.2) < 0.6
	_ci.draw_rect(Rect2(68, 102, 64, 26), Color("fff6c9", 0.25 if blink else 0.0))
	# Estrellitas de «¡oferta!» girando / Spinning "special offer!" sparkles
	for i in 3:
		var a := t * 2.0 + i * TAU / 3.0
		DreamBackground.draw_star(_ci, Vector2(100, 150) + Vector2(cos(a) * 62.0, sin(a) * 20.0), 3.0, Color("f6c24a", 0.8))


## La Kioskera Charo; sus gafas brillan de vez en cuando / Kiosk lady Charo; her glasses glint now and then
static func _charo(t: float) -> void:
	Sprites.draw(_ci, "npc_charo")
	var glint := fposmod(t, 4.0)
	if glint < 0.25:
		_ci.draw_rect(Rect2(86 + glint * 40.0, 75, 3, 3), Color(1, 1, 1, 0.8))


static func _stolk(t: float) -> void:
	Sprites.draw(_ci, "npc_stolk")
	# Aura roja que late / Pulsing red aura
	_ci.draw_arc(Vector2(100, 150), 90 + sin(t * 3.0) * 4.0, 0, TAU, 48, Color("ff7a8a", 0.12), 3.0, true)


static func _silly(t: float) -> void:
	# El portátil le ilumina la cara / The laptop lights up her face
	_ci.draw_texture_rect(DreamBackground.soft_texture(), Rect2(40, 60, 120, 140), false, Color("5ff2ff", 0.18))
	Sprites.draw(_ci, "npc_silly")
	# Pantalla y código que brillan / Glowing screen and code
	_ci.draw_rect(Rect2(76, 125, 50, 20), Color("5ff2ff", 0.45 + 0.15 * sin(t * 5.0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t * 6.0)
	for row in 5:
		var y := 168.0 + row * 6.0
		var x := 66.0 + rng.randf_range(0, 10)
		while x < 132.0:
			var w := rng.randf_range(4, 12)
			_ci.draw_rect(Rect2(x, y, w, 2.5), Color("7dffb0", rng.randf_range(0.2, 0.6)))
			x += w + rng.randf_range(3, 8)


static func _doc(t: float) -> void:
	Sprites.draw(_ci, "npc_doc")
	# Espejo frontal que brilla / Glowing head mirror
	var glint := 0.6 + 0.4 * sin(t * 2.0)
	_ci.draw_rect(Rect2(97, 37, 6, 6), Color(1, 1, 1, glint))


# --- Utilidades / Helpers -----------------------------------------------------

static func _ellipse(c: Vector2, r: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
