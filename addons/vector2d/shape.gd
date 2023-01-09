tool
extends "source.gd"

export var shape : Resource = Vector2DShapeDefinition.new() setget _set_shape

func _init():
	shape.connect("changed", self, "set_dirty")

func _set_shape(_shape) -> void:
	if !_shape || !(_shape is Vector2DShapeDefinition):
		_shape = Vector2DShapeDefinition.new()
	if is_instance_valid(shape) && shape.is_connected("changed", self, "set_dirty"):
		shape.disconnect("changed", self, "set_dirty")
	shape = _shape
	shape.connect("changed", self, "set_dirty")
	set_dirty()

func _get_shape() -> Array:
	if !shape || !(shape is Vector2DShapeDefinition):
		shape = Vector2DShapeDefinition.new()
	return shape.segments
