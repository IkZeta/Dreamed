class_name Pickup
extends Node2D
## Objeto que a veces suelta un enemigo y Kroker recoge al pasar por encima:
##  - "milk": vaso de leche, cura un 30 % de la vida máxima.
##  - "pillow": almohada, para el siguiente golpe.
##  - "clock": despertador, congela a todos los enemigos 3 segundos.
## Desaparece al cabo de 25 segundos (parpadea los últimos 4).
## An item an enemy sometimes drops; Kroker picks it up by walking over it:
##  - "milk": glass of milk, heals 30% of max health.
##  - "pillow": pillow, blocks the next hit.
##  - "clock": alarm clock, freezes every enemy for 3 seconds.
## It vanishes after 25 seconds (blinking for the last 4).

const KINDS: Array[String] = ["milk", "pillow", "clock"]
const LIFE := 25.0
const COLORS := {"milk": Color("fbf8ff"), "pillow": Color("8fe0ff"), "clock": Color("ffd36a")}

var run: Node
var kind := "milk"
var _t := 0.0


func _ready() -> void:
	z_index = 3
	Audio.play("chime", -14.0, 0.1)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		queue_free()
		return
	var player: Player = run.player
	if run.running and player.alive and player.global_position.distance_to(global_position) < 46.0:
		_collect(player)
		return
	queue_redraw()


func _collect(player: Player) -> void:
	match kind:
		"milk":
			player.heal(player.max_hp * 0.3)
		"pillow":
			player.shield_charges = 1
		"clock":
			for e: Node in run.enemies.get_children():
				if e is Enemy and e.is_targetable():
					e.stun_t = maxf(e.stun_t, 3.0)
			run.freeze_flash()
	Audio.play("pickup", -2.0)
	run.fx.ring(global_position + Vector2(0, -16), 26.0, COLORS[kind], 0.5, 2.4)
	run.fx.text(global_position + Vector2(0, -60), tr("PICKUP_" + kind.to_upper()), COLORS[kind], 18)
	queue_free()


func _draw() -> void:
	if _t > LIFE - 4.0 and fmod(_t, 0.25) < 0.1:
		return  # parpadea antes de irse / blinks before leaving
	var hop := -absf(sin(_t * 3.0)) * 6.0
	draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(16, 5)), Color(0.05, 0.02, 0.15, 0.35))
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(Vector2(-34, -50 + hop), Vector2(68, 68)), false, Color(COLORS[kind], 0.3 + 0.1 * sin(_t * 4.0)))
	draw_set_transform(Vector2(0, hop))
	Sprites.draw(self, "pickup_" + kind)
	draw_set_transform(Vector2.ZERO)


func _ellipse(c: Vector2, r: Vector2, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
