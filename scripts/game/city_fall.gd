class_name CityFall
extends Node2D
## Un rascacielos de la Metrópolis que está en pie desde el principio del sueño y se va
## deshaciendo: con el tiempo se agrieta, se inclina y suelta cascotes. Cuando le toca, se ve su
## sombra en el suelo (aviso), cae a lo largo de la calle y sus escombros cortan el paso un rato.
## Lo que pilla debajo recibe mucho daño (Kroker también, si no se aparta). Queda el muñón.
## A Metropolis skyscraper that stands from the start of the dream and slowly falls apart: over
## time it cracks, leans and sheds debris. When its turn comes, its shadow shows on the ground
## (warning), it falls along the street and its rubble blocks the way for a while. Whatever's caught
## underneath takes a lot of damage (Kroker too, if he doesn't move). The stump stays.

const WARN := 1.6
const FALL := 0.55
const LENGTH := 420.0       # largo de los escombros (lienzo) / rubble length (canvas)
const DEPTH := 120.0
const ENEMY_DAMAGE := 60.0
const PLAYER_DAMAGE := 3.0
const TOWER_SCALE := 0.75
const BASE := Vector2(110, 50)   # huella del pie de la torre (lienzo) / tower foot footprint (canvas)

enum State { STANDING, WARNING, LANDED }

var run: Node
var room: Act4Room
var dir := 1.0              # hacia dónde cae / which way it falls
var rect := Rect2()         # escombros en el lienzo / rubble on the canvas
var base_rect := Rect2()    # el pie de la torre (estorba siempre) / the tower's foot (always in the way)
var state := State.STANDING
var wear := 0.0             # lo deshecha que está (0..1) / how worn out it is (0..1)
var _wear_rate := 0.02
var _t := 0.0
var _clock := 0.0
var _debris: Array[Vector3] = []   # cascotes que caen: x, y, edad / falling debris: x, y, age
var _see := 1.0


## Prepara la torre: "at" es el centro de la franja donde caerá / Sets up the tower: "at" is the centre of the strip it will fall on
func setup(r: Node, at: Vector2, d: float) -> void:
	run = r
	room = r.room
	dir = d
	rect = Rect2(at - Vector2(LENGTH / 2.0, DEPTH / 2.0), Vector2(LENGTH, DEPTH))
	var foot := _foot()
	base_rect = Rect2(foot - Vector2(BASE.x / 2.0, BASE.y * 0.7), BASE)
	position = Bedroom.to_world(Vector2(rect.get_center().x, rect.end.y))
	scale = Vector2(Bedroom.S, Bedroom.S)
	_wear_rate = randf_range(0.012, 0.03)
	wear = randf_range(0.0, 0.25)
	_clock = randf() * 10.0


## Dónde está el pie de la torre en el lienzo / Where the tower's foot is on the canvas
func _foot() -> Vector2:
	return Vector2(rect.get_center().x - rect.size.x / 2.0 * dir, rect.get_center().y)


func standing() -> bool:
	return state == State.STANDING


## Empieza a caer / Starts to fall
func topple() -> void:
	if state != State.STANDING:
		return
	state = State.WARNING
	_t = 0.0
	Audio.play("rumble", -6.0)


var _redraw_t := 0.0


func _physics_process(delta: float) -> void:
	_clock += delta
	match state:
		State.STANDING:
			wear = minf(1.0, wear + _wear_rate * delta)
			# Cuanto más deshecha, más cascotes suelta / The more worn, the more debris it sheds
			if randf() < delta * wear * 1.2:
				_debris.append(Vector3(randf_range(-50, 50), -randf_range(180, 420), 0.0))
		State.WARNING:
			_t += delta
			if _t >= WARN + FALL:
				_land()
		State.LANDED:
			pass
	for i in range(_debris.size() - 1, -1, -1):
		_debris[i].z += delta
		if _debris[i].z > 0.9:
			_debris.remove_at(i)
	# Si Kroker pasa por detrás de la torre en pie, se transparenta / If Kroker walks behind the standing tower, it turns see-through
	var behind := false
	if state != State.LANDED and is_instance_valid(run.player):
		var p: Vector2 = (run.player.global_position - Bedroom.OFFSET) / Bedroom.S
		var f := _foot()
		behind = absf(p.x - f.x) < 80.0 and p.y < f.y - 10.0 and p.y > f.y - 470.0
	var see := move_toward(_see, 0.4 if behind else 1.0, delta * 4.0)
	# Solo se vuelve a dibujar si se ve y algo cambia (cascotes, aviso, transparencia), o de vez en
	# cuando para el desgaste / Only redrawn when on screen and something changes (debris, warning,
	# see-through), or now and then for the wear
	_redraw_t -= delta
	var busy := not _debris.is_empty() or state == State.WARNING or see != _see
	_see = see
	if busy or _redraw_t <= 0.0:
		_redraw_t = 0.25
		var cam := get_viewport().get_camera_2d()
		if cam == null or global_position.distance_squared_to(cam.get_screen_center_position()) < 1700.0 * 1700.0:
			queue_redraw()


func _land() -> void:
	state = State.LANDED
	room.add_rubble(rect)
	var wr := Bedroom.rect_world(rect)
	# En la cinemática del último sueño no hace daño / In the last dream's cutscene it doesn't hurt
	if run.running:
		for e: Node in run.enemies.get_children():
			if e is Enemy and (e as Enemy).is_targetable() and wr.grow(20.0).has_point((e as Node2D).global_position):
				(e as Enemy).hit(ENEMY_DAMAGE * GameState.enemy_hp_mult() * (0.3 if e.is_boss() else 1.0), Vector2(0, 400))
		if wr.grow(10.0).has_point(run.player.global_position):
			run.player.take_damage(PLAYER_DAMAGE * GameState.enemy_dmg_mult(), null)
	run.shake(12.0)
	run.fx.ring(wr.get_center(), wr.size.x * 0.6, Color("c8c4d8"), 0.6, 1.3)
	for i in 4:
		run.fx.dissipate(wr.get_center() + Vector2(randf_range(-wr.size.x * 0.45, wr.size.x * 0.45), randf_range(-20, 10)), Color("b8b4c8"))
	Audio.play("stomp", -2.0)
	Audio.play("crack", -4.0)


