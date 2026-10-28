class_name WeaponBat
extends Weapon
## Bate: golpe simple cuerpo a cuerpo al enemigo más cercano. (+30 % de ataque en Kroker)
## Bat: a simple melee strike on the nearest enemy. (+30% attack on Kroker)

const RANGE := 125.0
const DAMAGE := 10.0
const KNOCKBACK := 160.0


func _init() -> void:
	cooldown = 0.75


func attack() -> bool:
	var target := nearest(RANGE)
	if target == null:
		return false
	var dir := (_body(target) - origin()).normalized()
	deal(target, DAMAGE, dir * KNOCKBACK)
	player.attack_anim = 1.0
	run.fx.swing(origin(), 78.0, dir.angle(), 0.9, UITheme.BONE, 5.0)
	return true
