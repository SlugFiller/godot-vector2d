@tool
extends Node2D
class_name Vector2DFill

const SEGMENT_TYPE = Vector2DShapeSource.SEGMENT_TYPE

@export var color : Color = Color.WHITE:
	set(c):
		color = c
		queue_redraw()
@export var winding_even_odd : bool = false:
	set(even_odd):
		winding_even_odd = even_odd
		queue_redraw()
@export var feather : float = 1.0:
	set(_feather):
		feather = _feather
@export_enum("Flat", "Linear Gradient", "Radial Gradient") var paint_type : int = 0:
	set(_paint_type):
		paint_type = _paint_type
		_update_paint()
@export_enum("Pad", "Repeat", "Reflect") var gradient_spread_method : int = 0:
	set(_gradient_spread_method):
		gradient_spread_method = _gradient_spread_method
		_update_paint()
@export var gradient : Gradient = Gradient.new():
	set(_gradient):
		if !_gradient || !(_gradient is Gradient):
			_gradient = Gradient.new()
		if is_instance_valid(gradient) && gradient.changed.is_connected(Callable(self, "_update_paint")):
			gradient.changed.disconnect(Callable(self, "_update_paint"))
		gradient = _gradient
		gradient.changed.connect(Callable(self, "_update_paint"))
		_update_paint()
@export var gradient_point1 : Vector2 = Vector2.ZERO:
	set(_gradient_point1):
		gradient_point1 = _gradient_point1
		_update_paint()
@export var gradient_point2 : Vector2 = Vector2.ONE:
	set(_gradient_point2):
		gradient_point2 = _gradient_point2
		_update_paint()
@export var gradient_radius1 : float = 0:
	set(_gradient_radius1):
		gradient_radius1 = _gradient_radius1
		_update_paint()
@export var gradient_radius2 : float = 10:
	set(_gradient_radius2):
		gradient_radius2 = _gradient_radius2
		_update_paint()
@export var gradient_transform : Transform2D = Transform2D.IDENTITY:
	set(_gradient_transform):
		gradient_transform = _gradient_transform
		_update_paint()
var shape_node : Node = null
var flush_queued : bool = false

func _init() -> void:
	gradient.changed.connect(Callable(self, "_update_paint"))
	_update_paint()
	shape_node = null
	call_deferred("_check_shape_update")

func _enter_tree() -> void:
	call_deferred("_check_shape_update")

func _draw() -> void:
	if !is_instance_valid(shape_node):
		shape_node = null
	var segments : Array = [] if shape_node == null else shape_node.get_shape()
	var points_arr : Array[PackedVector2Array] = []
	var points : PackedVector2Array = PackedVector2Array()
	var types_arr : Array[PackedByteArray] = []
	var types : PackedByteArray = PackedByteArray()
	var type : int = 0
	var bit : int = 0
	var position : Vector2 = Vector2()
	for segment in segments:
		match segment[0]:
			SEGMENT_TYPE.START:
				if points.size() > 0:
					if bit > 0:
						types.push_back(type)
						type = 0
						bit = 0
					points_arr.push_back(points)
					types_arr.push_back(types)
					points = PackedVector2Array()
					types = PackedByteArray()
				points.push_back(segment[1])
				position = segment[1]
			SEGMENT_TYPE.LINEAR:
				bit += 1
				if bit > 7:
					types.push_back(type)
					type = 0
					bit = 0
				points.push_back((2*position+segment[1])/3)
				points.push_back((position+2*segment[1])/3)
				points.push_back(segment[1])
				position = segment[1]
			SEGMENT_TYPE.QUADRIC:
				bit += 1
				if bit > 7:
					types.push_back(type)
					type = 0
					bit = 0
				points.push_back((position+2*segment[1])/3)
				points.push_back((2*segment[1]+segment[2])/3)
				points.push_back(segment[2])
				position = segment[2]
			SEGMENT_TYPE.CUBIC:
				bit += 1
				if bit > 7:
					types.push_back(type)
					type = 0
					bit = 0
				points.push_back(segment[1])
				points.push_back(segment[2])
				points.push_back(segment[3])
				position = segment[3]
			SEGMENT_TYPE.ARC:
				type |= 1 << bit
				bit += 1
				if bit > 7:
					types.push_back(type)
					type = 0
					bit = 0
				points.push_back(segment[1])
				points.push_back(segment[2])
				points.push_back(segment[3])
				points.push_back(segment[4])
				position = segment[4]
	if points.size() > 0:
		if bit > 0:
			types.push_back(type)
			type = 0
			bit = 0
		points_arr.push_back(points)
		types_arr.push_back(types)
	draw_filled_curve(points_arr, types_arr, winding_even_odd, color)

