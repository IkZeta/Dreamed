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
## Devuelto por el giro de las botas: ahora daña a los enemigos / Sent back by the boots' spin: now it hurts enemies
var reflected := false
## Segundos de sangrado al dar a Kroker (las balas de la policía) / Seconds of bleeding on hitting Kroker (police bullets)
var bleed := 0.0
## Quién lo disparó (para el diario) / Who fired it (for the diary)
var cause := ""


## Lo devuelve hacia el enemigo más cercano (o por donde vino) / Sends it back towards the nearest enemy (or the way it came)
func reflect(target: Node2D) -> void:
	reflected = true
	life = 2.0
	var spd := velocity.length() * 1.3
	if target:
		velocity = (target.global_position + Vector2(0, -30) - global_position).normalized() * spd
	else:
		velocity = -velocity.normalized() * spd


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
	if reflected:
		for e: Node in run.enemies.get_children():
			if e is Enemy and (e as Enemy).is_targetable() and global_position.distance_to((e as Enemy).aim_point()) < radius + 26.0:
				(e as Enemy).hit(damage * 3.0, velocity.normalized() * 200.0)
				run.fx.ring(global_position, 18.0, Color("ffd27a"), 0.3, 2.0)
				queue_free()
				return
	elif run.running and global_position.distance_to(player.global_position + Player.HURT) < radius + Player.HURT_R:
		var before: float = player.hp
		player.take_damage(damage * GameState.enemy_dmg_mult(), self)
		if bleed > 0.0 and player.hp < before:
			player.start_bleed(bleed)
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
	if kind == "bullet":
		# Bala del fusil: trazo corto amarillo / Rifle bullet: a short yellow streak
		var tl := -velocity.normalized() * 22.0
		draw_line(tl, Vector2.ZERO, Color("ffb04a", 0.5), 6.0)
		draw_line(tl * 0.6, Vector2.ZERO, Color("fff0a0"), 3.0)
		return
	if kind == "coin":
		# Moneda roja de Evil Ad, girando, con su «$» / Evil Ad's red coin, spinning, with its "$"
		var sx := absf(cos(_spin * 1.5))
		draw_circle(-velocity.normalized() * 12.0, radius * 0.7, Color("e0303a", 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(maxf(0.25, sx), 1.0))
		draw_circle(Vector2.ZERO, radius + 2.0, Color("3a0810"))
		draw_circle(Vector2.ZERO, radius, Color("e0303a"))
		draw_circle(Vector2.ZERO, radius * 0.7, Color("ff6a6a"))
		draw_line(Vector2(0, -6), Vector2(0, 6), Color("3a0810"), 3.0)
		draw_arc(Vector2(0, -2), 4.0, PI * 0.3, PI * 1.6, 6, Color("3a0810"), 2.0)
		draw_set_transform(Vector2.ZERO)
		return
	if kind == "laser":
		# Rayo láser del Ovni: trazo rojo con el centro blanco / UFO laser bolt: red streak with a white core
		var tail := -velocity.normalized() * 44.0
		draw_line(tail, Vector2.ZERO, Color("ff3a5a", 0.35), 14.0)
		draw_line(tail, Vector2.ZERO, Color("ff5f7a"), 7.0)
		draw_line(tail * 0.8, Vector2.ZERO, Color.WHITE, 3.0)
		return
	# Estela (dorada si lo han devuelto) / Trail (golden if it was sent back)
	var trail := Color("ffd27a") if reflected else UITheme.EMBER
	for i in 4:
		draw_circle(-velocity.normalized() * (8.0 + i * 8.0), radius * (0.7 - i * 0.15), Color(trail, 0.15 - i * 0.03))
	draw_set_transform(Vector2.ZERO, _spin if kind == "book" else 0.0, Vector2.ONE)
	Sprites.draw(self, "shot_book" if kind == "book" else "shot_stone")
	draw_set_transform(Vector2.ZERO)
