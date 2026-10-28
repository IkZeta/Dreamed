class_name Foox
extends Enemy
## Foox: zorro fantasma. Lento, frágil y de poco daño. Aparece desde el Sueño 1.
## Foox: a ghost fox. Slow, fragile and low damage. Appears from Dream 1.

const EYES := Color("bfe6e2")

static var _glow: GradientTexture2D


func _init() -> void:
	max_hp = 16.0
	hp = max_hp
	contact_damage = 2.0
	radius = 22.0
	speed = 95.0
	aim_height = 18.0


func _ready() -> void:
	super._ready()
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.8))
		g.set_color(1, Color(1, 1, 1, 0))
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(0.5, 0.0)


## Serpentea un poco, como si flotara / Weaves slightly, as if floating
func _desired_velocity() -> Vector2:
	var dir: Vector2 = (run.player.global_position - global_position).normalized()
	var side := Vector2(-dir.y, dir.x) * sin(_t * 2.0 + _phase) * 0.45
	return (dir + side).normalized() * speed


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var body := Color("dfe3f0").lerp(Color.WHITE, _flash) * tint
	draw_set_transform(offset, 0.0, Vector2(_facing, 1.0))
	draw_texture_rect(_glow, Rect2(-60, -70, 120, 100), false, Color(UITheme.MIST, 0.22 * a))
	# Cola de humo que ondula / Smoky tail that ripples
	for i in 14:
		var k := i / 13.0
		var p := Vector2(-18 - k * 46.0, -16 - k * 18.0 + sin(_t * 4.0 - k * 4.0 + _phase) * 8.0 * k)
		draw_circle(p, lerpf(10.0, 2.0, k), Color(body, a * lerpf(0.42, 0.04, k)))
	# Cuerpo que se deshace por abajo / Body dissolving at the bottom
	var torso := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		torso.append(Vector2(cos(t) * 22.0, -16.0 + sin(t) * 12.0))
	draw_colored_polygon(torso, Color(body, 0.5 * a))
	for i in 4:
		var x := -14.0 + i * 9.0
		var y := -2.0 + fposmod(_t * 14.0 + i * 5.0, 14.0)
		draw_circle(Vector2(x, y), 4.0 * (1.0 - (y + 2.0) / 16.0), Color(body, 0.25 * a))
	# Cabeza con hocico y orejas / Head with snout and ears
	var head := PackedVector2Array([
		Vector2(8, -30), Vector2(13, -46), Vector2(19, -34), Vector2(25, -46), Vector2(29, -30),
		Vector2(44, -22), Vector2(30, -16), Vector2(14, -18),
	])
	draw_colored_polygon(head, Color(body, 0.75 * a))
	draw_polyline(head + PackedVector2Array([head[0]]), Color(1, 1, 1, 0.35 * a), 1.0, true)
	draw_line(Vector2(22, -27), Vector2(28, -25), Color(EYES, a), 2.2, true)
	draw_circle(Vector2(26, -26), 5.0, Color(EYES, 0.15 * a))
