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
		if self.material:
			self.material.set_shader_parameter("evenOdd", even_odd)
@export var feather : float = 1.0:
	set(_feather):
		feather = _feather
		if self.material:
			self.material.set_shader_parameter("feather", feather)
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
	self.material = ShaderMaterial.new()
	self.material.shader = preload("fill.gdshader")
	self.material.set_shader_parameter("feather", feather)
	self.material.set_shader_parameter("evenOdd", winding_even_odd)
	gradient.changed.connect(Callable(self, "_update_paint"))
	_update_paint()
	var image : Image = Image.create_from_data(1, 1, false, Image.FORMAT_L8, PackedByteArray([0]))
	var texture : ImageTexture = ImageTexture.create_from_image(image)
	self.material.set_shader_parameter("segments", texture)
	self.material.set_shader_parameter("tree", texture)
	self.material.set_shader_parameter("bboxs", texture)
	self.material.set_shader_parameter("bbox_position", Vector2.ZERO)
	self.material.set_shader_parameter("bbox_size", Vector2.ZERO)
	shape_node = null
	call_deferred("_check_shape_update")

func _enter_tree() -> void:
	call_deferred("_check_shape_update")

func _draw() -> void:
	draw_rect(Rect2(-1e10, -1e10, 1e20, 1e20), color)

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
	_update_shape()

