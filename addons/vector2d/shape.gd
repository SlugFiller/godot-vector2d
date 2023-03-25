@tool
extends Vector2DShapeSource
class_name Vector2DShape

@export var shape : Resource = Vector2DShapeDefinition.new():
	set(_shape):
		if !_shape || !(_shape is Vector2DShapeDefinition):
			_shape = Vector2DShapeDefinition.new()
		if is_instance_valid(shape) && shape.changed.is_connected(Callable(self, "set_dirty")):
			shape.changed.disconnect(Callable(self, "set_dirty"))
		shape = _shape
		shape.changed.connect(Callable(self, "set_dirty"))
		set_dirty()

func _init():
	shape.changed.connect(Callable(self, "set_dirty"))

func _get_shape() -> Array:
	if !shape || !(shape is Vector2DShapeDefinition):
		shape = Vector2DShapeDefinition.new()
	return shape.segments
