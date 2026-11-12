class_name Dreamcatcher
extends Enemy
## Atrapasueños (desde el Acto 2, raro; como mucho 2): una araña hecha de un aro de mimbre con su
## red, cuentas y plumas por patas. Huye de Kroker y teje telarañas por el suelo (como mucho 3).
##  - Las telarañas atrapan los trozos de estrella que caen dentro: no se pueden coger y suben
##    despacio hacia la araña, que se los come y crece.
##  - Al matarla suelta todo lo que se ha comido, y la mitad más. Si la tiras por un agujero, se
##    los lleva con ella: pierdes los trozos, pero te quitas el problema al momento.
##  - Las telarañas frenan a todos los que pasan, y el enemigo que entra lanzado se queda pegado.
## Dreamcatcher (from Act 2, rare; at most 2): a spider made of a wicker hoop with its net, beads
## and feathers for legs. It flees from Kroker and weaves webs on the floor (at most 3).
##  - Webs catch the star shards that land in them: they can't be picked up and creep towards the
##    spider, which eats them and grows.
##  - Killing it drops everything it has eaten, plus half. Throwing it down a hole takes them
##    with it: you lose the shards, but you're rid of the problem at once.
##  - Webs slow everyone passing through, and an enemy that comes in flying gets stuck.

const WEAVE_EVERY := 6.0
const WEAVE_TIME := 1.2
const MAX_WEBS := 3
const KEEP := 380.0
const STASH_BONUS := 1.5
const VIOLET := Color("b48cff")

var stash := 0
var _weave_cd := 2.0
var _weaving := 0.0
var _webs: Array[DreamWeb] = []
var _grow := 1.0


func _init() -> void:
	bestiary_id = "dreamcatcher"
	max_hp = 26.0
	hp = max_hp
	contact_damage = 2.0
	radius = 22.0
	speed = 120.0
	mass = 0.8
	aim_height = 22.0
	shards = 2


## Se mantiene lejos de Kroker, de lado, buscando sitio para tejer
## Keeps away from Kroker, sideways, looking for a spot to weave
func _desired_velocity() -> Vector2:
	if _weaving > 0.0:
		return Vector2.ZERO
	var to: Vector2 = run.player.global_position - global_position
	var d := to.length()
	var dir := to / maxf(d, 0.01)
	var side := dir.orthogonal() * (1.0 if fmod(_phase, 2.0) > 1.0 else -1.0)
	# Corretea a tirones, como las arañas / Scuttles in bursts, like spiders do
	var burst := 0.35 + 0.65 * maxf(0.0, sin(_t * 4.0 + _phase))
	if d < KEEP:
		return (-dir + side * 0.5).normalized() * speed * burst
	return side * speed * 0.6 * burst


func _act(delta: float) -> void:
	_grow = move_toward(_grow, 1.0 + minf(stash, 12) * 0.035, delta)
	if _weaving > 0.0:
		_weaving -= delta
		if _weaving <= 0.0:
			_weave()
		return
	_weave_cd -= delta * (0.5 if slow_t > 0.0 else 1.0)
	if _weave_cd <= 0.0 and not run._blocked(global_position, 60.0):
		_weave_cd = WEAVE_EVERY * (0.8 if stash >= 6 else 1.0)
		_weaving = WEAVE_TIME
		Audio.play("web_weave", -12.0, 0.1)


func _weave() -> void:
	for i in range(_webs.size() - 1, -1, -1):
		if not is_instance_valid(_webs[i]):
			_webs.remove_at(i)
	if _webs.size() >= MAX_WEBS:
		_webs[0].dissolve()
		_webs.remove_at(0)
	var w := DreamWeb.new()
	w.run = run
	w.spider = self
	w.position = global_position
	run.world.add_child(w)
	run.world.move_child(w, run.room.get_index() + 1)
	_webs.append(w)
	Progress.tip("dreamcatcher")


