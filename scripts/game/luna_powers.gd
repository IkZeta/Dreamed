class_name LunaPowers
extends Node
## Luna en la partida: el «Pozo gravitatorio» de las armas a distancia. Cada cierto tiempo abre un
## mini agujero negro donde más enemigos hay juntos: atrae a los de alrededor (sin dañarlos) y los
## deja amontonados; con el dúo de Svinho, lo que sale flotando de él rebota. La «Órbita» de las
## armas cuerpo a cuerpo va en Weapon._luna_orbit.
## Luna in the run: the ranged weapons' "Gravity well". Every so often it opens a mini black hole
## where most enemies are bunched together: it pulls those around it (without hurting them) and
## leaves them piled up. The melee weapons' "Orbit" lives in Weapon._luna_orbit.

const WELL_RADIUS := 260.0
## Si hay un agujero libre así de cerca del grupo, el pozo se abre encima
## If there's a free hole this close to the group, the well opens on top of it
const HOLE_SNAP := 240.0
## Sobre un agujero, se traga a los que llegan al centro con poca vida (como la aspiradora)
## Over a hole, it swallows whoever reaches the middle with low health (like the vacuum)
const SWALLOW_R := 56.0
const SWALLOW_HP := 0.5

var run: Node
var _timers := {}   # arma → segundos que faltan / weapon → seconds left


func setup(r: Node) -> void:
	run = r
	for w: String in GameState.weapons():
		if GameState.level("luna", w) > 0 and GameState.helper_power("luna", w) == "well":
			_timers[w] = GameState.up_value("luna", "cd", -1, w) * 0.5


func _physics_process(delta: float) -> void:
	if not run.running:
		return
	for w: String in _timers:
		_timers[w] = float(_timers[w]) - delta
		if float(_timers[w]) <= 0.0:
			var at := _densest()
			if at == Vector2.INF:
				_timers[w] = 1.0
				continue
			_timers[w] = GameState.up_value("luna", "cd", -1, w)
			var well := GravityWell.new()
			well.run = run
			well.life = GameState.up_value("luna", "secs", -1, w)
			well.pull = GameState.up_value("luna", "pull", -1, w)
			var hole := _hole_near(at)
			well.hole = hole
			well.position = at if hole == Vector2.INF else hole
			run.world.add_child(well)


## El centro del agujero libre más cercano a "at" (del suelo o un Bostezo), o INF
## The centre of the free hole nearest to "at" (floor or a Yawn), or INF
func _hole_near(at: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_d := HOLE_SNAP
	var list: Array = run.room.holes_list()
	for i in run.room.hole_count():
		var rc := Bedroom.rect_world(list[i])
		var d := rc.get_center().distance_to(at)
		if d < best_d and not run.hole_covered(rc):
			best_d = d
			best = rc.get_center()
	if is_instance_valid(run.yawns):
		for c: Vector2 in run.yawns.open_centers():
			if c.distance_to(at) < best_d:
				best_d = c.distance_to(at)
				best = c
	return best


## Donde más enemigos hay juntos (a la vista) / Where most enemies are bunched together (on screen)
func _densest() -> Vector2:
	var best := Vector2.INF
	var best_n := 0
	var view: Rect2 = run.view_rect()
	var list: Array[Node] = run.foes()
	for n: Node in list:
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or not e.is_targetable() or e.is_boss() or not view.has_point(e.global_position):
			continue
		var k := 0
		for m: Node in list:
			var o := m as Enemy
			if o and is_instance_valid(o) and o.is_targetable() and o.global_position.distance_squared_to(e.global_position) < 200.0 * 200.0:
				k += 1
		if k > best_n:
			best_n = k
			best = e.global_position
	return best


## El mini agujero negro de Luna / Luna's mini black hole
class GravityWell extends Node2D:
	var run: Node
	var life := 2.0
	var pull := 200.0
	var hole := Vector2.INF
	var _t := 0.0

	func _ready() -> void:
		z_index = 2
		Audio.play("gravity_well", -8.0, 0.05)
		Progress.tip("luna_well")

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t >= life + 0.4:
			queue_free()
			return
		if _t < life:
			var r2 := LunaPowers.WELL_RADIUS * LunaPowers.WELL_RADIUS
			for n: Node in run.foes():
				if not is_instance_valid(n):
					continue
				var e := n as Enemy
				if e == null or not e.is_targetable() or e.is_boss():
					continue
				var d := global_position - e.global_position
				var l2 := d.length_squared()
				if hole != Vector2.INF and l2 < LunaPowers.SWALLOW_R * LunaPowers.SWALLOW_R and e.can_fall() \
						and e.hp <= e.max_hp * LunaPowers.SWALLOW_HP:
					e._start_fall(hole)
					Progress.add_stat("luna_swallow")
					continue
				if l2 < r2 and l2 > 100.0:
					e.external_pull += d.normalized() * pull * (1.0 - sqrt(l2) / LunaPowers.WELL_RADIUS * 0.5)
		queue_redraw()

	func _draw() -> void:
		var open := minf(1.0, _t * 4.0) * clampf((life + 0.4 - _t) / 0.4, 0.0, 1.0)
		var r := 40.0 * open * (1.0 + sin(_t * 9.0) * 0.04)
		var lilac := Color(0.55, 0.45, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
		# Zona de atracción: un velo y anillos que se cierran hacia el centro
		# Pull zone: a veil and rings closing in towards the middle
		draw_circle(Vector2.ZERO, LunaPowers.WELL_RADIUS * open, Color(lilac, 0.1))
		for k in 3:
			var ph := fposmod(-_t * 0.7 + k / 3.0, 1.0)
			draw_arc(Vector2.ZERO, LunaPowers.WELL_RADIUS * open * ph + r, 0.0, TAU, 40, Color("c9d4ff", 0.35 * ph * open), 2.0)
		# Brazos de una galaxia girando / Arms of a spinning galaxy
		for arm in 3:
			var pts := PackedVector2Array()
			for i in 12:
				var f := i / 11.0
				var ang := _t * 3.0 + arm * TAU / 3.0 + f * 3.2
				pts.append(Vector2(cos(ang), sin(ang)) * (r + f * 120.0 * open))
			draw_polyline(pts, Color(lilac, 0.45 * open), 3.0)
		draw_circle(Vector2.ZERO, r + 12.0, Color(lilac, 0.45 * open))
		draw_circle(Vector2.ZERO, r, Color("07061a"))
		draw_arc(Vector2.ZERO, r + 3.0, 0.0, TAU, 28, Color("c9d4ff", 0.95 * open), 3.0)
		# Polvo de estrellas que cae en espiral / Stardust spiralling in
		for i in 16:
			var ph := fposmod(_t * 0.8 + i / 16.0, 1.0)
			var ang := i * 2.3 + ph * 5.0
			var d := (1.0 - ph) * LunaPowers.WELL_RADIUS * 0.85 * open + r * ph
			draw_circle(Vector2(cos(ang), sin(ang)) * d, 3.0, Color(1, 0.95, 0.8, ph * open))
		draw_set_transform(Vector2.ZERO)
