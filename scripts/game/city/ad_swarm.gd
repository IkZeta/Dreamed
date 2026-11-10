class_name AdSwarm
extends Node2D
## Lo que forma a Evil Ad: vallas y teles que suben al cielo, giran cada vez más cerca y se juntan
## What forms Evil Ad: billboards and TVs that rise into the sky, spin closer and closer and merge

signal formed
const TIME := 4.6
var center := Vector2.ZERO          # en el mundo / in the world
var _pieces: Array[Dictionary] = []
var _t := 0.0
var _done := false

func add_piece(from: Vector2, kind: String, ad: int, delay: float) -> void:
	var a := (from - center).angle()
	_pieces.append({"from": from, "kind": kind, "ad": ad, "delay": delay, "a": a, "r0": maxf(200.0, from.distance_to(center)), "spin": randf_range(-3.0, 3.0)})

func _ready() -> void:
	z_index = 50

func _process(delta: float) -> void:
	_t += delta
	if not _done and _t >= TIME:
		_done = true
		formed.emit()
	if _t > TIME + 0.6:
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_set_transform(-global_position)
	var fade := clampf((TIME + 0.6 - _t) / 0.6, 0.0, 1.0)
	# Remolino de estática en el centro / A whirl of static in the middle
	var core := clampf(_t / TIME, 0.0, 1.0)
	for i in int(40 * core):
		var p := center + Vector2.from_angle(randf() * TAU) * randf() * 160.0 * core
		draw_rect(Rect2(p, Vector2(8, 4)), Color(1, 1, 1, randf() * 0.6 * fade))
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(center - Vector2(300, 300) * core, Vector2(600, 600) * core), false, Color("e0303a", 0.35 * core * fade))
	for pc in _pieces:
		var k := clampf((_t - float(pc["delay"])) / (TIME - float(pc["delay"])), 0.0, 1.0)
		if k <= 0.0:
			continue
		# Primero sube; luego gira alrededor del centro, cada vez más cerca / First it rises; then it circles the centre, closer and closer
		var up := clampf(k / 0.3, 0.0, 1.0)
		var orbit := clampf((k - 0.15) / 0.85, 0.0, 1.0)
		var ang: float = float(pc["a"]) + orbit * orbit * 7.0
		var rad: float = lerpf(float(pc["r0"]), 20.0, orbit * orbit)
		var circ: Vector2 = center + Vector2(cos(ang), sin(ang) * 0.55) * rad
		var rise: Vector2 = (pc["from"] as Vector2) + Vector2(0, -260.0 * up)
		var p := rise.lerp(circ, smoothstep(0.0, 1.0, orbit))
		var sc := lerpf(0.75, 0.25, orbit) * fade
		var rot := float(pc["spin"]) * k * 3.0
		draw_set_transform(p - global_position, rot, Vector2(sc, sc))
		if pc["kind"] == "board":
			CityBillboard.draw_ad(self, Rect2(-130, -70, 260, 140), int(pc["ad"]), _t * 3.0)
		else:
			draw_rect(Rect2(-60, -44, 120, 88), Color("0e0e12"))
			draw_rect(Rect2(-52, -36, 104, 72), Color("8a1420"))
			for j in 5:
				draw_rect(Rect2(randf_range(-50, 30), randf_range(-34, 30), 20, 4), Color(1, 1, 1, 0.6))
	draw_set_transform(Vector2.ZERO)
