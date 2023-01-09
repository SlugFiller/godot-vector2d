tool
extends "source.gd"

const MAX_DEPTH : int = 4
const TEST_DIVISIONS : int = 16
const TOLERANCE : float = 0.0001

export var stroke_width : float = 1.0 setget _set_width
export var miter_limit : float = 4.0 setget _set_limit
export(int, "Arcs", "Bevel", "Miter", "Miter Clip", "Round") var join_type : int = 2 setget _set_join
export(int, "Butt", "Round", "Square") var cap_type : int = 0 setget _set_cap
var shape_node : Node = null

func _init() -> void:
	shape_node = null
	call_deferred("_check_shape_update")

func _enter_tree() -> void:
	call_deferred("_check_shape_update")

func _check_shape_update() -> void:
	if !is_instance_valid(shape_node):
		shape_node = null
	var new_shape_node : Node = get_parent()
	if new_shape_node != null && !(new_shape_node is preload("source.gd")):
		new_shape_node = null
	if new_shape_node == shape_node:
		return
	if shape_node && shape_node.is_connected("shape_changed", self, "set_dirty"):
		shape_node.disconnect("shape_changed", self, "set_dirty")
	shape_node = new_shape_node
	if shape_node && !shape_node.is_connected("shape_changed", self, "set_dirty"):
		shape_node.connect("shape_changed", self, "set_dirty")
	set_dirty()

func _get_shape() -> Array:
	if !shape_node:
		return []
	return _offset_shape(shape_node.get_shape())

func _set_width(width : float) -> void:
	if width < 0.0:
		return
	stroke_width = width
	set_dirty()

func _set_limit(limit : float) -> void:
	if limit < 0.0:
		return
	miter_limit = limit
	set_dirty()

func _set_join(join : int) -> void:
	if join < 0 || join > 4:
		return
	join_type = join
	set_dirty()

func _set_cap(cap : int) -> void:
	if cap < 0 || cap > 2:
		return
	cap_type = cap
	set_dirty()

func _offset_shape(segments : Array) -> Array:
	var dest : Array = []
	var subpath : Array = []
	for segment in segments:
		if segment[0] == SEGMENT_TYPE.START:
			if subpath.size() > 0:
				_process_subpath(subpath, dest)
				subpath = []
		else:
			if subpath.size() < 1:
				# Implicit start path
				subpath.append([SEGMENT_TYPE.START, segment[1], 0])
		subpath.append(segment)
	if subpath.size() > 0:
		_process_subpath(subpath, dest)
	return dest

func _process_subpath(subpath : Array, dest : Array):
	var closed : bool = subpath[0][2] & 1
	var rev : Array = _reverse_segments(subpath)
	subpath = _offset_subpath(subpath)
	rev = _offset_subpath(rev)
	if closed:
		for segment in subpath:
			dest.append(segment)
		for segment in rev:
			dest.append(segment)
	else:
		var pos : Vector2
		pos = _get_last_point(subpath[subpath.size()-1])
		if !pos.is_equal_approx(rev[0][1]):
			subpath.append([SEGMENT_TYPE.LINEAR, rev[0][1]])
		pos = _get_last_point(rev[rev.size()-1])
		if !pos.is_equal_approx(subpath[0][1]):
			rev.append([SEGMENT_TYPE.LINEAR, subpath[0][1]])
		for segment in subpath:
			dest.append(segment)
		var first : bool = true
		for segment in rev:
			if first:
				first = false
			else:
				dest.append(segment)

func _offset_subpath(segments : Array) -> Array:
	var dest : Array = []
	var join : Array = []
	for segment in segments:
		_offset_segment(join, segment, dest)
		if join.size() > 1:
			join[3] = true
	if segments[0][2] & 1:
		if join.size() > 1:
			if join[0].is_equal_approx(join[4]):
				_join(dest, join[0], join[1], join[2], join[3], join[5], join[6])
			else:
				# Add straight line to close the path
				var tangent : Vector2 = (join[4]-join[0]).normalized().tangent()
				_join(dest, join[0], join[1], join[2], join[3], tangent, 0)
				dest.append([SEGMENT_TYPE.LINEAR, join[4]+tangent*(stroke_width*0.5)])
				_join(dest, join[4], tangent, 0, join[3], join[5], join[6])
	elif join.size() > 0:
		match cap_type:
			1:
				if join.size() <= 1:
					dest.append([SEGMENT_TYPE.START, join[0]-Vector2(stroke_width*0.5, 0.0), 1])
					dest.append([SEGMENT_TYPE.ARC, join[0]+Vector2(0.0, stroke_width*0.5), join[0], join[0]+Vector2(stroke_width*0.5, 0.0), join[0]+Vector2(stroke_width*0.5, 0.0)])
					dest.append([SEGMENT_TYPE.ARC, join[0]-Vector2(0.0, stroke_width*0.5), join[0], join[0]-Vector2(stroke_width*0.5, 0.0), join[0]-Vector2(stroke_width*0.5, 0.0)])
				else:
					dest.append([SEGMENT_TYPE.ARC, join[0]-join[1].tangent()*(stroke_width*0.5), join[0], join[0]-join[1]*(stroke_width*0.5), join[0]-join[1]*(stroke_width*0.5)])
			2:
				if join.size() <= 1:
					dest.append([SEGMENT_TYPE.START, join[0], 1])
				else:
					dest.append([SEGMENT_TYPE.LINEAR, join[0]+(join[1]-join[1].tangent())*(stroke_width*0.5)])
					dest.append([SEGMENT_TYPE.LINEAR, join[0]-(join[1]+join[1].tangent())*(stroke_width*0.5)])
			_:
				if join.size() <= 1:
					dest.append([SEGMENT_TYPE.START, join[0], 1])
	return dest

