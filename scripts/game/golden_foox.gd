class_name GoldenFoox
extends Foox
## Foox dorado (evento): no hace daño, huye de Kroker y suelta muchos trozos de estrella
## si lo pillas. Se esfuma al cabo de un rato.
## Golden Foox (event): harmless, runs away from Kroker and drops lots of star shards if
## you catch it. It fades away after a while.

const LIFETIME := 14.0
const GOLD := Color(1.0, 0.82, 0.35)


func _init() -> void:
	super._init()
	bestiary_id = "golden_foox"
	max_hp = 30.0
	hp = max_hp
	speed = 165.0
	contact_damage = 0.0
	shards = 15


func is_dangerous() -> bool:
	return false


func _desired_velocity() -> Vector2:
	var away: Vector2 = global_position - run.player.global_position
	var r: Rect2 = run.arena_rect().grow(-80)
	var v := away.normalized()
	# Contra una pared se escurre de lado / Against a wall it slides sideways
	if not r.has_point(global_position + v * 60.0):
		v = v.orthogonal() * (1.0 if sin(_t * 0.7 + _phase) > 0.0 else -1.0)
	return v * speed


func _act(_delta: float) -> void:
	if _t > LIFETIME:
		run.fx.dissipate(aim_point(), UITheme.GOLD)
		die(false)
	elif fmod(_t, 0.2) < 0.02:
		run.fx.dissipate(aim_point() + Vector2(randf_range(-20, 20), 0), UITheme.GOLD)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	super._draw_body(offset, tint * GOLD, a)
