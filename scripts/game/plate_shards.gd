class_name PlateShards
extends Node2D
## Trozos de plato roto en el suelo: hacen daño a Kroker si los pisa. Duran unos segundos.
## Broken plate shards on the floor: they hurt Kroker if he steps on them. They last a few seconds.

const LIFE := 7.0
const RADIUS := 46.0
const DAMAGE := 1.5

var run: Node
var _t := 0.0


func _ready() -> void:
	z_index = -1


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > LIFE or not run.running:
		queue_free()
		return
	var player: Player = run.player
	var d := player.global_position - global_position
	if Vector2(d.x, d.y / 0.45).length() < RADIUS:
		player.take_damage(DAMAGE * GameState.enemy_dmg_mult())
	queue_redraw()


func _draw() -> void:
	var a := clampf((LIFE - _t) / 0.8, 0.0, 1.0)
	if _t > LIFE - 1.5 and fmod(_t, 0.25) < 0.1:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, RADIUS, Color(Settings.warning_color(), 0.12 * a))
	draw_set_transform(Vector2.ZERO)
	Sprites.draw(self, "plate_shards", Color(1, 1, 1, a))
