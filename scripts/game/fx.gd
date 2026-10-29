class_name FX
extends Node2D
## Efectos visuales de la partida dibujados en una sola capa: números de daño,
## rayos, tajos, anillos y disipaciones.
## In-game visual effects drawn on one layer: damage numbers, lightning bolts,
## swings, rings and dissipations.

var _items: Array[Dictionary] = []


func _ready() -> void:
	z_index = 50


func text(pos: Vector2, value: String, color := UITheme.BONE, size := 22) -> void:
	# El mundo se ve a la mitad (pixel art): los textos van un poco más grandes para leerse
	# The world is shown at half size (pixel art): texts are a bit bigger to stay readable
	size = int(size * 1.35)
	_items.append({"kind": "text", "pos": pos, "text": value, "color": color, "size": size,
		"life": 0.8, "max": 0.8, "vel": Vector2(randf_range(-20, 20), -70)})


func bolt(points: PackedVector2Array, color := UITheme.GOLD) -> void:
	_items.append({"kind": "bolt", "points": points, "color": color, "life": 0.3, "max": 0.3})


func swing(center: Vector2, radius: float, angle: float, spread: float, color := UITheme.BONE, width := 6.0) -> void:
	_items.append({"kind": "swing", "pos": center, "r": radius, "a": angle, "s": spread,
		"color": color, "w": width, "life": 0.18, "max": 0.18})


func ring(center: Vector2, radius: float, color := UITheme.MIST, life := 0.5, grow := 1.6) -> void:
	_items.append({"kind": "ring", "pos": center, "r": radius, "color": color,
		"life": life, "max": life, "grow": grow})


func telegraph(center: Vector2, life: float) -> void:
	_items.append({"kind": "tele", "pos": center, "life": life, "max": life})


func dissipate(center: Vector2, color := UITheme.BONE) -> void:
	for i in 14:
		var a := randf() * TAU
		_items.append({"kind": "mote", "pos": center + Vector2(randf_range(-14, 14), randf_range(-24, 0)),
			"vel": Vector2(cos(a), sin(a)) * randf_range(30, 110) + Vector2(0, -40),
			"color": color, "life": randf_range(0.5, 0.9), "max": 0.9, "r": randf_range(1.5, 3.5)})


func _process(delta: float) -> void:
	for i in range(_items.size() - 1, -1, -1):
		var it := _items[i]
		it["life"] = float(it["life"]) - delta
		if float(it["life"]) <= 0.0:
			_items.remove_at(i)
			continue
		if it.has("vel"):
			it["pos"] = Vector2(it["pos"]) + Vector2(it["vel"]) * delta
			it["vel"] = Vector2(it["vel"]) * (1.0 - 2.0 * delta)
	queue_redraw()


func _draw() -> void:
	var font := UITheme.font("caps")
	for it in _items:
		var k := float(it["life"]) / float(it["max"])  # 1 → 0
		var col: Color = it.get("color", UITheme.BONE)
		match it["kind"]:
			"text":
				var c := Color(col, minf(1.0, k * 2.0))
				var s := String(it["text"])
				var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, it["size"]).x
				draw_string(font, Vector2(it["pos"]) - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, it["size"], c)
			"bolt":
				# Grueso para que se vea en pixel art / Thick so it shows in pixel art
				draw_polyline(it["points"], Color(col, 0.3 * k), 16.0)
				draw_polyline(it["points"], Color(col, k), 6.0)
				draw_polyline(it["points"], Color(1, 1, 1, k), 2.5)
			"swing":
				var a := float(it["a"])
				var sp := float(it["s"])
				var r := float(it["r"])
				for j in 4:
					var rr := r - j * 5.0
					draw_arc(it["pos"], rr, a - sp, a + sp, 24, Color(col, k * (0.8 - j * 0.18)), float(it["w"]) - j, true)
			"ring":
				var r := float(it["r"]) * lerpf(float(it["grow"]), 1.0, k)
				draw_arc(it["pos"], r, 0, TAU, 48, Color(col, k * 0.8), 2.0, true)
			"tele":
				var p := 1.0 - k
				var c := Vector2(it["pos"])
				draw_arc(c, 30.0 * (1.0 - p) + 10.0, 0, TAU, 40, Color(UITheme.MIST, 0.25 + 0.5 * p), 1.5, true)
				draw_circle(c, 18.0 * p, Color(UITheme.MIST, 0.12 * p))
			"mote":
				draw_circle(it["pos"], float(it["r"]) * k, Color(col, k * 0.8))