func _offset_segment(join : Array, segment : Array, dest : Array) -> void:
	match segment[0]:
		SEGMENT_TYPE.START:
			join.resize(1)
			join[0] = segment[1]
		SEGMENT_TYPE.LINEAR:
			_offset_linear(join, segment[1], dest)
		SEGMENT_TYPE.QUADRIC:
			_offset_quadric(join, segment[1], segment[2], dest, MAX_DEPTH)
		SEGMENT_TYPE.CUBIC:
			_offset_cubic(join, segment[1], segment[2], segment[3], dest, MAX_DEPTH)
		SEGMENT_TYPE.ARC:
			if segment[1].is_equal_approx(segment[2]) && segment[3].is_equal_approx(segment[2]):
				_offset_linear(join, segment[2], dest)
				_offset_linear(join, segment[4], dest)
				return
			var axis : Transform2D = Transform2D(segment[1]-segment[2], segment[3]-segment[2], Vector2())
			var axis_inv : Transform2D = axis.affine_inverse()
			var a1 : float = axis_inv.basis_xform(join[0]-segment[2]).angle()
			var a2 : float = axis_inv.basis_xform(segment[4]-segment[2]).angle()
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
			_offset_linear(join, segment[2]+axis.basis_xform(Vector2(1, 0).rotated(a1)), dest)
			if a3 < a2:
				_offset_arc(join, segment[2], axis, Vector2(1, 0).rotated(a1), Vector2(1, 0).rotated(a3), dest, MAX_DEPTH)
				while a3+0.5*PI < a2:
					_offset_arc(join, segment[2], axis, Vector2(1, 0).rotated(a3), Vector2(1, 0).rotated(a3+0.5*PI), dest, MAX_DEPTH)
					a3 += 0.5*PI
				_offset_arc(join, segment[2], axis, Vector2(1, 0).rotated(a3), Vector2(1, 0).rotated(a2), dest, MAX_DEPTH)
			else:
				_offset_arc(join, segment[2], axis, Vector2(1, 0).rotated(a1), Vector2(1, 0).rotated(a2), dest, MAX_DEPTH)
			_offset_linear(join, segment[4], dest)

func _offset_linear(join : Array, end : Vector2, dest : Array) -> void:
	if join.size() < 1:
		join.append(end)
		return
	if join[0].is_equal_approx(end):
		return
	var tangent : Vector2 = (end-join[0]).normalized().tangent()
	if join.size() > 1:
		_join(dest, join[0], join[1], join[2], join[3], tangent, 0.0)
	else:
		dest.append([SEGMENT_TYPE.START, join[0]+tangent*(stroke_width*0.5), 1])
		join.resize(7)
		join[4] = join[0]
		join[5] = tangent
		join[6] = 0.0
	dest.append([SEGMENT_TYPE.LINEAR, end+tangent*(stroke_width*0.5)])
	join[0] = end
	join[1] = tangent
	join[2] = 0.0
	join[3] = false

