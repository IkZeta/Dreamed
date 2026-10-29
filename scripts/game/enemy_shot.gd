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


## Aviso de trayectoria antes de disparar (como en Brotato): una franja que se llena.
## "k" va de 0 a 1 mientras el enemigo apunta. Se dibuja en coordenadas del CanvasItem.
## Trajectory warning before a shot (Brotato style): a strip that fills up.
## "k" goes from 0 to 1 while the enemy aims. Drawn in the CanvasItem's coordinates.
static func draw_warning(ci: CanvasItem, from: Vector2, dir: Vector2, length: float, width: float, k: float) -> void:
	var to := from + dir * length
	var side := Vector2(-dir.y, dir.x) * width * 0.5
	var col := Settings.warning_color()
	ci.draw_colored_polygon(PackedVector2Array([from + side, to + side, to - side, from - side]), Color(col, 0.10 + 0.12 * k))
	# Lo que ya está "cargado" avanza desde el enemigo / The "charged" part grows out from the enemy
	var fill := from + dir * length * k
	var core := side * 0.35
	ci.draw_colored_polygon(PackedVector2Array([from + core, fill + core, fill - core, from - core]), Color(col, 0.35 + 0.35 * k))
	ci.draw_line(from + side, to + side, Color(col, 0.5), 2.0)
	ci.draw_line(from - side, to - side, Color(col, 0.5), 2.0)


## Hasta dónde llega un disparo antes de salir de la habitación / How far a shot goes before leaving the room
static func reach(run: Node, from: Vector2, dir: Vector2, max_len: float) -> float:
	var r: Rect2 = run.arena_rect().grow(30)
	var d := 0.0
	while d < max_len and r.has_point(from + dir * d):
		d += 12.0
	return maxf(d, 40.0)


func _ready() -> void:
	z_index = 30


func _physics_process(delta: float) -> void:
	life -= delta
	_spin += delta * (12.0 if kind == "book" else 6.0)
	position += velocity * delta
	var player: Node2D = run.player
	if run.running and global_position.distance_to(player.global_position + Vector2(0, -44)) < radius + 22.0:
		player.take_damage(damage * GameState.enemy_dmg_mult())
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
