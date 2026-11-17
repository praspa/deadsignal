class_name LightUtil
## Procedurally generated (and cached) light textures — no image assets needed.

static var _radial: Dictionary = {}
static var _cone_tex: Texture2D


static func radial(size: int = 256) -> Texture2D:
	if _radial.has(size):
		return _radial[size]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_radial[size] = t
	return t


## A forward-facing flashlight cone; the light origin is the texture's left-centre.
static func cone() -> Texture2D:
	if _cone_tex != null:
		return _cone_tex
	var w := 512
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var half := deg_to_rad(26.0)
	for y in h:
		for x in w:
			var dx := float(x)
			var dy := float(y) - h * 0.5
			var dist := sqrt(dx * dx + dy * dy)
			var ang := absf(atan2(dy, maxf(dx, 0.001)))
			var a := 0.0
			if ang < half and dist < w:
				var radial_f := 1.0 - dist / float(w)
				var ang_f := 1.0 - smoothstep(half * 0.55, half, ang)
				a = radial_f * radial_f * ang_f
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_cone_tex = ImageTexture.create_from_image(img)
	return _cone_tex