func _update_shape() -> void:
	if !is_instance_valid(shape_node):
		shape_node = null
	var bboxs : Array = []
	var buffer : StreamPeerBuffer = StreamPeerBuffer.new()
	var segments : Array = [] if shape_node == null else shape_node.get_shape()
	var start : Vector2 = Vector2()
	var position : Vector2 = Vector2()
	for segment in segments:
		match segment[0]:
			SEGMENT_TYPE.START:
				if !start.is_equal_approx(position):
					_write_line(buffer, position, start)
					var bbox : Rect2 = Rect2(position, Vector2.ZERO)
					bbox = bbox.expand(start)
					bboxs.append([bbox, bboxs.size()])
				start = segment[1]
				position = segment[1]
			SEGMENT_TYPE.LINEAR:
				_write_line(buffer, position, segment[1])
				var bbox : Rect2 = Rect2(position, Vector2.ZERO)
				bbox = bbox.expand(segment[1])
				bboxs.append([bbox, bboxs.size()])
				position = segment[1]
			SEGMENT_TYPE.QUADRIC:
				_write_quad(buffer, position, segment[1], segment[2])
				var bbox : Rect2 = Rect2(position, Vector2.ZERO)
				bbox = bbox.expand(segment[1])
				bbox = bbox.expand(segment[2])
				bboxs.append([bbox, bboxs.size()])
				position = segment[2]
			SEGMENT_TYPE.CUBIC:
				_write_cube(buffer, position, segment[1], segment[2], segment[3])
				var bbox : Rect2 = Rect2(position, Vector2.ZERO)
				bbox = bbox.expand(segment[1])
				bbox = bbox.expand(segment[2])
				bbox = bbox.expand(segment[3])
				bboxs.append([bbox, bboxs.size()])
				position = segment[3]
			SEGMENT_TYPE.ARC:
				var r1 : Vector2 = segment[1]-segment[2]
				var r2 : Vector2 = segment[3]-segment[2]
				var axis : Transform2D = Transform2D(r1, r2, Vector2()).affine_inverse()
				var a1 : float = axis.basis_xform(position-segment[2]).angle()
				var a2 : float = axis.basis_xform(segment[4]-segment[2]).angle()
				while a1 < 0:
					a1 += 2*PI
				while a1 >= 2*PI:
					a1 += 2*PI
				while a2 < a1:
					a2 += 2*PI
				while a2 >= a1+2*PI:
					a2 -= 2*PI
				var a3 : float = 0.5*PI
				while a3 <= a1:
					a3 += 0.5*PI
				var bbox : Rect2 = Rect2(position, Vector2.ZERO)
				var rstart : Vector2 = Vector2(1, 0).rotated(a1)
				var rend : Vector2 = Vector2(1, 0).rotated(a2)
				if a3 < a2:
					var rmid : Vector2 = Vector2(1, 0).rotated(a3)
					var pmid : Vector2 = rmid.x*r1+rmid.y*r2+segment[2]
					bbox = bbox.expand(rstart.x*r1+rstart.y*r2+segment[2]).expand(rstart.x*r1+rmid.y*r2+segment[2]).expand(rmid.x*r1+rstart.y*r2+segment[2]).expand(rmid.x*r1+rmid.y*r2+segment[2])
					bboxs.append([bbox, bboxs.size()])
					bbox = Rect2(pmid, Vector2.ZERO)
					_write_arc(buffer, rstart, rmid, segment[2], r1, r2, position, pmid)
					while a3+0.5*PI < a2:
						a3 += 0.5*PI
						var rnext : Vector2 = Vector2(1, 0).rotated(a3)
						var pnext : Vector2 = rnext.x*r1+rnext.y*r2+segment[2]
						bbox = bbox.expand(rmid.x*r1+rnext.y*r2+segment[2]).expand(rnext.x*r1+rmid.y*r2+segment[2]).expand(rnext.x*r1+rnext.y*r2+segment[2])
						bboxs.append([bbox, bboxs.size()])
						bbox = Rect2(pnext, Vector2.ZERO)
						_write_arc(buffer, rmid, rnext, segment[2], r1, r2, pmid, pnext)
						rmid = rnext
						pmid = pnext
					bbox = bbox.expand(rmid.x*r1+rend.y*r2+segment[2]).expand(rend.x*r1+rmid.y*r2+segment[2]).expand(rend.x*r1+rend.y*r2+segment[2])
					bbox = bbox.expand(segment[4])
					bboxs.append([bbox, bboxs.size()])
					_write_arc(buffer, rmid, rend, segment[2], r1, r2, pmid, segment[4])
				else:
					bbox = bbox.expand(rstart.x*r1+rstart.y*r2+segment[2]).expand(rstart.x*r1+rend.y*r2+segment[2]).expand(rend.x*r1+rstart.y*r2+segment[2]).expand(rend.x*r1+rend.y*r2+segment[2])
					bbox = bbox.expand(segment[4])
					bboxs.append([bbox, bboxs.size()])
					_write_arc(buffer, rstart, rend, segment[2], r1, r2, position, segment[4])
				position = segment[4]
	if !start.is_equal_approx(position):
		_write_line(buffer, position, start)
		var bbox : Rect2 = Rect2(position, Vector2.ZERO)
		bbox = bbox.expand(start)
		bboxs.append([bbox, bboxs.size()])
	if !bboxs.size():
		buffer.put_float(0.0);
		buffer.put_float(0.0);
		var image : Image = Image.create_from_data(1, 1, false, Image.FORMAT_L8, PackedByteArray([0]))
		var texture : ImageTexture = ImageTexture.create_from_image(image)
		self.material.set_shader_parameter("segments", texture)
		self.material.set_shader_parameter("tree", texture)
		self.material.set_shader_parameter("bboxs", texture)
		self.material.set_shader_parameter("bbox_position", Vector2.ZERO)
		self.material.set_shader_parameter("bbox_size", Vector2.ZERO)
		return
	var bbox : Rect2 = bboxs[0][0]
	for box in bboxs:
		bbox = bbox.merge(box[0])
	var tree : Array = []
	_build_tree(0, tree, bbox, bboxs, 32)
	var tree_buffer : StreamPeerBuffer = StreamPeerBuffer.new()
	var bbox_buffer : StreamPeerBuffer = StreamPeerBuffer.new()
	for node in tree:
		tree_buffer.put_16(node[1])
		tree_buffer.put_16(node[2])
		tree_buffer.put_16(node[3])
		tree_buffer.put_16(node[4])
		_put_vector(bbox_buffer, node[0].position)
		_put_vector(bbox_buffer, node[0].end)
	var image : Image = Image.create_from_data(8, buffer.get_position()/64, false, Image.FORMAT_RGF, buffer.data_array)
	var texture : ImageTexture = ImageTexture.create_from_image(image)
	self.material.set_shader_parameter("segments", texture)
	image = Image.create_from_data(4, tree_buffer.get_position()/8, false, Image.FORMAT_RG8, tree_buffer.data_array)
	texture = ImageTexture.create_from_image(image)
	self.material.set_shader_parameter("tree", texture)
	image = Image.create_from_data(2, bbox_buffer.get_position()/16, false, Image.FORMAT_RGF, bbox_buffer.data_array)
	texture = ImageTexture.create_from_image(image)
	self.material.set_shader_parameter("bboxs", texture)
	self.material.set_shader_parameter("bbox_position", bbox.position)
	self.material.set_shader_parameter("bbox_size", bbox.size)