## Se come un trozo que le ha llegado por la telaraña / Eats a shard that reached it along the web
func eat(value: int) -> void:
	stash += value
	_flash = 0.4
	Audio.play("web_eat", -14.0, 0.1)
	run.fx.ring(aim_point(), 12.0, VIOLET, 0.25, 1.5)


func die(counted: bool) -> void:
	if state == State.DYING:
		return
	# Suelta lo que se había comido, y la mitad más / Drops what it had eaten, plus half
	if counted and stash > 0:
		run.drop_shards(global_position + Vector2(0, -20), ceili(stash * STASH_BONUS))
		run.fx.text(global_position + Vector2(0, -90), tr("DCATCH_FREED") % ceili(stash * STASH_BONUS), UITheme.GOLD, 22)
	stash = 0
	_release_webs()
	super.die(counted)


func _start_fall(to: Vector2) -> void:
	if stash > 0:
		run.fx.text(global_position + Vector2(0, -90), tr("DCATCH_LOST") % stash, UITheme.MIST, 20)
	stash = 0
	_release_webs()
	super._start_fall(to)


func _release_webs() -> void:
	for w in _webs:
		if is_instance_valid(w):
			w.dissolve()
	_webs.clear()


func _death_sound() -> void:
	Audio.play("web_eat", -6.0, 0.2, 0.7)
	Audio.play("fluff", -10.0, 0.1)


func head_top() -> Vector2:
	return Vector2(0, -76 * _grow)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var mod := Sprites.flash_color(_flash, a) * tint
	var moving := clampf(_walk_vel.length() / 60.0, 0.0, 1.0)
	draw_set_transform(Vector2(offset.x, 0), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 24.0 * _grow, Color(0.05, 0.02, 0.15, 0.3 * a))
	var g := _grow
	var bob := -absf(sin(_t * 8.0 + _phase)) * 3.0 * moving + sin(_t * 2.0 + _phase) * 1.0
	# Patas-pluma: tres por lado, que se mueven a tirones / Feather legs: three per side, scuttling
	for side: float in [-1.0, 1.0]:
		for k in 3:
			var ph := _t * 12.0 * moving + k * 2.1 + (PI if side > 0.0 else 0.0)
			var rot := side * (0.6 + k * 0.35) + sin(ph) * 0.25 * moving + sin(_t * 1.5 + k) * 0.05
			var hip := Vector2(side * (10.0 + k * 4.0), -30.0 + k * 6.0) * g
			draw_set_transform(offset + hip + Vector2(0, bob), rot, Vector2(1.0, 1.0) * g)
			Sprites.draw(self, "dcatch_leg", mod)
	# El aro gira un pelín al tejer / The hoop turns a little while weaving
	var spin := sin(_t * 10.0) * 0.12 if _weaving > 0.0 else sin(_t * 1.3 + _phase) * 0.04
	draw_set_transform(offset + Vector2(0, bob), spin, Vector2(1.0, 1.0) * g)
	Sprites.draw(self, "dcatch_body", mod)
	draw_set_transform(Vector2.ZERO)
	# Lo que lleva comido: cuentas de luz girando dentro del aro / What it has eaten: beads of light circling inside the hoop
	for i in mini(stash, 12):
		var ang := _t * 2.0 + i * TAU / maxf(1.0, minf(stash, 12))
		var p := offset + Vector2(0, bob - 44.0 * g) + Vector2(cos(ang), sin(ang)) * 12.0 * g
		draw_circle(p, 2.2, Color(StarShard.COLORS[i % StarShard.COLORS.size()], a))
	# Hilo mientras teje / Thread while weaving
	if _weaving > 0.0:
		var k := 1.0 - _weaving / WEAVE_TIME
		draw_arc(offset + Vector2(0, -6), 20.0 + 70.0 * k, 0.0, TAU * k, 24, Color(0.94, 0.9, 0.81, 0.6 * a), 1.5)