func _offset_quadric(join : Array, control : Vector2, end : Vector2, dest : Array, max_depth : int) -> void:
	if join.size() < 1:
		join.append(control)
	var start : Vector2 = join[0]
	if start.is_equal_approx(control) && start.is_equal_approx(end):
		return
	var tangent_start : Vector2 = ((end-start) if start.is_equal_approx(control) else (control-start)).normalized().tangent()
	var tangent_end : Vector2 = ((end-start) if end.is_equal_approx(control) else (end-control)).normalized().tangent()
	var tangent_mid : Vector2 = ((control-start) if end.is_equal_approx(start) else ((end-start).tangent())).normalized()
	var start_shift : Vector2 = start+tangent_start*(stroke_width*0.5)
	var control1_shift : Vector2 = control+tangent_start*(stroke_width*0.5)
	var control2_shift : Vector2 = control+tangent_end*(stroke_width*0.5)
	var control_shift : Vector2 = control+(4.0*tangent_mid-(tangent_start+tangent_end))*(stroke_width*0.25)
	var end_shift : Vector2 = end+tangent_end*(stroke_width*0.5)
	var offset : Vector2 = ((4.0*tangent_mid-2.0*(tangent_start+tangent_end))*stroke_width+(start+end-2*control))*(1.0/3.0)
	if !offset.is_equal_approx(Vector2.ZERO):
		var c1 : Vector2 = control-start
		var c2 : Vector2 = control-end
		var det : float = c1.cross(c2)
		if is_zero_approx(det):
			if !c1.is_equal_approx(Vector2.ZERO):
				c1 = c1.normalized()
				var ofs : Vector2 = 0.5*c1*offset.dot(c1)
				control1_shift += ofs
				control2_shift += ofs
			elif !c2.is_equal_approx(Vector2.ZERO):
				c2 = c2.normalized()
				var ofs : Vector2 = 0.5*c2*offset.dot(c2)
				control1_shift += ofs
				control2_shift += ofs
		else:
			control1_shift += c1*((offset.x*c2.y-offset.y*c2.x)/det)
			control2_shift += c2*((offset.y*c1.x-offset.x*c1.y)/det)
	if max_depth > 0:
		var err : float = 0.0
		var worst : float = 0.0
		for i in TEST_DIVISIONS-2:
			var t : float = float(i+1)/TEST_DIVISIONS
			var a1 : Vector2 = start+t*(control-start)
			var a2 : Vector2 = control+t*(end-control)
			var b : Vector2 = a1+t*(a2-a1)
			b += ((b-a1) if !b.is_equal_approx(a1) else (b-start)).tangent().normalized()*stroke_width*0.5
			var u1 : Vector2 = start_shift+t*(control1_shift-start_shift)
			var u2 : Vector2 = control1_shift+t*(control2_shift-control1_shift)
			var u3 : Vector2 = control2_shift+t*(end_shift-control2_shift)
			var v1 : Vector2 = u1+t*(u2-u1)
			var v2 : Vector2 = u2+t*(u3-u2)
			var w : Vector2 = v1+t*(v2-v1)
			var l : float = b.distance_squared_to(w)
			if l > err:
				err = l
				worst = t
		if err > TOLERANCE*stroke_width*stroke_width:
			var t : float = worst
			var a1 : Vector2 = start+t*(control-start)
			var a2 : Vector2 = control+t*(end-control)
			var b : Vector2 = a1+t*(a2-a1)
			_offset_quadric(join, a1, b, dest, max_depth-1)
			_offset_quadric(join, a2, end, dest, max_depth-1)
			return
	var curvature_start : float = control.distance_to(start)
	if is_zero_approx(curvature_start):
		curvature_start = 0.0
	else:
		curvature_start = curvature_start*curvature_start*curvature_start
		curvature_start = 0.5*(control-start).cross(end-control)/curvature_start
	var curvature_end : float = control.distance_to(end)
	if is_zero_approx(curvature_end):
		curvature_end = 0.0
	else:
		curvature_end = curvature_end*curvature_end*curvature_end
		curvature_end = 0.5*(end-control).cross(start-control)/curvature_end
	if join.size() > 1:
		_join(dest, join[0], join[1], join[2], join[3], tangent_start, curvature_start)
	else:
		dest.append([SEGMENT_TYPE.START, start_shift, 1])
		join.resize(7)
		join[4] = start
		join[5] = tangent_start
		join[6] = curvature_start
	dest.append([SEGMENT_TYPE.CUBIC, control1_shift, control2_shift, end_shift])
	join[0] = end
	join[1] = tangent_end
	join[2] = curvature_end
	join[3] = false

func _offset_cubic(join : Array, control1 : Vector2, control2 : Vector2, end : Vector2, dest : Array, max_depth : int) -> void:
	if join.size() < 1:
		join.append(control1)
	var start : Vector2 = join[0]
	if start.is_equal_approx(control1) && start.is_equal_approx(control2) && start.is_equal_approx(end):
		return
	var tangent_start : Vector2
	if !start.is_equal_approx(control1):
		tangent_start = control1-start
	elif !start.is_equal_approx(control2):
		tangent_start = control2-start
	else:
		tangent_start = end-start
	tangent_start = tangent_start.normalized().tangent()
	var tangent_end : Vector2
	if !end.is_equal_approx(control2):
		tangent_end = end-control2
	elif !end.is_equal_approx(control1):
		tangent_end = end-control1
	else:
		tangent_end = end-start
	tangent_end = tangent_end.normalized().tangent()
	var tangent_mid : Vector2 = ((end+control2)-(start+control1)).normalized().tangent()
	var start_shift : Vector2 = start+tangent_start*(stroke_width*0.5)
	var control1_shift : Vector2 = control1+tangent_start*(stroke_width*0.5)
	var control2_shift : Vector2 = control2+tangent_end*(stroke_width*0.5)
	var end_shift : Vector2 = end+tangent_end*(stroke_width*0.5)
	var offset : Vector2 = (tangent_mid-0.5*(tangent_start+tangent_end))*(stroke_width*(4.0/3.0))
	if !offset.is_equal_approx(Vector2.ZERO):
		var c1 : Vector2 = control1-start
		var c2 : Vector2 = control2-end
		var det : float = c1.cross(c2)
		if is_zero_approx(det):
			if !c1.is_equal_approx(Vector2.ZERO):
				c1 = c1.normalized()
				var ofs : Vector2 = 0.5*c1*offset.dot(c1)
				control1_shift += ofs
				control2_shift += ofs
			elif !c2.is_equal_approx(Vector2.ZERO):
				c2 = c2.normalized()
				var ofs : Vector2 = 0.5*c2*offset.dot(c2)
				control1_shift += ofs
				control2_shift += ofs
		else:
			control1_shift += c1*((offset.x*c2.y-offset.y*c2.x)/det)
			control2_shift += c2*((offset.y*c1.x-offset.x*c1.y)/det)
	if max_depth > 0:
		var err : float = 0.0
		var worst : float = 0.0
		for i in TEST_DIVISIONS-2:
			var t : float = float(i+1)/TEST_DIVISIONS
			var a1 : Vector2 = start+t*(control1-start)
			var a2 : Vector2 = control1+t*(control2-control1)
			var a3 : Vector2 = control2+t*(end-control2)
			var b1 : Vector2 = a1+t*(a2-a1)
			var b2 : Vector2 = a2+t*(a3-a2)
			var c : Vector2 = b1+t*(b2-b1)
			c += ((c-b1) if !c.is_equal_approx(b1) else ((c-a1) if !c.is_equal_approx(a1) else (c-start))).tangent().normalized()*stroke_width*0.5
			var u1 : Vector2 = start_shift+t*(control1_shift-start_shift)
			var u2 : Vector2 = control1_shift+t*(control2_shift-control1_shift)
			var u3 : Vector2 = control2_shift+t*(end_shift-control2_shift)
			var v1 : Vector2 = u1+t*(u2-u1)
			var v2 : Vector2 = u2+t*(u3-u2)
			var w : Vector2 = v1+t*(v2-v1)
			var l : float = c.distance_squared_to(w)
			if l > err:
				err = l
				worst = t
		if err > TOLERANCE*stroke_width*stroke_width:
			var t : float = worst
			var a1 : Vector2 = start+t*(control1-start)
			var a2 : Vector2 = control1+t*(control2-control1)
			var a3 : Vector2 = control2+t*(end-control2)
			var b1 : Vector2 = a1+t*(a2-a1)
			var b2 : Vector2 = a2+t*(a3-a2)
			var c : Vector2 = b1+t*(b2-b1)
			_offset_cubic(join, a1, b1, c, dest, max_depth-1)
			_offset_cubic(join, b2, a3, end, dest, max_depth-1)
			return
	var curvature_start : float = control1.distance_to(start)
	if is_zero_approx(curvature_start):
		curvature_start = 0.0
	else:
		curvature_start = curvature_start*curvature_start*curvature_start
		curvature_start = (2.0/3.0)*(control1-start).cross(control2-control1)/curvature_start
	var curvature_end : float = control2.distance_to(end)
	if is_zero_approx(curvature_end):
		curvature_end = 0.0
	else:
		curvature_end = curvature_end*curvature_end*curvature_end
		curvature_end = (2.0/3.0)*(end-control2).cross(control1-control2)/curvature_end
	if join.size() > 1:
		_join(dest, join[0], join[1], join[2], join[3], tangent_start, curvature_start)
	else:
		dest.append([SEGMENT_TYPE.START, start_shift, 1])
		join.resize(7)
		join[4] = start
		join[5] = tangent_start
		join[6] = curvature_start
	dest.append([SEGMENT_TYPE.CUBIC, control1_shift, control2_shift, end_shift])
	join[0] = end
	join[1] = tangent_end
	join[2] = curvature_end
	join[3] = false

