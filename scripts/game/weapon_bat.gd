class_name WeaponBat
extends Weapon
## Bate: golpe simple cuerpo a cuerpo al enemigo más cercano. (+30 % de ataque en Kroker)
## Bat: a simple melee strike on the nearest enemy. (+30% attack on Kroker)
##
## Mejoras (valores por nivel en GameState.UPGRADE_VALUES) / Upgrades (per-level values there):
##  Svinho — Carambola: el golpeado sale volando y golpea a "chain" enemigos más.
##  Stolk  — Bate de matón: +"pct" % de daño.
##  Silly  — Golpe corrupto: "chance" % de congelar "secs" segundos.

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
	var damage := DAMAGE * (1.0 + uv("stolk", "pct") / 100.0)
	var knock := KNOCKBACK
	if lv("svinho") > 0:
		knock = 380.0 + 60.0 * lv("svinho")
		target.start_bounce(damage * player.damage_mult * uv("svinho", "pct") / 100.0, int(uv("svinho", "chain")) - 1)
	deal(target, damage, dir * knock)
	if lv("silly") > 0 and randf() * 100.0 < uv("silly", "chance"):
		target.glitch(uv("silly", "secs"))
	player.attack_anim = 1.0
	Audio.play("swing", -6.0, 0.1)
	run.fx.swing(origin(), 78.0, dir.angle(), 0.9, UITheme.BONE, 5.0)
	return true
