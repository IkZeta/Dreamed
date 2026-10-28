class_name WeaponShield
extends Weapon
## Escudo-almohada: poco daño, gran empuje a todos los enemigos del frente. (+3 de defensa)
## Pillow shield: low damage, strong shove to every enemy in front. (+3 defense)
##
## Mejoras / Upgrades:
##  Svinho  — Pase largo: con E cambias a lanzar la almohada, que rebota entre enemigos y hace
##            más daño, pero pierdes defensa. Con E vuelves al modo defensa.
##  Stolk   — Almohada de piedra: más daño y más empuje (cuesta vida máxima).
##  Silly   — Desfase: los enemigos golpeados quedan ralentizados por un glitch.

const RANGE := 115.0
const DAMAGE := 4.0
const KNOCKBACK := 720.0
const CONE := 1.0  # medio ángulo en radianes / half angle in radians
const THROW_RANGE := 520.0
const THROW_ARMOR_LOSS := 4.0

var throw_mode := false
var _projectile: Node2D


func _init() -> void:
	cooldown = 0.95


func _unhandled_input(event: InputEvent) -> void:
	if lv("svinho") > 0 and event.is_action_pressed("special") and run.running:
		toggle_mode()


## Cambia entre defender y lanzar / Switches between defending and throwing
func toggle_mode() -> void:
	throw_mode = not throw_mode
	player.armor += -THROW_ARMOR_LOSS if throw_mode else THROW_ARMOR_LOSS
	cooldown = 1.1 if throw_mode else 0.95
	run.hud.set_special_mode(throw_mode)
	run.fx.ring(origin(), 34.0, UITheme.GOLD, 0.4, 1.8)
	Audio.play("chime", -6.0)


func attack() -> bool:
	if throw_mode:
		return _throw()
	var target := nearest(RANGE)
	if target == null:
		return false
	var dir := (_body(target) - origin()).normalized()
	var damage := DAMAGE * (1.0 + 1.0 * lv("stolk"))
	var knock := KNOCKBACK * (1.0 + 0.4 * lv("stolk"))
	for e: Node2D in run.enemies.get_children():
		if not e.is_targetable():
			continue
		var to_e := _body(e) - origin()
		if to_e.length() <= RANGE + 20.0 and absf(dir.angle_to(to_e)) <= CONE:
			deal(e, damage, to_e.normalized() * knock)
			if lv("silly") > 0:
				e.glitch(0.6 if randf() < 0.25 else 0.0, 1.5 + lv("silly"))
	player.attack_anim = 1.0
	Audio.play("pillow", -2.0, 0.1)
	run.fx.swing(origin(), 70.0, dir.angle(), CONE, UITheme.BONE, 9.0)
	run.fx.ring(origin() + dir * 40.0, 26.0, UITheme.GOLD, 0.3, 2.2)
	run.shake(4.0)
	return true


func _throw() -> bool:
	if is_instance_valid(_projectile):
		return false
	var target := nearest(THROW_RANGE)
	if target == null:
		return false
	var p := PillowProjectile.new()
	p.run = run
	p.player = player
	p.damage = 9.0 * (1.0 + 0.3 * lv("svinho")) * (1.0 + 0.6 * lv("stolk")) * player.damage_mult
	p.bounces = 2 + lv("svinho")
	p.slow = (1.5 + lv("silly")) if lv("silly") > 0 else 0.0
	p.target = target
	p.position = origin()
	run.add_child(p)
	_projectile = p
	player.armed = false
	p.tree_exited.connect(func() -> void: player.armed = true)
	player.attack_anim = 1.0
	Audio.play("swing", -4.0, 0.1)
	return true