func _offset_arc(join : Array, center : Vector2, axis : Transform2D, start : Vector2, end : Vector2, dest : Array, max_depth : int) -> void:
	if join.size() < 1:
		join.append(center+axis.basis_xform(start))
	if start.is_equal_approx(end):
		return
	var control : Vector2 = (start+end)/((start+end).dot(start))
	var tangent_start : Vector2 = axis.basis_xform(control-start).tangent().normalized()
	var tangent_end : Vector2 = axis.basis_xform(end-control).tangent().normalized()
	var mid : Vector2 = (start+end).normalized()
	var tangent_mid : Vector2 = axis.basis_xform(-mid.tangent()).tangent().normalized()
	var start_shift : Vector2 = center+axis.basis_xform(start)+tangent_start*(stroke_width*0.5)
	var control1_shift : Vector2 = center+axis.basis_xform(control)+tangent_start*(stroke_width*0.5)
	var control2_shift : Vector2 = center+axis.basis_xform(control)+tangent_end*(stroke_width*0.5)
	var end_shift : Vector2 = center+axis.basis_xform(end)+tangent_end*(stroke_width*0.5)
	var offset : Vector2 = ((4.0*tangent_mid-2.0*(tangent_start+tangent_end))*stroke_width+axis.basis_xform(8.0*mid-start-end-6.0*control))*(1.0/3.0)
	if !offset.is_equal_approx(Vector2.ZERO):
		var c1 : Vector2 = axis.basis_xform(control-start)
		var c2 : Vector2 = axis.basis_xform(control-end)
		var det : float = c1.cross(c2)
		if is_zero_approx(det):
			if !c1.is_equal_approx(Vector2.ZERO):
				c1 = c1.normalized()
				var ofs : Vector2 = 0.5*c1*offset.dot(c1)
				control1_shift += ofs
				control2_shift += ofs
			elif !c2.is_equal_approx(Vector2.ZERO):
				c2 = c2.normalized()
				var ofs : Vector2 = 0.5*c2*offset.dot(c2)
				control1_shift += ofs
				control2_shift += ofs
		else:
			control1_shift += c1*((offset.x*c2.y-offset.y*c2.x)/det)
			control2_shift += c2*((offset.y*c1.x-offset.x*c1.y)/det)
	if max_depth > 0:
		var angle : float = acos(start.dot(end))
		var err : float = 0.0
		var worst : float = 0.0
		for i in TEST_DIVISIONS-2:
			var t : float = float(i+1)/TEST_DIVISIONS
			var mid1 : Vector2 = start.rotated(t*angle)
			var p : Vector2 = (center+axis.basis_xform(mid1))-axis.basis_xform(mid1.tangent()).normalized().tangent()*(stroke_width*0.5)
			var u1 : Vector2 = start_shift+t*(control1_shift-start_shift)
			var u2 : Vector2 = control1_shift+t*(control2_shift-control1_shift)
			var u3 : Vector2 = control2_shift+t*(end_shift-control2_shift)
			var v1 : Vector2 = u1+t*(u2-u1)
			var v2 : Vector2 = u2+t*(u3-u2)
			var w : Vector2 = v1+t*(v2-v1)
			var l : float = p.distance_squared_to(w)
			if l > err:
				err = l
				worst = t
		if err > TOLERANCE*stroke_width*stroke_width:
			var t : float = worst
			var mid1 : Vector2 = start.rotated(t*angle)
			_offset_arc(join, center, axis, start, mid1, dest, max_depth-1)
			_offset_arc(join, center, axis, mid1, end, dest, max_depth-1)
			return
	var curvature_start : float = axis.basis_xform((control-start).normalized()).length()
	if is_zero_approx(curvature_start):
		curvature_start = 0.0
	else:
		curvature_start = curvature_start*curvature_start*curvature_start
		curvature_start = axis.x.cross(axis.y)/curvature_start
	var curvature_end : float = axis.basis_xform((control-end).normalized()).length()
	if is_zero_approx(curvature_end):
		curvature_end = 0.0
	else:
		curvature_end = curvature_end*curvature_end*curvature_end
		curvature_end = axis.x.cross(axis.y)/curvature_end
	if join.size() > 1:
		_join(dest, join[0], join[1], join[2], join[3], tangent_start, curvature_start)
	else:
		dest.append([SEGMENT_TYPE.START, start_shift, 1])
		join.resize(7)
		join[4] = center+axis.basis_xform(start)
		join[5] = tangent_start
		join[6] = curvature_start
	dest.append([SEGMENT_TYPE.CUBIC, control1_shift, control2_shift, end_shift])
	join[0] = center+axis.basis_xform(end)
	join[1] = tangent_end
	join[2] = curvature_end
	join[3] = false

