class_name FaceBadge
extends Control
## Medallón redondo con la cara de un personaje, del color de su aura (en pixel art). Para listas
## donde sale un personaje, como la chimenea de sacrificios.
## Round badge with a character's face, in their aura colour (pixel art). For lists where a
## character appears, such as the sacrifice fireplace.

const FACE := {"svinho": Vector2(100, 62), "stolk": Vector2(100, 60), "silly": Vector2(100, 70), "doc": Vector2(100, 66),
	"ad": Vector2(100, 64), "pinche": Vector2(100, 60), "magnus": Vector2(100, 72), "superk": Vector2(100, 58),
	"lilkey": Vector2(100, 62), "lynx": Vector2(100, 58), "charo": Vector2(100, 74)}

var who := "svinho"


static func make(id: String, px := 56.0) -> Control:
	var b := FaceBadge.new()
	b.who = id
	var v := PixelView.wrap(b, 2)
	v.custom_minimum_size = Vector2(px, px)
	v.size = Vector2(px, px)
	return v


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var mask := Control.new()
	mask.mouse_filter = MOUSE_FILTER_IGNORE
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(mask)
	mask.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mask.draw.connect(func() -> void:
		mask.draw_circle(size / 2.0, size.x / 2.0 - 2.0, _aura().darkened(0.45)))
	var face := Control.new()
	face.mouse_filter = MOUSE_FILTER_IGNORE
	mask.add_child(face)
	face.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	face.draw.connect(func() -> void:
		var s := size.x / 70.0
		var f: Vector2 = FACE.get(who, Vector2(100, 64))
		var at := size / 2.0 + Vector2(0, size.y * 0.12)
		NpcArt.draw(face, Transform2D(0.0, Vector2(s, s), 0.0, (at - f * s).round()), who, 0.0)
		face.draw_set_transform(Vector2.ZERO))


func _draw() -> void:
	var c := size / 2.0
	draw_circle(c, size.x / 2.0, Color("140e26"))
	draw_circle(c, size.x / 2.0 - 1.0, _aura())


func _aura() -> Color:
	return HubLayout.ISLES[who]["aura"] if HubLayout.ISLES.has(who) else UITheme.GOLD