func _check_shape_update() -> void:
	if !is_instance_valid(shape_node):
		shape_node = null
	var new_shape_node : Node = get_parent()
	if new_shape_node != null && !(new_shape_node is Vector2DShapeSource):
		new_shape_node = null
	if new_shape_node == shape_node:
		return
	if shape_node && shape_node.shape_changed.is_connected(Callable(self, "_queue_update_shape")):
		shape_node.shape_changed.disconnect(Callable(self, "_queue_update_shape"))
	shape_node = new_shape_node
	if shape_node && !shape_node.shape_changed.is_connected(Callable(self, "_queue_update_shape")):
		shape_node.shape_changed.connect(Callable(self, "_queue_update_shape"))
	_queue_update_shape()

func _queue_update_shape() -> void:
	if flush_queued:
		return
	flush_queued = true
	await RenderingServer.frame_pre_draw
	if !flush_queued:
		return
	flush_queued = false
	queue_redraw()

func _update_paint() -> void:
	match paint_type:
		1:
			self.material = ShaderMaterial.new()
			self.material.shader = preload("gradient.gdshader")
			match gradient_spread_method:
				1:
					self.material.set_shader_parameter("paint_type", 2)
				2:
					self.material.set_shader_parameter("paint_type", 3)
				_:
					self.material.set_shader_parameter("paint_type", 1)
		2:
			self.material = ShaderMaterial.new()
			self.material.shader = preload("gradient.gdshader")
			match gradient_spread_method:
				1:
					self.material.set_shader_parameter("paint_type", 5)
				2:
					self.material.set_shader_parameter("paint_type", 6)
				_:
					self.material.set_shader_parameter("paint_type", 4)
		_:
			self.material = null
			return
	self.material.set_shader_parameter("gradient_point1", gradient_point1)
	self.material.set_shader_parameter("gradient_point2", gradient_point2)
	self.material.set_shader_parameter("gradient_radius1", gradient_radius1)
	self.material.set_shader_parameter("gradient_radius2", gradient_radius2)
	self.material.set_shader_parameter("gradient_transform", gradient_transform)
	var buffer_stops : StreamPeerBuffer = StreamPeerBuffer.new()
	var buffer_colors : StreamPeerBuffer = StreamPeerBuffer.new()
	if gradient.get_point_count() < 1:
		buffer_stops.put_float(1.0)
		buffer_colors.put_u32(0)
	else :
		buffer_colors.put_u32(gradient.get_color(0).to_abgr32())
		if !is_zero_approx(gradient.get_offset(0)):
			buffer_stops.put_float(gradient.get_offset(0))
			buffer_colors.put_u32(gradient.get_color(0).to_abgr32())
		for i in gradient.get_point_count()-2:
			buffer_stops.put_float(gradient.get_offset(i+1))
			buffer_colors.put_u32(gradient.get_color(i+1).to_abgr32())
		if !is_equal_approx(gradient.get_offset(gradient.get_point_count()-1), 1.0):
			buffer_stops.put_float(gradient.get_offset(gradient.get_point_count()-1))
			buffer_colors.put_u32(gradient.get_color(gradient.get_point_count()-1).to_abgr32())
		buffer_stops.put_float(1.0)
		buffer_colors.put_u32(gradient.get_color(gradient.get_point_count()-1).to_abgr32())
	var image : Image = Image.create_from_data(buffer_stops.get_position()/4, 1, false, Image.FORMAT_RF, buffer_stops.data_array)
	var texture : ImageTexture = ImageTexture.create_from_image(image)
	self.material.set_shader_parameter("gradient_stops", texture)
	image = Image.create_from_data(buffer_colors.get_position()/4, 1, false, Image.FORMAT_RGBA8, buffer_colors.data_array)
	texture = ImageTexture.create_from_image(image)
	self.material.set_shader_parameter("gradient_colors", texture)