func _join(dest : Array, point : Vector2, tangent_start : Vector2, curvature_start : float, allow_type : bool, tangent_end : Vector2, curvature_end : float) -> void:
	if tangent_start.is_equal_approx(tangent_end):
		return
	if tangent_start.tangent().dot(tangent_end) > 0.0:
		dest.append([SEGMENT_TYPE.LINEAR, point+tangent_end*(stroke_width*0.5)])
		return
	match join_type if allow_type else 4:
		0:
			if is_zero_approx(curvature_start) && is_zero_approx(curvature_end):
				_miter(dest, point, tangent_start, tangent_end, true)
				return
			if curvature_start*stroke_width > 2.0 || curvature_end*stroke_width > 2.0:
				dest.append([SEGMENT_TYPE.ARC, point+tangent_end.tangent()*(stroke_width*0.5), point, point+tangent_end*(stroke_width*0.5), point+tangent_end*(stroke_width*0.5)])
				return
			var tangent_mid : Vector2 = tangent_start+tangent_end
			if tangent_mid.length_squared() < 1.0:
				tangent_mid = (tangent_end-tangent_start).tangent()
			tangent_mid = tangent_mid.normalized()
			if is_zero_approx(curvature_start):
				var radius : float = -1.0/curvature_end-stroke_width*0.5
				var center : Vector2 = point+tangent_end*(stroke_width*0.5+radius)
				var expand : Vector2 = tangent_end
				if radius < 0:
					radius = -radius
					expand = -expand
				var line_start : Vector2 = point+tangent_start*stroke_width*0.5
				var line_dir : Vector2 = -tangent_start.tangent()
				var b : float = line_dir.dot(line_start-center)
				var c : float = line_start.distance_squared_to(center)-radius*radius
				var d : float
				if b*b < c:
					var a : float = expand.dot(line_dir)
					if is_zero_approx(a):
						_miter(dest, point, tangent_start, tangent_end, true)
						return
					a = a*a
					c = (b*b-c)/a
					b = (radius+expand.dot(line_start-center-b*line_dir))/a
					if b*b < c:
						_miter(dest, point, tangent_start, tangent_end, true)
						return
					d = sqrt(b*b-c)
					if d < b:
						_miter(dest, point, tangent_start, tangent_end, true)
						return
					if b+d > 0:
						d -= b
					else:
						d = -b-d
					center += d*expand
					radius += d
					b = line_dir.dot(line_start-center)
					d = 0
				else:
					d = sqrt(b*b-c)
				var intersection : Vector2 = line_start+((-b+d) if b+d > 0 else (-b-d))*line_dir
				var miter_clip : bool = false
				var miter_point : Vector2
				var miter_tangent : Vector2
				var miter_radius : float = tangent_mid.tangent().dot(intersection-point)
				if is_zero_approx(miter_radius):
					if intersection.distance_to(point) > miter_limit*stroke_width*0.5:
						miter_clip = true
						miter_point = point+miter_limit*stroke_width*0.5*tangent_mid
						miter_tangent = tangent_mid
				else:
					miter_radius = 0.5*point.distance_squared_to(intersection)/miter_radius
					var miter_center : Vector2 = point+tangent_mid.tangent()*miter_radius
					if abs(tangent_mid.tangent().angle_to(miter_center-intersection)*miter_radius) > miter_limit*stroke_width*0.5:
						miter_clip = true
						miter_point = miter_center-tangent_mid.tangent().rotated(-miter_limit*stroke_width*0.5/miter_radius)*miter_radius
						miter_tangent = tangent_mid.rotated(-miter_limit*stroke_width*0.5/miter_radius)
				if miter_clip:
					var intersection1 : Vector2 = intersection+miter_tangent.dot(miter_point-intersection)/miter_tangent.dot(point+tangent_start*stroke_width*0.5-intersection)*(point+tangent_start*stroke_width*0.5-intersection)
					b = -miter_tangent.tangent().dot(miter_point-center)
					c = radius*radius-miter_point.distance_squared_to(center)
					d = sqrt(b*b-c)
					var intersection2 : Vector2 = miter_point-miter_tangent.tangent()*((b+d) if b < d else (b-d))
					dest.append([SEGMENT_TYPE.LINEAR, intersection1])
					dest.append([SEGMENT_TYPE.LINEAR, intersection2])
					dest.append([SEGMENT_TYPE.ARC, center+tangent_end.tangent()*radius, center, point+tangent_end*stroke_width*0.5, point+tangent_end*stroke_width*0.5])
				else:
					dest.append([SEGMENT_TYPE.LINEAR, intersection])
					dest.append([SEGMENT_TYPE.ARC, center+tangent_end.tangent()*radius, center, point+tangent_end*stroke_width*0.5, point+tangent_end*stroke_width*0.5])
				return
			if is_zero_approx(curvature_end):
				var radius : float = -1.0/curvature_start-stroke_width*0.5
				var center : Vector2 = point+tangent_start*(stroke_width*0.5+radius)
				var expand : Vector2 = tangent_start
				if radius < 0:
					radius = -radius
					expand = -expand
				var line_start : Vector2 = point+tangent_end*stroke_width*0.5
				var line_dir : Vector2 = tangent_end.tangent()
				var b : float = line_dir.dot(line_start-center)
				var c : float = line_start.distance_squared_to(center)-radius*radius
				var d : float
				if b*b < c:
					var a : float = expand.dot(line_dir)
					if is_zero_approx(a):
						_miter(dest, point, tangent_start, tangent_end, true)
						return
					a = a*a
					c = (b*b-c)/a
					b = (radius+expand.dot(line_start-center-b*line_dir))/a
					if b*b < c:
						_miter(dest, point, tangent_start, tangent_end, true)
						return
					d = sqrt(b*b-c)
					if d < b:
						_miter(dest, point, tangent_start, tangent_end, true)
						return
					if b+d > 0:
						d -= b
					else:
						d = -b-d
					center += d*expand
					radius += d
					b = line_dir.dot(line_start-center)
					d = 0
				else:
					d = sqrt(b*b-c)
				var intersection : Vector2 = line_start+((-b+d) if b+d > 0 else (-b-d))*line_dir
				var miter_clip : bool = false
				var miter_point : Vector2
				var miter_tangent : Vector2
				var miter_radius : float = tangent_mid.tangent().dot(intersection-point)
				if is_zero_approx(miter_radius):
					if intersection.distance_to(point) > miter_limit*stroke_width*0.5:
						miter_clip = true
						miter_point = point+miter_limit*stroke_width*0.5*tangent_mid
						miter_tangent = tangent_mid
				else:
					miter_radius = 0.5*point.distance_squared_to(intersection)/miter_radius
					var miter_center : Vector2 = point+tangent_mid.tangent()*miter_radius
					if abs(tangent_mid.tangent().angle_to(miter_center-intersection)*miter_radius) > miter_limit*stroke_width*0.5:
						miter_clip = true
						miter_point = miter_center-tangent_mid.tangent().rotated(-miter_limit*stroke_width*0.5/miter_radius)*miter_radius
						miter_tangent = tangent_mid.rotated(-miter_limit*stroke_width*0.5/miter_radius)
				if miter_clip:
					b = miter_tangent.tangent().dot(miter_point-center)
					c = radius*radius-miter_point.distance_squared_to(center)
					d = sqrt(b*b-c)
					var intersection1 : Vector2 = miter_point+miter_tangent.tangent()*((b+d) if b < d else (b-d))
					var intersection2 : Vector2 = intersection+miter_tangent.dot(miter_point-intersection)/miter_tangent.dot(point+tangent_end*stroke_width*0.5-intersection)*(point+tangent_end*stroke_width*0.5-intersection)
					dest.append([SEGMENT_TYPE.ARC, center+tangent_start.tangent()*radius, center, point+tangent_start*stroke_width*0.5, intersection1])
					dest.append([SEGMENT_TYPE.LINEAR, intersection2])
					dest.append([SEGMENT_TYPE.LINEAR, point+tangent_end*stroke_width*0.5])
				else:
					dest.append([SEGMENT_TYPE.ARC, center+tangent_start.tangent()*radius, center, point+tangent_start*stroke_width*0.5, intersection])
					dest.append([SEGMENT_TYPE.LINEAR, point+tangent_end*stroke_width*0.5])
				return
			var radius1 : float = -1.0/curvature_start-stroke_width*0.5
			var center1 : Vector2 = point+tangent_start*(stroke_width*0.5+radius1)
			var expand1 : Vector2 = tangent_start
			if radius1 < 0:
				radius1 = -radius1
				expand1 = -expand1
			var radius2 : float = -1.0/curvature_end-stroke_width*0.5
			var center2 : Vector2 = point+tangent_end*(stroke_width*0.5+radius2)
			var expand2 : Vector2 = tangent_end
			if radius2 < 0:
				radius2 = -radius2
				expand2 = -expand2
			var intersection : Vector2
			if center1.distance_squared_to(center2) > (radius1+radius2)*(radius1+radius2):
				var a : float = expand1.distance_squared_to(expand2)-4
				var b : float = (center2-center1).dot(expand2-expand1)-2*(radius1+radius2)
				var c : float = center1.distance_squared_to(center2)-(radius1+radius2)*(radius1+radius2)
				var d : float
				if is_zero_approx(a):
					if is_zero_approx(b):
						_miter(dest, point, tangent_start, tangent_end, true)
						return
					d = -0.5*c/b
					if d < 0:
						_miter(dest, point, tangent_start, tangent_end, true)
						return
				else:
					b /= a
					c /= a
					if b*b < c:
						_miter(dest, point, tangent_start, tangent_end, true)
						return
					d = sqrt(b*b-c)
					if d < b:
						_miter(dest, point, tangent_start, tangent_end, true)
						return
					if b+d > 0:
						d -= b
					else:
						d = -b-d
				center1 += d*expand1
				radius1 += d
				center2 += d*expand2
				radius2 += d
				intersection = 0.5*(1+(radius1*radius1-radius2*radius2)/center1.distance_squared_to(center2))*(center2-center1)+center1
			elif center1.distance_squared_to(center2) < (radius1-radius2)*(radius1-radius2):
				if radius1 < radius2:
					var a : float = (expand1+expand2).length_squared()-4
					var b : float = (center1-center2).dot(expand1+expand2)+2*(radius2-radius1)
					var c : float = center1.distance_squared_to(center2)-(radius1-radius2)*(radius1-radius2)
					var d : float
					if is_zero_approx(a):
						if is_zero_approx(b):
							_miter(dest, point, tangent_start, tangent_end, true)
							return
						d = -0.5*c/b
						if d < 0:
							_miter(dest, point, tangent_start, tangent_end, true)
							return
					else:
						b /= a
						c /= a
						if b*b < c:
							_miter(dest, point, tangent_start, tangent_end, true)
							return
						d = sqrt(b*b-c)
						if d < b:
							_miter(dest, point, tangent_start, tangent_end, true)
							return
						if b+d > 0:
							d -= b
						else:
							d = -b-d
					center1 += d*expand1
					radius1 += d
					center2 -= d*expand2
					radius2 -= d
				else:
					var a : float = (expand1+expand2).length_squared()-4
					var b : float = (center2-center1).dot(expand1+expand2)+2*(radius1-radius2)
					var c : float = center1.distance_squared_to(center2)-(radius1-radius2)*(radius1-radius2)
					var d : float
					if is_zero_approx(a):
						if is_zero_approx(b):
							_miter(dest, point, tangent_start, tangent_end, true)
							return
						d = -0.5*c/b
						if d < 0:
							_miter(dest, point, tangent_start, tangent_end, true)
							return
					else:
						b /= a
						c /= a
						if b*b < c:
							_miter(dest, point, tangent_start, tangent_end, true)
							return
						d = sqrt(b*b-c)
						if d < b:
							_miter(dest, point, tangent_start, tangent_end, true)
							return
						if b+d > 0:
							d -= b
						else:
							d = -b-d
					center1 -= d*expand1
					radius1 -= d
					center2 += d*expand2
					radius2 += d
				intersection = 0.5*(1+(radius1*radius1-radius2*radius2)/center1.distance_squared_to(center2))*(center2-center1)+center1
			elif center1.is_equal_approx(center2):
				intersection = point+(tangent_start+tangent_end)*(stroke_width*0.25)
				if intersection.is_equal_approx(center1):
					intersection += tangent_start+tangent_end
				intersection = center1+(intersection-center1).normalized()*radius1
			else:
				var line_start : Vector2 = 0.5*(1+(radius1*radius1-radius2*radius2)/center1.distance_squared_to(center2))*(center2-center1)+center1
				var line_dir : Vector2 = (center2-line_start).tangent().normalized() if center1.is_equal_approx(line_start) else ((line_start-center1).tangent().normalized())
				var d : float = sqrt(radius1*radius1-line_start.distance_squared_to(center1))
				intersection = line_start+d*line_dir
				if tangent_end.tangent().dot(point+tangent_end*stroke_width*0.5-intersection) > 0:
					intersection = line_start-d*line_dir
				else:
					var intersection2 : Vector2 = line_start-d*line_dir
					if tangent_end.tangent().dot(point+tangent_end*stroke_width*0.5-intersection2) < 0 && intersection2.distance_squared_to(point+tangent_end*stroke_width*0.5) < intersection.distance_squared_to(point+tangent_end*stroke_width*0.5):
						intersection = intersection2
			var miter_clip : bool = false
			var miter_point : Vector2
			var miter_tangent : Vector2
			var miter_radius : float = tangent_mid.tangent().dot(intersection-point)
			if is_zero_approx(miter_radius):
				if intersection.distance_to(point) > miter_limit*stroke_width*0.5:
					miter_clip = true
					miter_point = point+miter_limit*stroke_width*0.5*tangent_mid
					miter_tangent = tangent_mid
			else:
				miter_radius = 0.5*point.distance_squared_to(intersection)/miter_radius
				var miter_center : Vector2 = point+tangent_mid.tangent()*miter_radius
				if abs(tangent_mid.tangent().angle_to(miter_center-intersection)*miter_radius) > miter_limit*stroke_width*0.5:
					miter_clip = true
					miter_point = miter_center-tangent_mid.tangent().rotated(-miter_limit*stroke_width*0.5/miter_radius)*miter_radius
					miter_tangent = tangent_mid.rotated(-miter_limit*stroke_width*0.5/miter_radius)
			if miter_clip:
				var b : float = miter_tangent.tangent().dot(miter_point-center1)
				var c : float = radius1*radius1-miter_point.distance_squared_to(center1)
				var d : float = sqrt(b*b-c)
				var intersection1 : Vector2 = miter_point+miter_tangent.tangent()*((b+d) if b < d else (b-d))
				b = -miter_tangent.tangent().dot(miter_point-center2)
				c = radius2*radius2-miter_point.distance_squared_to(center2)
				d = sqrt(b*b-c)
				var intersection2 : Vector2 = miter_point-miter_tangent.tangent()*((b+d) if b < d else (b-d))
				dest.append([SEGMENT_TYPE.ARC, center1+tangent_start.tangent()*(radius1 if tangent_start.tangent().dot(intersection1-center1) < 0 else -radius1), center1, point+tangent_start*stroke_width*0.5, intersection1])
				dest.append([SEGMENT_TYPE.LINEAR, intersection2])
				dest.append([SEGMENT_TYPE.ARC, center2+tangent_end.tangent()*(radius2 if tangent_end.tangent().dot(center2-intersection2) < 0 else -radius2), center2, point+tangent_end*stroke_width*0.5, point+tangent_end*stroke_width*0.5])
			else:
				dest.append([SEGMENT_TYPE.ARC, center1+tangent_start.tangent()*(radius1 if tangent_start.tangent().dot(intersection-center1) < 0 else -radius1), center1, point+tangent_start*stroke_width*0.5, intersection])
				dest.append([SEGMENT_TYPE.ARC, center2+tangent_end.tangent()*(radius2 if tangent_end.tangent().dot(center2-intersection) < 0 else -radius2), center2, point+tangent_end*stroke_width*0.5, point+tangent_end*stroke_width*0.5])
		2:
			_miter(dest, point, tangent_start, tangent_end, false)
		3:
			_miter(dest, point, tangent_start, tangent_end, true)
		4:
			dest.append([SEGMENT_TYPE.ARC, point+tangent_end.tangent()*(stroke_width*0.5), point, point+tangent_end*(stroke_width*0.5), point+tangent_end*(stroke_width*0.5)])
		_:
			dest.append([SEGMENT_TYPE.LINEAR, point+tangent_end*(stroke_width*0.5)])

