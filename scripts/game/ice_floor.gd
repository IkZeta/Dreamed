class_name IceFloor
extends Node2D
## Evento «Suelo helado»: una capa de escarcha sobre el suelo. Kroker resbala: le cuesta
## arrancar, frenar y cambiar de dirección (lo hace Player con run.event == "ice").
## "Icy floor" event: a layer of frost over the floor. Kroker slides: it's hard for him to get
## going, stop and turn (Player does it with run.event == "ice").

var run: Node
var _t := 0.0
var _glints: Array[Vector3] = []   # x, y (0..1 del suelo / of the floor), fase / phase


func _ready() -> void:
	z_index = -9
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 70:
		_glints.append(Vector3(rng.randf(), rng.randf(), rng.randf() * TAU))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = run.view_rect()
	draw_rect(r, Color("bfe8ff", 0.12))
	# Vetas de hielo y destellos / Ice streaks and glints
	for g in _glints:
		var p := r.position + Vector2(g.x * r.size.x, g.y * r.size.y)
		var tw := 0.5 + 0.5 * sin(_t * 2.0 + g.z)
		draw_line(p, p + Vector2(26, -6), Color("e8f6ff", 0.12), 2.0)
		if tw > 0.85:
			DreamBackground.draw_star(self, p + Vector2(10, -3), 3.0 * (tw - 0.85) / 0.15 + 1.0, Color(1, 1, 1, 0.7))
