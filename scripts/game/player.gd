class_name Player
extends Node2D
## Kroker en la partida: se mueve y su arma ataca sola (estilo Brotato).
## Kroker in game: moves around while his weapon attacks on its own (Brotato style).

const ART_SCALE := 0.55
const HIT_INVULN := 0.8

var run: Node  # Run
var outfit := "bat"
var max_hp := 20.0
var hp := 20.0
var speed := 300.0
var damage_mult := 1.0
var armor := 0.0
var alive := true
var attack_anim := 0.0  # 1 → 0 tras un golpe / after a strike
var aim := Vector2(1, 0.5)   # hacia dónde apunta el arma / where the weapon points
var sucking := false         # la aspiradora está absorbiendo / the vacuum is sucking
var cast_anim := 0.0         # 1 → 0 al lanzar un rayo / after casting lightning
var armed := true            # lleva el arma en la mano / holds the weapon
var hurt_lean := 0.0         # retroceso al recibir daño / recoil when hit
var hop := 0.0               # altura de un salto en píxeles / jump height in pixels
var _land := 0.0             # rebote al aterrizar / landing squash

var _walk := 0.0
var _moving := 0.0
var _last_pos := Vector2.INF

var _vel := Vector2.ZERO
var _invuln := 0.0
var _flash := 0.0
var _facing := 1.0
var _t := 0.0
var _regen_acc := 0.0
var _heal_text := 0.0
## Transparencia de cada anillo de carga (se apaga al llenarse, como la stamina de Zelda)
## Opacity of each charge ring (fades out once full, like Zelda's stamina wheel)
var _ring_a: Array[float] = []
var weapon: Weapon


func setup(p_run: Node, p_outfit: String) -> void:
	run = p_run
	outfit = p_outfit
	refresh_stats()
	hp = max_hp
	match outfit:
		"shield": weapon = WeaponShield.new()
		"book": weapon = WeaponBook.new()
		"vacuum": weapon = WeaponVacuum.new()
		_: weapon = WeaponBat.new()
	weapon.run = run
	weapon.player = self
	add_child(weapon)


## Vuelve a leer las estadísticas (al subir de nivel) / Re-reads the stats (after a level-up)
func refresh_stats() -> void:
	var s := GameState.stats_for(outfit)
	max_hp = s["max_hp"]
	hp = minf(hp, max_hp)
	speed = s["speed"]
	damage_mult = s["damage_mult"]
	armor = s["armor"]


func heal(amount: float) -> void:
	if not alive or hp >= max_hp:
		return
	hp = minf(max_hp, hp + amount)
	run.hud.set_hp(hp, max_hp)
	# Sin llenar la pantalla de números / Without flooding the screen with numbers
	if _heal_text <= 0.0:
		_heal_text = 0.6
		run.fx.text(global_position + Vector2(0, -120), "+%s" % str(snappedf(amount, 0.1)).trim_suffix(".0"), Color("9be38a"), 20)


func _physics_process(delta: float) -> void:
	_t += delta
	_heal_text = maxf(0.0, _heal_text - delta)
	# Recuperación de salud: "regen" de vida cada 5 s / Health regeneration: "regen" health every 5 s
	var regen := GameState.stat("regen")
	if regen > 0.0 and alive and run.running:
		_regen_acc += regen / 5.0 * delta
		if _regen_acc >= 0.5:
			heal(_regen_acc)
			_regen_acc = 0.0
	_invuln = maxf(0.0, _invuln - delta)
	_flash = maxf(0.0, _flash - delta * 4.0)
	attack_anim = maxf(0.0, attack_anim - delta * 4.0)
	cast_anim = maxf(0.0, cast_anim - delta * 3.0)
	hurt_lean = move_toward(hurt_lean, 0.0, delta * 1.5)
	_land = move_toward(_land, 0.0, delta * 4.0)
	modulate.a = 1.0 if alive else 0.35
	if alive and run.running:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		_vel = _vel.lerp(input * speed, minf(1.0, delta * 14.0))
		position = run.clamp_to_arena(position + _vel * delta, 24.0)
		if absf(_vel.x) > 10.0:
			_facing = signf(_vel.x)
	else:
		_vel = Vector2.ZERO
	queue_redraw()