func _miter(dest : Array, point : Vector2, tangent_start : Vector2, tangent_end : Vector2, clip : bool) -> void:
		var tangent_mid : Vector2 = tangent_start+tangent_end
		if tangent_mid.length_squared() < 1.0:
			tangent_mid = (tangent_end-tangent_start).tangent()
		tangent_mid = tangent_mid.normalized()
		var det : float = tangent_mid.dot(tangent_start)
		if miter_limit*det >= 1:
			dest.append([SEGMENT_TYPE.LINEAR, point+tangent_mid*(stroke_width*0.5/det)])
			dest.append([SEGMENT_TYPE.LINEAR, point+tangent_end*(stroke_width*0.5)])
		elif !clip:
			dest.append([SEGMENT_TYPE.LINEAR, point+tangent_end*(stroke_width*0.5)])
		else:
			det = (miter_limit-tangent_start.dot(tangent_mid))/tangent_start.tangent().dot(tangent_mid)
			dest.append([SEGMENT_TYPE.LINEAR, point+(tangent_start+tangent_start.tangent()*det)*stroke_width*0.5])
			dest.append([SEGMENT_TYPE.LINEAR, point+(tangent_end-tangent_end.tangent()*det)*stroke_width*0.5])
			dest.append([SEGMENT_TYPE.LINEAR, point+tangent_end*(stroke_width*0.5)])

