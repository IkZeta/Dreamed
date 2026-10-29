class_name PixelView
extends SubViewportContainer
## Muestra un dibujo a baja resolución y lo amplía sin suavizar, para que se vea en pixel art.
## Se usa con los fondos y los personajes de los menús. No recibe clics.
## Shows a drawing at low resolution and scales it up without smoothing, so it reads as pixel
## art. Used for the menus' backgrounds and characters. It ignores clicks.

var _inner: Control


## Envuelve un dibujo; "shrink" es cuántos píxeles de pantalla mide cada píxel del arte
## Wraps a drawing; "shrink" is how many screen pixels each art pixel takes
static func wrap(inner: Control, shrink := 2) -> PixelView:
	var v := PixelView.new()
	v._inner = inner
	v.stretch = true
	v.stretch_shrink = shrink
	return v


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.msaa_2d = Viewport.MSAA_DISABLED
	vp.snap_2d_transforms_to_pixel = true
	vp.gui_disable_input = true
	add_child(vp)
	vp.add_child(_inner)
	_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE


## El dibujo de dentro / The drawing inside
func inner() -> Control:
	return _inner
