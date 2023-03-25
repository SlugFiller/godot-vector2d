@tool
extends Node2D
class_name Vector2DShapeSource

var dirty : bool = false

signal shape_changed

func get_shape() -> Array:
	dirty = false
	return _get_shape()

func _get_shape() -> Array:
	return []

func set_dirty() -> void:
	if !dirty:
		dirty = true
		emit_signal("shape_changed")

enum SEGMENT_TYPE {
	START,
	LINEAR,
	QUADRIC,
	CUBIC,
	ARC
}