func _reverse_segments(subpath : Array) -> Array:
	var dest : Array = [[SEGMENT_TYPE.START, _get_last_point(subpath[subpath.size()-1]), subpath[0][2]]]
	var i : int = subpath.size()-1
	while i > 0:
		var pos : Vector2 = _get_last_point(subpath[i-1])
		match subpath[i][0]:
			SEGMENT_TYPE.LINEAR:
				dest.append([SEGMENT_TYPE.LINEAR, pos])
			SEGMENT_TYPE.QUADRIC:
				dest.append([SEGMENT_TYPE.QUADRIC, subpath[i][1], pos])
			SEGMENT_TYPE.CUBIC:
				dest.append([SEGMENT_TYPE.CUBIC, subpath[i][2], subpath[i][1], pos])
			SEGMENT_TYPE.ARC:
				dest.append([SEGMENT_TYPE.ARC, subpath[i][3], subpath[i][2], subpath[i][1], pos])
		i -= 1
	return dest

func _get_last_point(segment : Array) -> Vector2:
	match segment[0]:
		SEGMENT_TYPE.QUADRIC:
			return segment[2]
		SEGMENT_TYPE.CUBIC:
			return segment[3]
		SEGMENT_TYPE.ARC:
			return segment[4]
		_:
			return segment[1]