func _draw() -> void:
	var w := rect.size.x
	var d := rect.size.y
	var style := room.style
	var base := Vector2(-w / 2.0 * dir, -d / 2.0)
	if state == State.LANDED:
		_draw_stump(base)
		var a := room.rubble_left(rect)
		if a > 0.0:
			draw_set_transform(Vector2(-w * 0.22, 0), 0.0, Vector2(0.75, 0.8))
			Sprites.draw(self, "city_%s_rubble" % style, Color(1, 1, 1, a))
			draw_set_transform(Vector2(w * 0.22, -6), 0.0, Vector2(-0.75, 0.8))
			Sprites.draw(self, "city_%s_rubble" % style, Color(1, 1, 1, a))
			draw_set_transform(Vector2.ZERO)
		return
	var ang := 0.0
	if state == State.WARNING:
		# Sombra que crece en el suelo y rayas de aviso / Shadow growing on the ground and warning stripes
		var k := clampf(_t / WARN, 0.0, 1.0)
		var shadow := Rect2(-w / 2.0, -d, w, d)
		draw_rect(shadow, Color(0.05, 0.02, 0.12, 0.15 + 0.35 * k))
		var col := Settings.warning_color()
		draw_rect(shadow, Color(col, 0.4 + 0.4 * k), false, 4.0)
		for i in 6:
			var x := -w / 2.0 + fposmod(i * 80.0 + _t * 120.0, w)
			draw_line(Vector2(x, -d), Vector2(minf(x + 40.0, w / 2.0), 0), Color(col, 0.35 * k), 6.0)
		var f := clampf((_t - WARN + 0.3) / (FALL + 0.3), 0.0, 1.0)
		ang = dir * (PI / 2.0) * f * f + sin(_t * 30.0) * 0.012 * (1.0 - f)
	# En pie: se inclina un poco hacia donde caerá y tiembla cuando está muy deshecha
	# Standing: it leans a little towards where it'll fall and shakes when very worn
	ang += dir * wear * 0.06 + (sin(_clock * 23.0) * 0.006 * wear if wear > 0.6 else 0.0)
	if state == State.STANDING:
		draw_colored_polygon(room._ellipse(base + Vector2(dir * 18, 6), Vector2(90, 22)), Color(0, 0, 0, 0.25))
	draw_set_transform(base, ang, Vector2(TOWER_SCALE, TOWER_SCALE))
	Sprites.draw(self, "city_%s_tower" % style, Color(1, 1, 1, _see))
	_draw_cracks()
	draw_set_transform(Vector2.ZERO)
	for db in _debris:
		var q := base + Vector2(db.x, db.y + 420.0 * db.z * db.z)
		if q.y < base.y + 6.0:
			draw_rect(Rect2(q, Vector2(7, 6)), Color(0.55, 0.5, 0.6, 1.0 - db.z))


## Grietas en la fachada según el desgaste (en el espacio del sprite) / Cracks on the facade by wear (in sprite space)
func _draw_cracks() -> void:
	var ink := Color(0.06, 0.03, 0.1, 0.85)
	var n := int(wear * 6.0)
	for i in n:
		var x := -60.0 + fposmod(i * 47.0 + 13.0, 120.0)
		var y := -520.0 + fposmod(i * 131.0, 460.0)
		var pts := PackedVector2Array([Vector2(x, y)])
		for k in 4:
			pts.append(pts[-1] + Vector2(((i + k) % 3 - 1) * 9.0, 16.0))
		draw_polyline(pts, ink, 3.0)
		draw_line(pts[2], pts[2] + Vector2(10.0 * (1 if i % 2 else -1), 8.0), ink, 2.0)
	if wear > 0.5:
		# Ventanas reventadas / Blown-out windows
		for i in int((wear - 0.5) * 8.0):
			draw_rect(Rect2(-50.0 + fposmod(i * 37.0, 90.0), -480.0 + fposmod(i * 97.0, 400.0), 14, 12), Color(0.04, 0.02, 0.08))


## Lo que queda en pie tras caer: el muñón roto / What's left standing after the fall: the broken stump
func _draw_stump(base: Vector2) -> void:
	var col := Color(room.LOOK[room.style]["plinth"]).darkened(0.3)
	draw_colored_polygon(room._ellipse(base + Vector2(0, 4), Vector2(70, 18)), Color(0, 0, 0, 0.25))
	var top := PackedVector2Array([base + Vector2(-56, -60), base + Vector2(-30, -82), base + Vector2(-8, -64), base + Vector2(14, -96), base + Vector2(36, -70), base + Vector2(56, -78)])
	var poly := PackedVector2Array([base + Vector2(-56, 0), base + Vector2(56, 0)])
	for i in range(top.size() - 1, -1, -1):
		poly.append(top[i])
	draw_colored_polygon(poly, col)
	draw_polyline(top, col.darkened(0.4), 4.0)
	for i in 3:
		draw_rect(Rect2(base + Vector2(-40 + i * 30, -50), Vector2(14, 14)), Color(0.05, 0.03, 0.08))
	draw_rect(Rect2(base + Vector2(-56, -8), Vector2(112, 8)), col.darkened(0.25))
