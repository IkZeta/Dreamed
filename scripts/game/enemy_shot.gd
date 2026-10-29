class_name EnemyShot
extends Node2D
## Proyectil enemigo: piedra del tirachinas o libro lanzado por la estantería.
## Enemy projectile: a slingshot stone or a book thrown by the bookshelf.

var run: Node
var velocity := Vector2.ZERO
var damage := 3.0
var radius := 10.0
var kind := "stone"   # "stone" o "book"
var life := 3.0
var _spin := 0.0


func _ready() -> void:
	z_index = 30


func _physics_process(delta: float) -> void:
	life -= delta
	_spin += delta * (12.0 if kind == "book" else 6.0)
	position += velocity * delta
	var player: Node2D = run.player
	if run.running and global_position.distance_to(player.global_position + Vector2(0, -44)) < radius + 22.0:
		player.take_damage(damage)
		run.fx.ring(global_position, 14.0, UITheme.EMBER, 0.3, 2.0)
		queue_free()
		return
	var r: Rect2 = run.arena_rect()
	if life <= 0.0 or not r.grow(180).has_point(global_position) or not run.running:
		run.fx.dissipate(global_position, Color("cfc6e8"))
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	# Estela / Trail
	for i in 4:
		draw_circle(-velocity.normalized() * (8.0 + i * 8.0), radius * (0.7 - i * 0.15), Color(UITheme.EMBER, 0.15 - i * 0.03))
	draw_set_transform(Vector2.ZERO, _spin if kind == "book" else 0.0, Vector2.ONE)
	Sprites.draw(self, "shot_book" if kind == "book" else "shot_stone")
	draw_set_transform(Vector2.ZERO)
