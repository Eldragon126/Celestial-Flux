extends Node2D
class_name ResonanceZoneVisual

@onready var core: Polygon2D = $Core
@onready var ring: Line2D = $OuterRing
@onready var accent: Line2D = $InnerAccent
@onready var label: Label = $RuleLabel
@onready var particles: GPUParticles2D = $ZoneParticles


func get_glyph_nodes() -> Array[Line2D]:
	var glyphs: Array[Line2D] = []
	for child in get_children():
		if child is Line2D and child.name.begins_with("RuleGlyph"):
			glyphs.append(child as Line2D)
	glyphs.sort_custom(func(a: Line2D, b: Line2D) -> bool:
		return String(a.name) < String(b.name)
	)
	return glyphs


func to_visual_dictionary() -> Dictionary:
	return {
		"root": self,
		"core": core,
		"ring": ring,
		"accent": accent,
		"glyphs": get_glyph_nodes(),
		"label": label,
		"particles": particles,
		"particle_material": particles.process_material if particles != null else null,
		"zone_type": -1,
	}
