class_name WeaponShield
extends Weapon
## Escudo-almohada: poco daño, gran empuje a todos los enemigos del frente. (+3 de defensa)
## Pillow shield: low damage, strong shove to every enemy in front. (+3 defense)
##
## Mejoras / Upgrades:
##  (valores por nivel en GameState.UPGRADE_VALUES / per-level values there)
##  Svinho  — Pase largo: con E lanzas la almohada; golpea a "hits" enemigos (1 en nivel 1,
##            2 en nivel 2...), pero pierdes defensa. Con E vuelves al modo defensa.
##  Stolk   — Almohada de piedra: +"pct" % de daño y +"push" % de empuje.
##  Silly   — Desfase: "chance" % de dejar al enemigo a cámara lenta "secs" segundos.

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
	cooldown = uv("svinho", "cd") if throw_mode else 0.95
	run.hud.set_special_mode(throw_mode)
	run.fx.ring(origin(), 34.0, UITheme.GOLD, 0.4, 1.8)
	Audio.play("chime", -8.0)


func charge_bars() -> Array:
	var bars := super.charge_bars()
	if throw_mode:
		bars[0][1] = UITheme.GOLD
	return bars


## El anillo sale junto a la almohada (mano izquierda) / The ring sits by the pillow (left hand)
func charge_anchor() -> Vector2:
	return Vector2(-32.0 * player._facing, -50.0)


func attack() -> bool:
	if throw_mode:
		return _throw()
	var target := nearest(RANGE * range_mult())
	if target == null:
		return false
	var dir := (_body(target) - origin()).normalized()
	var damage := DAMAGE * (1.0 + uv("stolk", "pct") / 100.0)
	var knock := KNOCKBACK * (1.0 + uv("stolk", "push") / 100.0) * (1.0 - uv("doc", "pct") / 100.0)
	for e: Node2D in run.enemies.get_children():
		if not e.is_targetable():
			continue
		var to_e := _body(e) - origin()
		if to_e.length() <= RANGE * range_mult() + 20.0 and absf(dir.angle_to(to_e)) <= CONE:
			deal(e, damage, to_e.normalized() * knock)
			if lv("silly") > 0 and randf() * 100.0 < uv("silly", "chance"):
				e.glitch(0.0, uv("silly", "secs"))
	player.attack_anim = 1.0
	Audio.play("pillow", -2.0, 0.1)
	run.fx.swing(origin(), 70.0, dir.angle(), CONE, UITheme.BONE, 9.0)
	run.fx.ring(origin() + dir * 40.0, 26.0, UITheme.GOLD, 0.3, 2.2)
	run.shake(4.0)
	return true


func _throw() -> bool:
	if is_instance_valid(_projectile):
		return false
	var target := nearest(THROW_RANGE * range_mult())
	if target == null:
		return false
	var p := PillowProjectile.new()
	p.run = run
	p.player = player
	p.damage = uv("svinho", "dmg") * (1.0 + uv("stolk", "pct") / 100.0) * player.damage_mult
	p.bounces = int(uv("svinho", "hits")) - 1
	p.slow_chance = uv("silly", "chance")
	p.slow = uv("silly", "secs")
	p.target = target
	p.position = origin()
	run.world.add_child(p)
	_projectile = p
	player.armed = false
	p.tree_exited.connect(func() -> void: player.armed = true)
	player.attack_anim = 1.0
	Audio.play("swing", -4.0, 0.1)
	return true