## Animación de andar según lo que se ha movido de verdad (también en la intro).
## Se calcula por fotograma dibujado, que es cuando se mueven las animaciones.
## Walk animation from actual movement (also during the intro), computed per drawn frame.
func _process(delta: float) -> void:
	if _last_pos != Vector2.INF and delta > 0.0:
		var spd := position.distance_to(_last_pos) / delta
		_moving = move_toward(_moving, clampf(spd / 200.0, 0.0, 1.0), delta * 8.0)
		_walk += spd * delta * 0.045
		if not run.running and absf(position.x - _last_pos.x) > 0.3:
			_facing = signf(position.x - _last_pos.x)
	_last_pos = position
	queue_redraw()


## Pequeño rebote al caer de un salto / Small bounce when landing from a hop
func land() -> void:
	_land = 1.0


func set_facing(f: float) -> void:
	_facing = f


func take_damage(amount: float) -> void:
	if not alive or _invuln > 0.0 or not run.running:
		return
	if GameState.god_mode and GameState.god_invuln:
		return  # modo Dios / god mode
	# La defensa resta daño, pero siempre se recibe al menos 1.
	# Defense subtracts damage, but at least 1 always gets through.
	var dmg := maxf(1.0, amount - armor)
	hp = maxf(0.0, hp - dmg)
	_invuln = HIT_INVULN
	_flash = 1.0
	hurt_lean = -0.18
	run.fx.text(global_position + Vector2(0, -110), "-%d" % roundi(dmg), UITheme.EMBER, 26)
	run.on_player_hit(dmg)
	if hp <= 0.0:
		alive = false
		run.on_player_died()


func _draw() -> void:
	# Parpadea mientras es invulnerable / Blinks while invulnerable
	var visible_now := _invuln <= 0.0 or fmod(_t, 0.12) < 0.07 or not alive
	if not visible_now:
		return
	# Al aterrizar se aplasta un poco y recupera la forma / Squashes a little on landing, then springs back
	var squash := sin(_land * PI) * 0.12
	var sx := ART_SCALE * (1.0 + squash)
	var sy := ART_SCALE * (1.0 - squash)
	KrokerArt.draw(self, Transform2D(0.0, Vector2(sx, sy), 0.0, Vector2(-200.0 * sx / 2.0, -288.0 * sy - hop)),
		outfit, _t, {"facing": _facing, "flash": _flash, "attack": attack_anim, "aim": aim, "sucking": sucking,
		"cast": cast_anim, "walk": _walk, "moving": _moving, "armed": armed, "lean": hurt_lean})
	if alive and run.running and weapon:
		_draw_charge_rings(weapon.charge_bars(), weapon.charge_anchor())


## Anillos de carga junto al arma: se rellenan en círculo y se apagan cuando están llenos.
## Charge rings by the weapon: they fill in a circle and fade out once full.
func _draw_charge_rings(bars: Array, anchor: Vector2) -> void:
	_ring_a.resize(bars.size())
	var dt := get_process_delta_time()
	for i in bars.size():
		var k: float = clampf(bars[i][0], 0.0, 1.0)
		var col: Color = bars[i][1]
		_ring_a[i] = move_toward(_ring_a[i], 0.0 if k >= 1.0 else 1.0, dt * (2.5 if k >= 1.0 else 8.0))
		var a: float = _ring_a[i]
		if a <= 0.01:
			continue
		var c := anchor + Vector2(0, -26.0 * i)
		var r := 10.0
		draw_circle(c, r + 3.5, Color(0.05, 0.03, 0.18, 0.45 * a))
		draw_arc(c, r, 0, TAU, 28, Color(col, 0.18 * a), 4.0, true)
		if k > 0.0:
			draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * k, maxi(4, int(28 * k)), Color(col, 0.95 * a), 4.0, true)
		if k >= 1.0:
			draw_circle(c, r * 0.45, Color(col, 0.7 * a))