static func _build_tree(parent : int, tree : Array, bbox : Rect2, bboxs : Array, max_depth : int) -> void:
	var element : Array = [bbox, parent, 0, 0, 0]
	var element_index : int = tree.size()
	tree.append(element)
	if bboxs.size() < 2:
		element[4] = bboxs[0][1]+1
		return
	element[2] = tree.size()
	if max_depth < 1:
		for box in bboxs:
			tree.append([box[0], element_index, 0, tree.size()+1, box[1]+1])
		tree[tree.size()-1][3] = 0
		return
	var bboxs_x_min : Array = bboxs.duplicate()
	var bboxs_y_min : Array = bboxs.duplicate()
	var bboxs_x_max : Array = bboxs.duplicate()
	var bboxs_y_max : Array = bboxs.duplicate()
	bboxs_x_min.sort_custom(func(a : Array, b : Array) -> bool: return a[0].position.x < b[0].position.x)
	bboxs_y_min.sort_custom(func(a : Array, b : Array) -> bool: return a[0].position.y < b[0].position.y)
	bboxs_x_max.sort_custom(func(a : Array, b : Array) -> bool: return a[0].end.x < b[0].end.x)
	bboxs_y_max.sort_custom(func(a : Array, b : Array) -> bool: return a[0].end.y < b[0].end.y)
	var metric_x_min : Array = []
	var metric_y_min : Array = []
	var metric_x_max : Array = []
	var metric_y_max : Array = []
	metric_x_min.resize(bboxs.size()-1)
	metric_y_min.resize(bboxs.size()-1)
	metric_x_max.resize(bboxs.size()-1)
	metric_y_max.resize(bboxs.size()-1)
	var bbox_x_min : Rect2 = bboxs_x_min[0][0]
	var bbox_y_min : Rect2 = bboxs_y_min[0][0]
	var bbox_x_max : Rect2 = bboxs_x_max[0][0]
	var bbox_y_max : Rect2 = bboxs_y_max[0][0]
	for i in bboxs.size()-1:
		bbox_x_min = bbox_x_min.merge(bboxs_x_min[i][0])
		bbox_y_min = bbox_y_min.merge(bboxs_y_min[i][0])
		bbox_x_max = bbox_x_max.merge(bboxs_x_max[i][0])
		bbox_y_max = bbox_y_max.merge(bboxs_y_max[i][0])
		metric_x_min[i] = max(bbox_x_min.size.x, bbox_x_min.size.y)
		metric_y_min[i] = max(bbox_y_min.size.x, bbox_y_min.size.y)
		metric_x_max[i] = max(bbox_x_max.size.x, bbox_x_max.size.y)
		metric_y_max[i] = max(bbox_y_max.size.x, bbox_y_max.size.y)
	bbox_x_min = bboxs_x_min[bboxs.size()-1][0]
	bbox_y_min = bboxs_y_min[bboxs.size()-1][0]
	bbox_x_max = bboxs_x_max[bboxs.size()-1][0]
	bbox_y_max = bboxs_y_max[bboxs.size()-1][0]
	for i in bboxs.size()-1:
		var j : int = bboxs.size()-2-i
		metric_x_min[j] = max(metric_x_min[j], max(bbox_x_min.size.x, bbox_x_min.size.y))
		metric_y_min[j] = max(metric_y_min[j], max(bbox_y_min.size.x, bbox_y_min.size.y))
		metric_x_max[j] = max(metric_x_max[j], max(bbox_x_max.size.x, bbox_x_max.size.y))
		metric_y_max[j] = max(metric_y_max[j], max(bbox_y_max.size.x, bbox_y_max.size.y))
		bbox_x_min = bbox_x_min.merge(bboxs_x_min[j][0])
		bbox_y_min = bbox_y_min.merge(bboxs_y_min[j][0])
		bbox_x_max = bbox_x_max.merge(bboxs_x_max[j][0])
		bbox_y_max = bbox_y_max.merge(bboxs_y_max[j][0])
	var min_metric = [metric_x_min.min(), metric_y_min.min(), metric_x_max.min(), metric_y_max.min()].min()
	var index : int
	var group1 : Array = []
	var group2 : Array = []
	index = metric_x_min.find(min_metric)
	if index >= 0:
		group1 = bboxs_x_min.slice(0, index+1)
		group2 = bboxs_x_min.slice(index+1, bboxs.size())
	else:
		index = metric_y_min.find(min_metric)
		if index >= 0:
			group1 = bboxs_y_min.slice(0, index+1)
			group2 = bboxs_y_min.slice(index+1, bboxs.size())
		else:
			index = metric_x_max.find(min_metric)
			if index >= 0:
				group1 = bboxs_x_max.slice(0, index+1)
				group2 = bboxs_x_max.slice(index+1, bboxs.size())
			else:
				index = metric_y_max.find(min_metric)
				if index >= 0:
					group1 = bboxs_y_max.slice(0, index+1)
					group2 = bboxs_y_max.slice(index+1, bboxs.size())
	if index < 0:
		for box in bboxs:
			tree.append([box[0], element_index, 0, tree.size()+1, box[1]+1])
		tree[tree.size()-1][3] = 0
		return
	var bbox1 : Rect2 = group1[0][0]
	for box in group1:
		bbox1 = bbox1.merge(box[0])
	var bbox2 : Rect2 = group2[0][0]
	for box in group2:
		bbox2 = bbox2.merge(box[0])
	_build_tree(element_index, tree, bbox1, group1, max_depth-1)
	tree[element_index+1][3] = tree.size()
	_build_tree(element_index, tree, bbox2, group2, max_depth-1)

