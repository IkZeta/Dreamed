class_name WeaponBat
extends Weapon
## Bate: golpe simple cuerpo a cuerpo al enemigo más cercano. (+30 % de ataque en Kroker)
## Bat: a simple melee strike on the nearest enemy. (+30% attack on Kroker)
##
## Mejoras / Upgrades:
##  Svinho  — Carambola: el golpeado sale despedido y golpea a los que tiene detrás (encadena).
##  Stolk   — Bate de matón: +60 % de daño por nivel (cuesta vida máxima).
##  Silly   — Golpe corrupto: probabilidad de dejar al enemigo congelado por un glitch.

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
	var damage := DAMAGE * (1.0 + 0.6 * lv("stolk"))
	var knock := KNOCKBACK
	if lv("svinho") > 0:
		knock = 520.0 + 80.0 * lv("svinho")
		target.start_bounce(damage * player.damage_mult * 0.7, lv("svinho"))
	deal(target, damage, dir * knock)
	if lv("silly") > 0 and randf() < 0.2 + 0.1 * lv("silly"):
		target.glitch(1.0 + 0.4 * lv("silly"))
	player.attack_anim = 1.0
	Audio.play("swing", -6.0, 0.1)
	run.fx.swing(origin(), 78.0, dir.angle(), 0.9, UITheme.BONE, 5.0)
	return true
