class_name CityFall
extends Node2D
## Un edificio de la Metrópolis se derrumba: primero se ve su sombra en el suelo (aviso), luego el
## rascacielos se inclina y cae a lo largo de la calle, y sus escombros cortan el paso un rato.
## Lo que pilla debajo recibe mucho daño (Kroker también, si no se aparta).
## A Metropolis building collapses: first its shadow shows on the ground (warning), then the
## skyscraper leans and falls along the street, and its rubble blocks the way for a while.
## Whatever's caught underneath takes a lot of damage (Kroker too, if he doesn't move).

const WARN := 1.6
const FALL := 0.55
const LENGTH := 420.0       # largo de los escombros (lienzo) / rubble length (canvas)
const DEPTH := 120.0
const ENEMY_DAMAGE := 60.0
const PLAYER_DAMAGE := 3.0

var run: Node
var room: Act4Room
var dir := 1.0              # hacia dónde cae / which way it falls
var rect := Rect2()         # escombros en el lienzo / rubble on the canvas
var _t := 0.0
var _landed := false


## Prepara la caída en un punto del lienzo / Sets up the fall at a canvas point
func setup(r: Node, at: Vector2, d: float) -> void:
	run = r
	room = r.room
	dir = d
	rect = Rect2(at - Vector2(LENGTH / 2.0, DEPTH / 2.0), Vector2(LENGTH, DEPTH))
	position = Bedroom.to_world(Vector2(rect.get_center().x, rect.end.y))
	scale = Vector2(Bedroom.S, Bedroom.S)
	Audio.play("rumble", -6.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _landed and _t >= WARN + FALL:
		_land()
	if _landed and room.rubble_left(rect) <= 0.0:
		queue_free()
	queue_redraw()


func _land() -> void:
	_landed = true
	room.add_rubble(rect)
	var wr := Bedroom.rect_world(rect)
	for e: Node in run.enemies.get_children():
		if e is Enemy and (e as Enemy).is_targetable() and wr.grow(20.0).has_point((e as Node2D).global_position):
			(e as Enemy).hit(ENEMY_DAMAGE * GameState.enemy_hp_mult() * (0.3 if e.is_boss() else 1.0), Vector2(0, 400))
	if wr.grow(10.0).has_point(run.player.global_position):
		run.player.take_damage(PLAYER_DAMAGE * GameState.enemy_dmg_mult(), null)
	run.shake(12.0)
	run.fx.ring(wr.get_center(), wr.size.x * 0.6, Color("c8c4d8"), 0.6, 1.3)
	for i in 4:
		run.fx.dissipate(wr.get_center() + Vector2(randf_range(-wr.size.x * 0.45, wr.size.x * 0.45), randf_range(-20, 10)), Color("b8b4c8"))
	Audio.play("stomp", -2.0)
	Audio.play("crack", -4.0)


func _draw() -> void:
	var w := rect.size.x
	var d := rect.size.y
	var style := room.style
	if not _landed:
		# Sombra que crece en el suelo y rayas de aviso / Shadow growing on the ground and warning stripes
		var k := clampf(_t / WARN, 0.0, 1.0)
		var shadow := Rect2(-w / 2.0, -d, w, d)
		draw_rect(shadow, Color(0.05, 0.02, 0.12, 0.15 + 0.35 * k))
		var col := Settings.warning_color()
		draw_rect(shadow, Color(col, 0.4 + 0.4 * k), false, 4.0)
		for i in 6:
			var x := -w / 2.0 + fposmod(i * 80.0 + _t * 120.0, w)
			draw_line(Vector2(x, -d), Vector2(minf(x + 40.0, w / 2.0), 0), Color(col, 0.35 * k), 6.0)
		# El rascacielos se inclina y cae / The skyscraper leans and falls
		var f := clampf((_t - WARN + 0.3) / (FALL + 0.3), 0.0, 1.0)
		var base := Vector2(-w / 2.0 * dir, -d / 2.0)
		var ang := dir * (PI / 2.0) * f * f
		draw_set_transform(base, ang, Vector2(0.75, 0.75))
		Sprites.draw(self, "city_%s_tower" % style, Color(1, 1, 1, clampf(_t * 2.0, 0.0, 1.0)))
		draw_set_transform(Vector2.ZERO)
		return
	# Escombros que se desvanecen al final / Rubble that fades at the end
	var a := room.rubble_left(rect)
	draw_set_transform(Vector2(-w * 0.22, 0), 0.0, Vector2(0.75, 0.8))
	Sprites.draw(self, "city_%s_rubble" % style, Color(1, 1, 1, a))
	draw_set_transform(Vector2(w * 0.22, -6), 0.0, Vector2(-0.75, 0.8))
	Sprites.draw(self, "city_%s_rubble" % style, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)
