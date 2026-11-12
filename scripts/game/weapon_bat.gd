class_name WeaponBat
extends Weapon
## Bate: golpe simple cuerpo a cuerpo al enemigo más cercano. (+20 % de ataque en Kroker)
## Bat: a simple melee strike on the nearest enemy. (+20% attack on Kroker)
##
## Mejoras (valores por nivel en GameState.UPGRADE_VALUES) / Upgrades (per-level values there):
##  Svinho — Carambola: el golpeado sale volando y golpea a "chain" enemigos más.
##  Stolk  — Bate de matón: +"pct" % de daño.
##  Silly  — Golpe corrupto: "chance" % de congelar "secs" segundos.

const RANGE := 115.0
const DAMAGE := 8.0
const KNOCKBACK := 160.0


func _init() -> void:
	cooldown = 0.6


func attack() -> bool:
	var target := nearest(RANGE * range_mult())
	if target == null:
		return false
	var dir := (_body(target) - origin()).normalized()
	# Dúo Stolk y Doc: sin la pega del Doc / Stolk & Doc duo: without Doc's downside
	var doc_pen := 0.0 if GameState.has_duo("stolk_doc") else uv("doc", "pct") / 100.0
	var damage := DAMAGE * (1.0 + uv("stolk", "pct") / 100.0) * (1.0 - doc_pen)
	var knock := KNOCKBACK
	if lv("svinho") > 0:
		knock = 380.0 + 60.0 * lv("svinho")
		target.start_bounce(damage * player.damage_mult * uv("svinho", "pct") / 100.0, int(uv("svinho", "chain")) - 1)
	# Dúo Svinho y Luna: lo que flota sale disparado como un balón y rebota en cadena
	# Svinho & Luna duo: whatever is floating shoots off like a ball and bounces in a chain
	if GameState.has_duo("svinho_luna") and primary and target is Enemy and (target as Enemy).float_t > 0.0:
		knock = maxf(knock, 700.0)
		target.start_bounce(damage * player.damage_mult * GameState.duo_value("svinho_luna", "pct") / 100.0, int(GameState.duo_value("svinho_luna", "chain")))
		run.fx.text(target.global_position + Vector2(0, -110), tr("DUO_SVINHO_LUNA_SHOUT"), Color("c9d4ff"), 22)
	deal(target, damage, dir * knock)
	# ...y cada enemigo que tumba el bate cura / ...and every enemy the bat knocks out heals
	if GameState.has_duo("stolk_doc") and target.state == Enemy.State.DYING:
		player.heal(GameState.duo_value("stolk_doc", "heal"))
	if lv("silly") > 0 and randf() * 100.0 < uv("silly", "chance"):
		target.glitch(uv("silly", "secs"))
	swung()
	Audio.play("swing", -6.0, 0.1)
	run.fx.swing(origin(), 78.0, dir.angle(), 0.9, UITheme.BONE, 5.0)
	return true
