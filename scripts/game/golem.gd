class_name Golem
extends Enemy
## Gólem de papel higiénico (Acto 3, desde el Sueño 13): un montón de rollos con un tubo de
## cartón por cabeza. Es muy lento, tiene mucha vida y pega fuerte, pero tiene poca defensa
## (recibe un 30 % más de daño). Si te pega, te deja mal olor: pierdes una de tus dos armas
## al azar durante unos segundos.
## Toilet-Paper Golem (Act 3, from Dream 13): a heap of rolls with a cardboard tube for a head.
## It's very slow, has lots of health and hits hard, but has low defence (takes 30% more
## damage). If it hits you, it leaves you smelly: you lose one of your two weapons at random
## for a few seconds.

const FRAGILE := 1.3
const STENCH_TIME := 6.0
const SLAM_REACH := 120.0
const SLAM_DAMAGE := 7.0
const SLAM_WINDUP := 0.8
const SLAM_EVERY := 2.6
const PAPER := Color("f4f2ea")
const STINK := Color("9fd86a")

var _slam_cd := 1.5
var _windup := 0.0
var _swing := 0.0


func _init() -> void:
	bestiary_id = "golem"
	max_hp = 130.0
	hp = max_hp
	contact_damage = 5.0
	radius = 44.0
	speed = 42.0
	mass = 4.0
	aim_height = 80.0
	shards = 8


## Poca defensa: recibe más daño / Low defence: takes more damage
func hit(amount: float, impulse := Vector2.ZERO) -> void:
	super.hit(amount * FRAGILE, impulse)


func _desired_velocity() -> Vector2:
	if _windup > 0.0:
		return Vector2.ZERO
	var to_player: Vector2 = run.player.global_position - global_position
	# Pasos pesados: avanza a golpes / Heavy steps: it lurches forward
	var step := 0.3 + 0.7 * absf(sin(_t * 1.6 + _phase))
	return to_player.normalized() * speed * step


func _act(delta: float) -> void:
	var k := 0.5 if slow_t > 0.0 else 1.0
	_swing = maxf(0.0, _swing - delta * 2.0)
	var to_player: Vector2 = run.player.global_position - global_position
	if _windup <= 0.0 and absf(to_player.x) > 6.0:
		_facing = signf(to_player.x)
	if _windup > 0.0:
		_windup -= delta * k
		if _windup <= 0.0:
			_slam()
		return
	_slam_cd -= delta * k
	if _slam_cd <= 0.0 and to_player.length() < SLAM_REACH:
		_windup = SLAM_WINDUP
		Audio.play("swing", -8.0, 0.05)


## Manotazo de papel: pega fuerte y deja el mal olor / Paper slap: hits hard and leaves the stench
func _slam() -> void:
	_slam_cd = SLAM_EVERY + randf_range(-0.3, 0.4)
	_swing = 1.0
	Audio.play("stomp", -4.0, 0.05)
	run.shake(5.0)
	var at := global_position + Vector2(_facing * 70.0, -10)
	run.fx.ring(at, 40.0, PAPER, 0.4, 2.2)
	var player: Player = run.player
	if player.global_position.distance_to(at) < SLAM_REACH * 0.85:
		_hurt_player(SLAM_DAMAGE)


## Tocarlo también apesta / Touching it stinks too
func _touch_player() -> void:
	var player: Node2D = run.player
	if global_position.distance_to(player.global_position + Vector2(0, -28)) < radius + 22.0:
		_hurt_player(contact_damage)


func _hurt_player(dmg: float) -> void:
	var player: Player = run.player
	var before := player.hp
	player.take_damage(dmg * GameState.enemy_dmg_mult() * atk_mult())
	if player.hp < before:
		player.stink(STENCH_TIME)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var mod := Sprites.flash_color(_flash * 0.6, a) * tint
	var step := sin(_t * 1.6 + _phase)
	draw_set_transform(offset, 0.0, Vector2(_facing, 1.0))
	draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(50, 12)), Color(0.05, 0.02, 0.15, 0.4 * a))
	# Nube de peste alrededor / Stink cloud around it
	for i in 5:
		var ph := fposmod(_t * 0.35 + i * 0.2, 1.0)
		var p := Vector2(sin(i * 2.4 + _t * 0.5) * 50.0, -30.0 - ph * 170.0)
		draw_circle(p, 8.0 + ph * 10.0, Color(STINK, 0.22 * (1.0 - ph) * a))
	var lean := step * 0.05 - 0.25 * (1.0 - _windup / SLAM_WINDUP if _windup > 0.0 else 0.0) + 0.3 * _swing
	draw_set_transform(offset + Vector2(0, -absf(step) * 4.0), lean * 0.4, Vector2(_facing, 1.0))
	# Brazo de atrás / Back arm
	draw_set_transform(offset + Vector2(-40 * _facing, -140 - absf(step) * 4.0), (0.2 - step * 0.15) * _facing, Vector2(_facing, 1.0))
	Sprites.draw(self, "golem_arm", mod)
	draw_set_transform(offset + Vector2(0, -absf(step) * 4.0), lean * 0.4, Vector2(_facing, 1.0))
	Sprites.draw(self, "golem_body", mod)
	# Tiras de papel que se arrastran / Paper streamers trailing behind
	for i in 3:
		var y := -60.0 - i * 34.0
		var pts := PackedVector2Array()
		for kk in 6:
			pts.append(Vector2(-46.0 - kk * 10.0, y + sin(_t * 3.0 + kk * 0.9 + i) * 5.0 + kk * 3.0))
		draw_polyline(pts, Color(PAPER, 0.9 * a), 5.0)
	# Brazo de delante: se levanta y pega un manotazo / Front arm: raises and slaps down
	var arm_ang := 0.15 + step * 0.15
	if _windup > 0.0:
		arm_ang = lerpf(0.15, -2.4, 1.0 - _windup / SLAM_WINDUP)
	elif _swing > 0.0:
		arm_ang = lerpf(0.15, -1.2, _swing - 0.3)
	draw_set_transform(offset + Vector2(40 * _facing, -140 - absf(step) * 4.0), arm_ang * _facing, Vector2(_facing, 1.0))
	Sprites.draw(self, "golem_arm", mod)
	draw_set_transform(Vector2.ZERO)


func _ellipse(c: Vector2, r: Vector2, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	return pts


func head_top() -> Vector2:
	return Vector2(0, -200)
