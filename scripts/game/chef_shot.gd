class_name ChefShot
extends Node2D
## Proyectiles del Chef:
##  - "knife": cuchillo en línea recta; si te da, sangras.
##  - "plate": plato lanzado en arco a un punto marcado en el suelo; al romperse hace daño
##    alrededor y deja trozos que hacen daño al pisarlos.
## The Chef's projectiles:
##  - "knife": a knife flying straight; if it hits you, you bleed.
##  - "plate": a plate lobbed in an arc to a spot marked on the floor; when it breaks it hurts
##    around it and leaves shards that hurt when you step on them.

const KNIFE_DAMAGE := 2.0
const BLEED_TIME := 2.4
const PLATE_DAMAGE := 3.0
const PLATE_RADIUS := 56.0
const PLATE_FLIGHT := 0.85

var run: Node
var kind := "knife"
var velocity := Vector2.ZERO
var target := Vector2.ZERO      # dónde cae el plato / where the plate lands
var _from := Vector2.ZERO
var _t := 0.0
var _life := 3.0


func _ready() -> void:
	z_index = 30
	_from = position


func _physics_process(delta: float) -> void:
	_t += delta
	if not run.running:
		queue_free()
		return
	var player: Player = run.player
	if kind == "knife":
		position += velocity * delta
		_life -= delta
		if global_position.distance_to(player.global_position + Vector2(0, -44)) < 30.0:
			var before := player.hp
			player.take_damage(KNIFE_DAMAGE * GameState.enemy_dmg_mult())
			# Solo sangra si el cuchillo le ha hecho daño de verdad / Only bleeds if the knife really hurt him
			if player.hp < before:
				player.start_bleed(BLEED_TIME)
			run.fx.ring(global_position, 14.0, Color("e8455a"), 0.3, 2.0)
			queue_free()
			return
		if _life <= 0.0 or not run.arena_rect().grow(120).has_point(global_position):
			queue_free()
			return
	else:
		var k := _t / PLATE_FLIGHT
		if k >= 1.0:
			_break()
			return
		position = _from.lerp(target, k)
	queue_redraw()


func _break() -> void:
	var player: Player = run.player
	var d := player.global_position - target
	if Vector2(d.x, d.y / 0.5).length() < PLATE_RADIUS:
		player.take_damage(PLATE_DAMAGE * GameState.enemy_dmg_mult())
	Audio.play("plate_break", -4.0, 0.1)
	run.shake(3.0)
	run.fx.ring(target, 26.0, Color("f4f1fa"), 0.35, 2.4)
	var shards := PlateShards.new()
	shards.run = run
	shards.position = target
	run.world.add_child(shards)
	queue_free()


func _draw() -> void:
	if kind == "knife":
		draw_set_transform(Vector2.ZERO, velocity.angle(), Vector2.ONE)
		Sprites.draw(self, "shot_knife")
		draw_set_transform(Vector2.ZERO)
		return
	# Marca en el suelo donde va a caer el plato / Floor mark where the plate will land
	var k := clampf(_t / PLATE_FLIGHT, 0.0, 1.0)
	var mark := target - position
	var col := Settings.warning_color()
	draw_set_transform(mark, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, PLATE_RADIUS, Color(col, 0.1 + 0.15 * k))
	draw_circle(Vector2.ZERO, PLATE_RADIUS * k, Color(col, 0.25))
	draw_arc(Vector2.ZERO, PLATE_RADIUS, 0, TAU, 28, Color(col, 0.6), 2.0)
	draw_set_transform(Vector2.ZERO)
	# El plato va en arco y girando / The plate flies in an arc, spinning
	var lift := sin(k * PI) * 160.0
	draw_set_transform(Vector2(0, -lift - 40.0), 0.0, Vector2(cos(_t * 14.0), 1.0))
	Sprites.draw(self, "shot_plate")
	draw_set_transform(Vector2.ZERO)
