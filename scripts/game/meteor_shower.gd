class_name MeteorShower
extends Node2D
## Evento «Lluvia de estrellas»: caen estrellas del cielo una tras otra. Antes de caer se marca
## en el suelo dónde van a dar; al caer, hacen daño a los enemigos de alrededor... y a Kroker si
## no se aparta. Algunas caen cerca de él, así que hay que estar atento.
## "Meteor shower" event: stars fall from the sky one after another. Before landing, where they'll
## hit is marked on the floor; when they land they hurt the enemies around... and Kroker if he
## doesn't get out of the way. Some land near him, so you have to keep an eye out.

const EVERY := 0.9          # segundos entre estrella y estrella / seconds between stars
const WARN := 1.1           # segundos de aviso antes de caer / warning seconds before landing
const RADIUS := 80.0
const DAMAGE := 14.0        # a los enemigos / to enemies
const PLAYER_DAMAGE := 2.0
const NEAR_CHANCE := 0.35   # las que caen cerca de Kroker / the ones landing near Kroker

var run: Node
var _cd := 1.5
var _stars: Array[Dictionary] = []    # {"at": Vector2, "t": tiempo que falta / time left}
var _t := 0.0


func _ready() -> void:
	z_index = 3


func _physics_process(delta: float) -> void:
	_t += delta
	if run.running:
		_cd -= delta
		if _cd <= 0.0:
			_cd = EVERY * randf_range(0.7, 1.3)
			_spawn()
	for i in range(_stars.size() - 1, -1, -1):
		var s := _stars[i]
		s["t"] = float(s["t"]) - delta
		if float(s["t"]) <= 0.0:
			_land(s["at"])
			_stars.remove_at(i)
	queue_redraw()


func _spawn() -> void:
	var view: Rect2 = run.view_rect()
	var at: Vector2
	if randf() < NEAR_CHANCE:
		at = run.player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 130.0)
	else:
		at = Vector2(randf_range(view.position.x + 60.0, view.end.x - 60.0), randf_range(view.position.y + 120.0, view.end.y - 40.0))
	at = run.clamp_to_arena(at, 20.0)
	_stars.append({"at": at, "t": WARN})


func _land(at: Vector2) -> void:
	var dmg: float = DAMAGE * GameState.enemy_hp_mult()
	for e: Node in run.enemies.get_children():
		if e is Enemy and (e as Enemy).is_targetable() and (e as Node2D).global_position.distance_to(at) < RADIUS:
			(e as Enemy).hit(dmg if not e.is_boss() else dmg * 0.5, ((e as Node2D).global_position - at).normalized() * 300.0)
	var p: Node2D = run.player
	if p.global_position.distance_to(at) < RADIUS * 0.75:
		p.take_damage(PLAYER_DAMAGE * GameState.enemy_dmg_mult(), null)
	run.fx.ring(at, RADIUS, Color("f6d993"), 0.4, 1.3)
	run.fx.dissipate(at + Vector2(0, -10), Color("f6d993"))
	run.shake(3.0)
	Audio.play("stomp", -12.0, 0.15)


func _draw() -> void:
	for s in _stars:
		var at: Vector2 = s["at"]
		var k := 1.0 - float(s["t"]) / WARN       # 0 → 1 según se acerca / as it gets closer
		# Aviso en el suelo: un círculo que se cierra / Floor warning: a closing circle
		draw_set_transform(at, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, RADIUS, Color("f6d993", 0.08 + 0.12 * k))
		draw_arc(Vector2.ZERO, RADIUS * (1.0 - k * 0.15), 0.0, TAU, 40, Color("f6d993", 0.35 + 0.5 * k), 3.0)
		draw_arc(Vector2.ZERO, RADIUS * (1.0 - k), 0.0, TAU, 32, Color("fff0a0", 0.6), 2.0)
		draw_set_transform(Vector2.ZERO)
		# La estrella cayendo en diagonal con su estela / The star falling diagonally with its trail
		var from := at + Vector2(-260, -620)
		var pos := from.lerp(at, k * k)
		var dir := (at - from).normalized()
		for j in 6:
			draw_circle(pos - dir * (j * 14.0), 9.0 - j * 1.3, Color("ffe08a", 0.5 - j * 0.07))
		DreamBackground.draw_star(self, pos, 14.0, Color("fff0a0"))
