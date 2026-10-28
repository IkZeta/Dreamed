class_name WeaponShield
extends Weapon
## Escudo: poco daño, gran empuje a todos los enemigos del frente. (+3 de defensa)
## Shield: low damage, strong shove to every enemy in front. (+3 defense)

const RANGE := 115.0
const DAMAGE := 4.0
const KNOCKBACK := 720.0
const CONE := 1.0  # medio ángulo en radianes / half angle in radians


func _init() -> void:
	cooldown = 0.95


func attack() -> bool:
	var target := nearest(RANGE)
	if target == null:
		return false
	var dir := (_body(target) - origin()).normalized()
	for e: Node2D in run.enemies.get_children():
		if not e.is_targetable():
			continue
		var to_e := _body(e) - origin()
		if to_e.length() <= RANGE + 20.0 and absf(dir.angle_to(to_e)) <= CONE:
			deal(e, DAMAGE, to_e.normalized() * KNOCKBACK)
	player.attack_anim = 1.0
	Audio.play("pillow", -2.0, 0.1)
	run.fx.swing(origin(), 70.0, dir.angle(), CONE, UITheme.BONE, 9.0)
	run.fx.ring(origin() + dir * 40.0, 26.0, UITheme.GOLD, 0.3, 2.2)
	run.shake(4.0)
	return true