static func _write_line(buffer : StreamPeerBuffer, start : Vector2, end : Vector2) -> void:
	buffer.put_float(0.0)
	buffer.put_float(0.0)
	_put_vector(buffer, start)
	_put_vector(buffer, end)
	_put_vector(buffer, Vector2.ZERO)
	_put_vector(buffer, Vector2.ZERO)
	_put_vector(buffer, Vector2.ZERO)
	_put_vector(buffer, Vector2.ZERO)
	_put_vector(buffer, Vector2.ZERO)

static func _write_quad(buffer : StreamPeerBuffer, start : Vector2, control : Vector2, end : Vector2) -> void:
	buffer.put_float(0.4)
	buffer.put_float(0.0)
	_put_vector(buffer, start)
	_put_vector(buffer, control)
	_put_vector(buffer, end)
	_put_vector(buffer, Vector2.ZERO)
	_put_vector(buffer, Vector2.ZERO)
	_put_vector(buffer, Vector2.ZERO)
	_put_vector(buffer, Vector2.ZERO)

static func _write_cube(buffer : StreamPeerBuffer, start : Vector2, control1 : Vector2, control2 : Vector2, end : Vector2) -> void:
	buffer.put_float(0.6)
	buffer.put_float(0.0)
	_put_vector(buffer, start)
	_put_vector(buffer, control1)
	_put_vector(buffer, control2)
	_put_vector(buffer, end)
	_put_vector(buffer, Vector2.ZERO)
	_put_vector(buffer, Vector2.ZERO)
	_put_vector(buffer, Vector2.ZERO)

static func _write_arc(buffer : StreamPeerBuffer, start : Vector2, end : Vector2, center : Vector2, radius1 : Vector2, radius2 : Vector2, pstart : Vector2, pend : Vector2) -> void:
	buffer.put_float(1.0)
	buffer.put_float(0.0)
	_put_vector(buffer, start)
	_put_vector(buffer, end)
	_put_vector(buffer, center)
	_put_vector(buffer, radius1)
	_put_vector(buffer, radius2)
	_put_vector(buffer, pstart)
	_put_vector(buffer, pend)

static func _put_vector(buffer : StreamPeerBuffer, vec : Vector2) -> void:
	if vec.x < 0.0:
		buffer.put_float(1.0/(2.0-vec.x))
	else:
		buffer.put_float(1.0-1.0/(2.0+vec.x))
	if vec.y < 0.0:
		buffer.put_float(1.0/(2.0-vec.y))
	else:
		buffer.put_float(1.0-1.0/(2.0+vec.y))

func _update_paint() -> void:
	if !self.material:
		return
	match paint_type:
		1:
			match gradient_spread_method:
				1:
					self.material.set_shader_parameter("paint_type", 2)
				2:
					self.material.set_shader_parameter("paint_type", 3)
				_:
					self.material.set_shader_parameter("paint_type", 1)
		2:
			match gradient_spread_method:
				1:
					self.material.set_shader_parameter("paint_type", 5)
				2:
					self.material.set_shader_parameter("paint_type", 6)
				_:
					self.material.set_shader_parameter("paint_type", 4)
		_:
			self.material.set_shader_parameter("paint_type", 0)
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
