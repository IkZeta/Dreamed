class_name FXLayer
extends Sprite2D
## La capa donde se dibujan los efectos (tajos, rayos, anillos, garras, chispas...): un lienzo a la
## mitad de resolución que el del mundo, ampliado sin suavizar. Así los efectos salen con el mismo
## tamaño de píxel que los sprites (4 de pantalla) en vez de la mitad, y todo parece del mismo
## pixel art. Va en el mundo, por encima de los personajes; su cámara copia a la del mundo en
## cada fotograma (posición, zoom, giro y temblor). Los números y textos no pasan por aquí: a
## esta resolución no se leerían (FX los dibuja en su capa de texto, a la resolución del mundo).
## The layer the effects are drawn on (slashes, bolts, rings, claws, sparks...): a canvas at half
## the world's resolution, scaled up unsmoothed. That gives effects the same pixel size as the
## sprites (4 on screen) instead of half, so everything reads as the same pixel art. It sits in
## the world, above the characters; its camera copies the world's every frame (position, zoom,
## rotation and shake). Numbers and text don't go through here: at this resolution they'd be
## unreadable (FX draws them on its text layer, at the world's resolution).

## Cuánto más gordo es cada píxel de efecto que uno del mundo / How much fatter an effect pixel is than a world one
const SHRINK := 2

var world_camera: Camera2D
var _vp: SubViewport
var _cam: Camera2D


func _init() -> void:
	z_index = 50
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Después de que la cámara del mundo se haya movido este fotograma / After the world camera has moved this frame
	process_priority = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.msaa_2d = Viewport.MSAA_DISABLED
	_vp.snap_2d_transforms_to_pixel = true
	_vp.gui_disable_input = true
	_vp.size = Vector2i(480, 270)
	add_child(_vp)
	_cam = Camera2D.new()
	_cam.ignore_rotation = false
	_vp.add_child(_cam)
	_cam.make_current()
	texture = _vp.get_texture()


## Mete un nodo en el lienzo de efectos / Puts a node on the effects canvas
func add_fx(node: Node) -> void:
	_vp.add_child(node)


func _process(_delta: float) -> void:
	sync()


func sync() -> void:
	if not is_instance_valid(world_camera) or not is_inside_tree():
		return
	var world_size := Vector2(get_viewport().get_visible_rect().size)
	var size := Vector2i((world_size / SHRINK).ceil())
	if size.x < 2 or size.y < 2:
		return
	if _vp.size != size:
		_vp.size = size
	var ratio := world_size / Vector2(size)
	var centre := world_camera.get_screen_center_position()
	var zoom := world_camera.zoom
	# La cámara de efectos ve lo mismo que la del mundo, en menos píxeles
	# The effects camera sees what the world's does, in fewer pixels
	_cam.position = centre
	_cam.zoom = zoom / ratio
	_cam.rotation = world_camera.global_rotation
	global_position = centre
	global_rotation = world_camera.global_rotation
	scale = ratio / zoom
