@tool
extends Resource
class_name Vector2DShapeDefinition

const SEGMENT_TYPE = Vector2DShapeSource.SEGMENT_TYPE
var segments : Array
var segment_regex : RegEx

func _init() -> void:
	segments = []
	segment_regex = RegEx.new()
	segment_regex.compile("^([0-9]+)_(start_position|start_closed|linear_end|quadric_control|quadric_end|cubic_control1|cubic_control2|cubic_end|arc_center|arc_axis1|arc_axis2|arc_end)$")

func _get_property_list() -> Array:
	var properties : Array = [{
		"name": "path",
		"type": TYPE_ARRAY,
		"usage": PROPERTY_USAGE_STORAGE
	}, {
		"name": "Vector2DShape",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_CATEGORY
	}]
	var index : int = 0
	for segment in segments:
		match segment[0]:
			SEGMENT_TYPE.START:
				properties.push_back({
					"name": str(index)+"_start",
					"hint_string": str(index)+"_start_",
					"type": TYPE_NIL,
					"usage": PROPERTY_USAGE_GROUP
				})
				properties.push_back({
					"name": str(index)+"_start_position",
					"type": TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_EDITOR
				})
				properties.push_back({
					"name": str(index)+"_start_closed",
					"type": TYPE_BOOL,
					"usage": PROPERTY_USAGE_EDITOR
				})
			SEGMENT_TYPE.LINEAR:
				properties.push_back({
					"name": str(index)+"_linear",
					"hint_string": str(index)+"_linear_",
					"type": TYPE_NIL,
					"usage": PROPERTY_USAGE_GROUP
				})
				properties.push_back({
					"name": str(index)+"_linear_end",
					"type": TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_EDITOR
				})
			SEGMENT_TYPE.QUADRIC:
				properties.push_back({
					"name": str(index)+"_quadric",
					"hint_string": str(index)+"_quadric_",
					"type": TYPE_NIL,
					"usage": PROPERTY_USAGE_GROUP
				})
				properties.push_back({
					"name": str(index)+"_quadric_control",
					"type": TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_EDITOR
				})
				properties.push_back({
					"name": str(index)+"_quadric_end",
					"type": TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_EDITOR
				})
			SEGMENT_TYPE.CUBIC:
				properties.push_back({
					"name": str(index)+"_cubic",
					"hint_string": str(index)+"_cubic_",
					"type": TYPE_NIL,
					"usage": PROPERTY_USAGE_GROUP
				})
				properties.push_back({
					"name": str(index)+"_cubic_control1",
					"type": TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_EDITOR
				})
				properties.push_back({
					"name": str(index)+"_cubic_control2",
					"type": TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_EDITOR
				})
				properties.push_back({
					"name": str(index)+"_cubic_end",
					"type": TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_EDITOR
				})
			SEGMENT_TYPE.ARC:
				properties.push_back({
					"name": str(index)+"_arc",
					"hint_string": str(index)+"_arc_",
					"type": TYPE_NIL,
					"usage": PROPERTY_USAGE_GROUP
				})
				properties.push_back({
					"name": str(index)+"_arc_axis1",
					"type": TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_EDITOR
				})
				properties.push_back({
					"name": str(index)+"_arc_center",
					"type": TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_EDITOR
				})
				properties.push_back({
					"name": str(index)+"_arc_axis2",
					"type": TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_EDITOR
				})
				properties.push_back({
					"name": str(index)+"_arc_end",
					"type": TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_EDITOR
				})
		index += 1
	return properties

func _get(property: StringName):
	if property == "path":
		return segments
	var result : RegExMatch = segment_regex.search(property)
	if !result:
		return null
	var index1 : int = int(result.get_string(1))
	var index2 : int = 1
	match result.get_string(2):
		"start_closed":
			return !!(segments[index1][2] & 1)
		"quadric_end":
			index2 = 2
		"cubic_control2":
			index2 = 2
		"cubic_end":
			index2 = 3
		"arc_center":
			index2 = 2
		"arc_axis2":
			index2 = 3
		"arc_end":
			index2 = 4
	return segments[index1][index2]

func _set(property: StringName, value) -> bool:
	if property == "path":
		if typeof(value) == TYPE_ARRAY:
			segments = []
			for segment in value:
				if typeof(segment) == TYPE_ARRAY && segment.size() > 1 && typeof(segment[0]) == TYPE_INT:
					match segment[0]:
						SEGMENT_TYPE.START:
							if segment.size() > 2 && typeof(segment[1]) == TYPE_VECTOR2 && typeof(segment[2]) == TYPE_INT:
								segments.append([SEGMENT_TYPE.START, segment[1], segment[2]])
						SEGMENT_TYPE.LINEAR:
							if typeof(segment[1]) == TYPE_VECTOR2:
								segments.append([SEGMENT_TYPE.LINEAR, segment[1]])
						SEGMENT_TYPE.QUADRIC:
							if segment.size() > 2 && typeof(segment[1]) == TYPE_VECTOR2 && typeof(segment[2]) == TYPE_VECTOR2:
								segments.append([SEGMENT_TYPE.QUADRIC, segment[1], segment[2]])
						SEGMENT_TYPE.CUBIC:
							if segment.size() > 3 && typeof(segment[1]) == TYPE_VECTOR2 && typeof(segment[2]) == TYPE_VECTOR2 && typeof(segment[3]) == TYPE_VECTOR2:
								segments.append([SEGMENT_TYPE.CUBIC, segment[1], segment[2], segment[3]])
						SEGMENT_TYPE.ARC:
							if segment.size() > 4 && typeof(segment[1]) == TYPE_VECTOR2 && typeof(segment[2]) == TYPE_VECTOR2 && typeof(segment[3]) == TYPE_VECTOR2 && typeof(segment[4]) == TYPE_VECTOR2:
								segments.append([SEGMENT_TYPE.ARC, segment[1], segment[2], segment[3], segment[4]])
		emit_signal("changed")
		return true
	var result : RegExMatch = segment_regex.search(property)
	if !result:
		return false
	var index1 : int = int(result.get_string(1))
	var index2 : int = 1
	match result.get_string(2):
		"start_closed":
			index2 = 2
			value = (segments[index1][index2] & ~1)|(1 if value else 0)
		"quadric_end":
			index2 = 2
		"cubic_control2":
			index2 = 2
		"cubic_end":
			index2 = 3
		"arc_center":
			index2 = 2
		"arc_axis2":
			index2 = 3
		"arc_end":
			index2 = 4
	segments[index1][index2] = value
	emit_signal("changed")
	return true
