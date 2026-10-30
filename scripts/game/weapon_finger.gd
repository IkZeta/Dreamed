class_name WeaponFinger
extends Weapon
## Pistola de dedos: Kroker apunta con el dedo y dispara rayos láser al enemigo más cercano.
## Cada rayo sale con un efecto al azar (la suerte hace más probables los buenos):
##   normal, atraviesa (golpea también a los de detrás), empuja (puede tirarlos por los
##   agujeros), crítico (x1,75), sale hacia atrás (se le va el dedo) o rebota hacia otro enemigo.
## Finger gun: Kroker points his finger and fires laser beams at the nearest enemy.
## Every beam comes out with a random effect (luck makes the good ones likelier):
##   normal, pierce (also hits whoever is behind), push (can knock them down holes),
##   critical (x1.75), backfire (comes out backwards) or bounce (ricochets to another enemy).
##
## Mejoras (valores por nivel en GameState.UPGRADE_VALUES) / Upgrades (per-level values there):
##  Svinho — Carambola láser: +"chance" de rebote y rebota en "extra" enemigos más.
##  Stolk  — Pistola de matón: +"pct" % de daño.
##  Silly  — Láser corrupto: "chance" % de ralentizar "secs" segundos.
##  Doc    — vida máxima a cambio de +"pct" % de recarga.

const RANGE := 450.0
const DAMAGE := 4.0
const CRIT := 1.75
## Probabilidad base de cada tipo de disparo / Base weight of each kind of shot
const KINDS := {"normal": 40.0, "pierce": 12.0, "push": 12.0, "crit": 12.0, "back": 12.0, "bounce": 12.0}
## Color del rayo según su efecto / Beam colour by effect
const COLORS := {"normal": Color("ff5f7a"), "pierce": Color("5ff2ff"), "push": Color("ffb04a"),
	"crit": Color("ffe36a"), "back": Color("c48bff"), "bounce": Color("8dff9a")}


func _init() -> void:
	cooldown = 0.6


func _ready() -> void:
	cooldown = 0.6 * (1.0 + uv("doc", "pct") / 100.0)


## Elige el efecto del disparo. La suerte sube los especiales y baja el "hacia atrás".
## Picks the shot's effect. Luck raises the special ones and lowers "backfire".
func roll_kind() -> String:
	var luck := GameState.stat("luck")
	var w := {}
	var total := 0.0
	for k: String in KINDS:
		var v: float = KINDS[k]
		if k == "back":
			v *= clampf(1.0 - luck / 60.0, 0.25, 1.5)
		elif k != "normal":
			v *= maxf(0.3, 1.0 + luck / 50.0)
		if k == "bounce":
			v += uv("svinho", "chance")
		w[k] = v
		total += v
	var roll := randf() * total
	for k: String in w:
		roll -= float(w[k])
		if roll <= 0.0:
			return k
	return "normal"


func attack() -> bool:
	var target := nearest(RANGE * range_mult())
	if target == null:
		return false
	var kind := roll_kind()
	var from := muzzle()
	var dir := (_body(target) - from).normalized()
	if kind == "back":
		# Se le va el dedo: el rayo sale hacia atrás (a por quien haya detrás, si hay alguien)
		# His finger slips: the beam comes out backwards (at whoever is behind, if anyone)
		dir = -dir
		var best_d := RANGE * range_mult()
		for e: Node2D in run.enemies.get_children():
			if not e.is_targetable():
				continue
			var to := _body(e) - from
			if to.length() < best_d and to.normalized().dot(dir) > 0.5:
				best_d = to.length()
				dir = to.normalized()
	var dmg := DAMAGE * (1.0 + uv("stolk", "pct") / 100.0)
	var shot := LaserShot.new()
	shot.weapon = self
	shot.kind = kind
	shot.dir = dir
	shot.damage = dmg * (CRIT if kind == "crit" else 1.0)
	shot.max_travel = RANGE * range_mult() * 1.3
	shot.bounces = 1 + int(uv("svinho", "extra")) if kind == "bounce" else 0
	shot.pierces = 2 if kind == "pierce" else 0
	shot.position = from
	run.world.add_child(shot)
	swung(true)
	Audio.play("laser", -9.0 if kind != "crit" else -6.0, 0.12)
	run.fx.ring(from, 8.0, COLORS[kind], 0.18, 2.4)
	return true


## La punta del dedo / The fingertip
func muzzle() -> Vector2:
	# Con la mano izquierda (segunda arma) el dedo queda un poco más atrás / In the left hand (second weapon) the finger sits a little further back
	var x := 30.0 if hand() == "r" else -18.0
	return player.global_position + Vector2(x * player._facing, -58.0)


## Silly: el láser corrupto ralentiza / Silly: the corrupted laser slows
func on_laser_hit(e: Node2D) -> void:
	if lv("silly") > 0 and randf() * 100.0 < uv("silly", "chance"):
		e.glitch(0.0, uv("silly", "secs"))


func charge_anchor() -> Vector2:
	if not primary:
		return super.charge_anchor()
	# Encima de la mano que dispara, para no taparla / Above the firing hand, so it doesn't cover it
	return Vector2(32.0 * player._facing, -80.0)
