class_name EnemyStatue
extends Control
## Dibuja un enemigo animado (las estatuas del museo del plano astral).
## Draws an animated enemy (the statues in the astral plane's museum).

var id := "foox"
var hidden_shape := false
var power := "split"
var _enemy: Node2D
var _t := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if id.begins_with("boss_") and id != "boss_chef" and id != "boss_ufo" and id != "boss_evil_ad":
		return
	var e: Enemy
	match id:
		"thug": e = Thug.new()
		"sling": e = SlingThug.new()
		"skeleton": e = Skeleton.new()
		"nest": e = Nest.new()
		"mosquito": e = Mosquito.new()
		"cyber": e = Cyberpunk.new()
		"puppet": e = Puppet.new()
		"golem": e = Golem.new()
		"police": e = Police.new()
		"van": e = Van.new()
		"riot": e = Riot.new()
		"botcher": e = Botcher.new()
		"boss_chef": e = Chef.new()
		"boss_ufo": e = Ufo.new()
		"boss_evil_ad": e = EvilAd.new()
		"golden_foox": e = GoldenFoox.new()
		_: e = Foox.new()
	if id == "elite":
		e.elite = true
		e.elite_power = power
	e.preview = true
	e.state = Enemy.State.ALIVE
	e._fade = 1.0
	add_child(e)
	e.set_physics_process(false)
	e.scale = Vector2.ONE * (1.3 if id == "elite" else 1.0) * _fit()
	if hidden_shape:
		e.modulate = Color(0, 0, 0, 0.75)
	_enemy = e

## Alto de cada dibujo (con cuernos y aura) / Height of each drawing (with horns and aura)
const HEIGHTS := {"foox": 70.0, "golden_foox": 70.0, "elite": 70.0, "thug": 170.0, "sling": 130.0, "skeleton": 130.0, "nest": 60.0, "mosquito": 70.0, "cyber": 150.0, "puppet": 210.0, "golem": 210.0, "police": 160.0, "van": 260.0, "riot": 175.0, "botcher": 100.0, "boss_chef": 290.0, "boss_ufo": 160.0, "boss_evil_ad": 420.0,
	"boss_bed": 200.0, "boss_shelf": 190.0, "boss_chest": 130.0}

## Escala para que quepa entero en el hueco / Scale so it fits whole in the space
func _fit() -> float:
	var h: float = HEIGHTS.get(id, 120.0) * (1.3 if id == "elite" else 1.0)
	return minf(1.6, size.y * 0.74 / h)

func _process(delta: float) -> void:
	_t += delta
	# El élite va cambiando de color cada 2 s / The elite changes colour every 2 s
	if id == "elite" and _enemy and _t > 2.0:
		_t = 0.0
		var powers := ["split", "puddle", "haste"]
		power = powers[(powers.find(power) + 1) % 3]
		_enemy.queue_free()
		_enemy = null
		_ready()
		return
	if _enemy:
		_enemy.set("_t", _t)
		_enemy.position = Vector2(size.x / 2.0, size.y * 0.84)
		_enemy.scale = Vector2.ONE * (1.3 if id == "elite" else 1.0) * _fit()
		_enemy.queue_redraw()
	queue_redraw()

func _draw() -> void:
	var c := Vector2(size.x / 2.0, size.y * 0.84)
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - Vector2(90, 120), Vector2(180, 160)), false, Color(UITheme.MIST, 0.15))
	if id.begins_with("boss_") and id != "boss_chef" and id != "boss_ufo" and id != "boss_evil_ad":
		var sprite := {"boss_bed": "boss_bed", "boss_shelf": "boss_shelf", "boss_chest": "boss_chest_box"}[id] as String
		var mod := Color(0, 0, 0, 0.75) if hidden_shape else Color.WHITE
		draw_set_transform(c, 0.0, Vector2.ONE * _fit())
		Sprites.draw(self, sprite, mod)
		if id == "boss_chest":
			Sprites.draw(self, "boss_chest_lid", mod, Vector2(0, -66))
		draw_set_transform(Vector2.ZERO)
