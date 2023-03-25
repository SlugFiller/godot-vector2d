@tool
extends EditorPlugin

const SEGMENT_TYPE = Vector2DShapeSource.SEGMENT_TYPE
const COLOR_CONTROL_POINT = Color(0, 0.5, 1)
const COLOR_INTERSECTION_POINT = Color(1, 1, 1)
const COLOR_CREATE_POINT = Color(0, 1, 0)
const COLOR_POINT_OUTLINE = Color(0, 0, 0)
const COLOR_POINT_OUTLINE_SELECTED = Color(1, 0.5, 0)
const COLOR_LINE = Color(0.5, 0.6, 1.0, 0.7)
const WIDTH_LINE = 2
const RADIUS_POINT = 4
const RADIUS_POINT_OUTLINE = 5
const RADIUS_POINT_OUTLINE_SELECTED = 5
const HOVER_TEXT_SHIFT = Vector2(5, -5)
const HOVER_COLOR = Color(1.0, 1.0, 1.0, 0.5)
const HOVER_RANGE = 5
const HOVER_MAX_TRAVEL = 5.0
const CLICK_MAX_TRAVEL = 5.0
const INTERPOLATE_PERCISION = 0.5
var toolbar : HBoxContainer = null
var editing : Object = null
var editing_readonly : bool = true
var selection : Dictionary = {}
var hover_index : int = 0
var hover_type : int = 0
var hover_travel : float = 0
var hover_last_point : Vector2 = Vector2()
var click_index : int = 0
var click_type : int = 0
var click_point : Vector2 = Vector2()
var click_release_type : int = 0
var click_drag : Vector2 = Vector2()
var click_create : Vector2 = Vector2()
var click_dragging : bool = false
var snap_first_time : bool = true
var snap_on : bool = false
var snap_offset : Vector2 = Vector2.ZERO
var snap_step : Vector2 = Vector2.ONE
var button_select : Button
var button_start : Button
var button_line : Button
var button_quad : Button
var button_cube : Button
var button_arc : Button
var button_delete : Button
var mode : int = 0
var importer : EditorImportPlugin

func _enter_tree() -> void:
	importer = preload("res://addons/vector2d/svg.gd").new()
	add_custom_type("Vector2DShape", "Node2D", Vector2DShape, preload("vector2d.svg"))
	add_custom_type("Vector2DFill", "Node2D", Vector2DFill, preload("vector2d.svg"))
	add_custom_type("Vector2DStroke", "Node2D", Vector2DStroke, preload("vector2d.svg"))
	add_import_plugin(importer)
	toolbar = HBoxContainer.new()
	toolbar.add_child(VSeparator.new())
	button_select = Button.new()
	button_select.focus_mode = Control.FOCUS_NONE
	button_select.tooltip_text = "Select object";
	button_select.icon = preload("btn_select.svg")
	button_select.toggle_mode = true
	button_select.flat = true
	button_select.pressed.connect(Callable(self, "set_mode").bind(0))
	toolbar.add_child(button_select)
	button_start = Button.new()
	button_start.focus_mode = Control.FOCUS_NONE
	button_start.tooltip_text = "Start new path";
	button_start.icon = preload("btn_start.svg")
	button_start.toggle_mode = true
	button_start.flat = true
	button_start.pressed.connect(Callable(self, "set_mode").bind(1))
	toolbar.add_child(button_start)
	button_line = Button.new()
	button_line.focus_mode = Control.FOCUS_NONE
	button_line.tooltip_text = "Continue path with line";
	button_line.icon = preload("btn_line.svg")
	button_line.toggle_mode = true
	button_line.flat = true
	button_line.pressed.connect(Callable(self, "set_mode").bind(2))
	toolbar.add_child(button_line)
	button_quad = Button.new()
	button_quad.focus_mode = Control.FOCUS_NONE
	button_quad.tooltip_text = "Continue path with quadric curve";
	button_quad.icon = preload("btn_quad.svg")
	button_quad.toggle_mode = true
	button_quad.flat = true
	button_quad.pressed.connect(Callable(self, "set_mode").bind(3))
	toolbar.add_child(button_quad)
	button_cube = Button.new()
	button_cube.focus_mode = Control.FOCUS_NONE
	button_cube.tooltip_text = "Continue path with cubic curve";
	button_cube.icon = preload("btn_cube.svg")
	button_cube.toggle_mode = true
	button_cube.flat = true
	button_cube.pressed.connect(Callable(self, "set_mode").bind(4))
	toolbar.add_child(button_cube)
	button_arc = Button.new()
	button_arc.focus_mode = Control.FOCUS_NONE
	button_arc.tooltip_text = "Continue path with arc";
	button_arc.icon = preload("btn_arc.svg")
	button_arc.toggle_mode = true
	button_arc.flat = true
	button_arc.pressed.connect(Callable(self, "set_mode").bind(5))
	toolbar.add_child(button_arc)
	button_delete = Button.new()
	button_delete.focus_mode = Control.FOCUS_NONE
	button_delete.tooltip_text = "Delete selected segments";
	button_delete.icon = preload("btn_delete.svg")
	button_delete.toggle_mode = false
	button_delete.flat = true
	button_delete.pressed.connect(Callable(self, "delete_selected"))
	toolbar.add_child(button_delete)
	toolbar.visible = false
	set_mode(0)
	update_buttons()
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, toolbar)

func _exit_tree() -> void:
	if importer:
		remove_import_plugin(importer)
		importer = null
	if toolbar:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, toolbar)
		toolbar = null
	remove_custom_type("Vector2DShape")
	remove_custom_type("Vector2DFill")

func _handles(object: Object) -> bool:
	if object is Vector2DShapeSource:
		return true
	return false

func _edit(object: Object) -> void:
	if !is_instance_valid(editing) || !editing.is_inside_tree():
		editing = null
	if editing && editing.visibility_changed.is_connected(Callable(self, "_node_changed")):
		editing.visibility_changed.disconnect(Callable(self, "_node_changed"))
	if editing && editing.shape_changed.is_connected(Callable(self, "_node_changed")):
		editing.shape_changed.disconnect(Callable(self, "_node_changed"))
	selection = {}
	hover_index = 0
	hover_type = 0
	click_release_type = 0
	click_drag = Vector2()
	click_create = Vector2()
	editing = object
	editing_readonly = !editing || !(editing is Vector2DShape)
	if editing && !editing.visibility_changed.is_connected(Callable(self, "_node_changed")):
		editing.visibility_changed.connect(Callable(self, "_node_changed"))
	if editing && !editing.shape_changed.is_connected(Callable(self, "_node_changed")):
		editing.shape_changed.connect(Callable(self, "_node_changed"))
	reload_snap_settings()
	update_buttons()
	update_overlays()

func _make_visible(visible: bool) -> void:
	if toolbar:
		toolbar.visible = visible
	if visible:
		get_editor_interface().set_main_screen_editor("2D")
		update_overlays()

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if editing && (!is_instance_valid(editing) || !editing.is_inside_tree()):
		editing = null
		update_overlays()
		update_buttons()
	if !editing:
		return false
	var segments : Array = editing.get_shape()
	var canvas : Transform2D = get_canvas_transform()
	if event is InputEventMouseMotion:
		var point : Vector2 = (event as InputEventMouseMotion).position
		if click_release_type:
			if !click_dragging:
				if (point-click_point).length() < CLICK_MAX_TRAVEL:
					return true
				click_dragging = true
			if click_release_type == 4:
				click_create = point
				snap_create()
			else:
				click_drag = point-click_point
				snap_drag()
			update_overlays()
			return true
		if is_point_in_range(segments, point, canvas, hover_index, hover_type):
			hover_travel += (point-hover_last_point).length()
			hover_last_point = point
			if hover_travel < HOVER_MAX_TRAVEL:
				return false
		hover_travel = 0.0
		hover_last_point = point
		var cur_index : int = hover_index
		var cur_type : int = hover_type
		while true:
			cur_type += 1
			if cur_type > 4:
				cur_index += 1
				cur_type = 1
			if cur_index >= segments.size():
				break
			if is_point_in_range(segments, point, canvas, cur_index, cur_type):
				hover_index = cur_index
				hover_type = cur_type
				update_overlays()
				return false
		cur_index = 0
		cur_type = 0
		while true:
			cur_type += 1
			if cur_type > 4:
				cur_index += 1
				cur_type = 1
			if cur_index >= hover_index && cur_type >= hover_type:
				break
			if is_point_in_range(segments, point, canvas, cur_index, cur_type):
				hover_index = cur_index
				hover_type = cur_type
				update_overlays()
				return false
		if hover_type != 0 && !is_point_in_range(segments, point, canvas, hover_index, hover_type):
			hover_index = 0
			hover_type = 0
			update_overlays()
		return false
	if !editing_readonly && event is InputEventMouseButton:
		var point : Vector2 = (event as InputEventMouseButton).position
		if (event as InputEventMouseButton).button_index != 1:
			return false
		hover_travel = 0.0
		hover_last_point = point
		if (event as InputEventMouseButton).is_pressed():
			update_overlays()
			click_point = point
			click_drag = Vector2()
			click_dragging = false
			click_index = hover_index
			click_type = hover_type
			if !is_point_in_range(segments, point, canvas, click_index, click_type):
				click_index = 0
				click_type = 0
				hover_index = 0
				hover_type = 0
				while true:
					click_type += 1
					if click_type > 4:
						click_index += 1
						click_type = 1
					if click_index >= segments.size():
						break
					if is_point_in_range(segments, point, canvas, click_index, click_type):
						break
				if click_index >= segments.size():
					click_index = 0
					click_type = 0
			if click_type == 0:
				if mode != 0:
					click_dragging = true
					click_create = point
					click_release_type = 4
					snap_create()
					return true
				click_release_type = 0
				return false
			if !click_index in selection || !(click_type-1) in selection[click_index]:
				if !(event as InputEventMouseButton).shift_pressed:
					selection = {}
				if !click_index in selection:
					selection[click_index] = {}
				selection[click_index][click_type-1] = true
				click_release_type = 3
			else:
				click_release_type = 2 if (event as InputEventMouseButton).shift_pressed else 1
			update_buttons()
			return true
		else:
			var ret : bool = !!click_release_type
			if !click_dragging:
				match click_release_type:
					1:
						selection = {}
						if !click_index in selection:
							selection[click_index] = {}
						selection[click_index][click_type-1] = true
						update_overlays()
					2:
						if click_index in selection && (click_type-1) in selection[click_index]:
							selection[click_index].erase(click_type-1)
						update_overlays()
			elif click_release_type == 4:
				click_dragging = false
				click_create = point
				snap_create()
				apply_create()
			elif click_release_type:
				click_dragging = false
				click_drag = point-click_point
				snap_drag()
				apply_drag()
			click_release_type = 0
			click_index = 0
			click_type = 0
			click_drag = Vector2()
			click_create = Vector2()
			update_overlays()
			update_buttons()
			return ret
	return false

func try_optimize_polyline(overlay : Control, edscale : float, line : Array, rect : Rect2, points : Array) -> bool:
	var in_x_min : bool = false
	var in_x_max : bool = false
	var in_y_min : bool = false
	var in_y_max : bool = false
	for point in points:
		if point.x >= rect.position.x:
			in_x_min = true
		if point.x <= rect.end.x:
			in_x_max = true
		if point.y >= rect.position.x:
			in_y_min = true
		if point.y <= rect.end.x:
			in_y_max = true
	if line.size() > 0:
		var point : Vector2 = line[line.size()-1]
		if point.x >= rect.position.x:
			in_x_min = true
		if point.x <= rect.end.x:
			in_x_max = true
		if point.y >= rect.position.x:
			in_y_min = true
		if point.y <= rect.end.x:
			in_y_max = true
	if in_x_min && in_x_max && in_y_min && in_y_max:
		return false
	if line.size() > 1:
		var offset : int = 0
		while line.size() > offset+8192:
			overlay.draw_polyline(PackedVector2Array(line.slice(offset, offset+8192)), COLOR_LINE, WIDTH_LINE, true)
			offset += 8192
		if line.size() > offset+1:
			overlay.draw_polyline(PackedVector2Array(line.slice(offset, line.size())), COLOR_LINE, WIDTH_LINE, true)
	line.resize(0)
	return true

func interpolate_quadric(overlay : Control, edscale : float, line : Array, rect : Rect2, start : Vector2, c : Vector2, end : Vector2) -> void:
	if try_optimize_polyline(overlay, edscale, line, rect, [start, c, end]) || (start-c).length()+(c-end).length() < INTERPOLATE_PERCISION:
		line.append(end)
		return
	var a1 : Vector2 = 0.5*(start+c)
	var a2 : Vector2 = 0.5*(c+end)
	var b : Vector2 = 0.5*(a1+a2)
	interpolate_quadric(overlay, edscale, line, rect, start, a1, b)
	interpolate_quadric(overlay, edscale, line, rect, b, a2, end)

func interpolate_cubic(overlay : Control, edscale : float, line : Array, rect : Rect2, start : Vector2, c1 : Vector2, c2 : Vector2, end : Vector2) -> void:
	if try_optimize_polyline(overlay, edscale, line, rect, [start, c1, c2, end]) || (start-c1).length()+(c1-c2).length()+(c2-end).length() < INTERPOLATE_PERCISION:
		line.append(end)
		return
	var a1 : Vector2 = 0.5*(start+c1)
	var a2 : Vector2 = 0.5*(c1+c2)
	var a3 : Vector2 = 0.5*(c2+end)
	var b1 : Vector2 = 0.5*(a1+a2)
	var b2 : Vector2 = 0.5*(a2+a3)
	var c : Vector2 = 0.5*(b1+b2)
	interpolate_cubic(overlay, edscale, line, rect, start, a1, b1, c)
	interpolate_cubic(overlay, edscale, line, rect, c, b2, a3, end)

func interpolate_arc(overlay : Control, edscale : float, line : Array, rect : Rect2, start : Vector2, c : Vector2, r1 : Vector2, r2 : Vector2, end : Vector2) -> void:
	if try_optimize_polyline(overlay, edscale, line, rect, [c+start.x*r1+start.y*r2, c+end.x*r1+start.y*r2, c+start.x*r1+end.y*r2, c+end.x*r1+end.y*r2]) || (start-end).length()*(1.0+r1.length()+r2.length()) < INTERPOLATE_PERCISION:
		line.append(c+end.x*r1+end.y*r2)
		return
	var m : Vector2 = (start+end).normalized()
	interpolate_arc(overlay, edscale, line, rect, start, c, r1, r2, m)
	interpolate_arc(overlay, edscale, line, rect, m, c, r1, r2, end)

func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
	if editing && (!is_instance_valid(editing) || !editing.is_inside_tree()):
		editing = null
		update_buttons()
	if !editing:
		return
	var canvas : Transform2D = get_canvas_transform()
	var edscale : float = canvas.basis_xform(Vector2(1, 0)).x
	var canvas_rect : Rect2 = Rect2(Vector2(), get_canvas_size()).grow(10.0*(abs(edscale)+1.0))
	var position : Vector2 = Vector2()
	var start : Vector2 = Vector2()
	var should_close : bool = false
	var line : Array = []
	var index : int = 0
	for segment in editing.get_shape():
		var point_selected : bool = false
		match segment[0]:
			SEGMENT_TYPE.START:
				var pos : Vector2 = canvas*(segment[1])
				if index in selection && 0 in selection[index]:
					pos += click_drag
					point_selected = true
				if should_close && !position.is_equal_approx(start):
					line.append(start)
				should_close = false
				if line.size() > 1:
					while line.size() > 8192:
						viewport_control.draw_polyline(PackedVector2Array(line.slice(0, 8192)), COLOR_LINE, WIDTH_LINE, true)
						line = line.slice(8192, line.size())
					viewport_control.draw_polyline(PackedVector2Array(line), COLOR_LINE, WIDTH_LINE, true)
				line.resize(0)
				line.append(pos)
				position = pos
				start = pos
				if segment[2] & 1:
					should_close = true
			SEGMENT_TYPE.LINEAR:
				var pos : Vector2 = canvas*(segment[1])
				if index in selection && 0 in selection[index]:
					pos += click_drag
					point_selected = true
				try_optimize_polyline(viewport_control, edscale, line, canvas_rect, [pos])
				line.append(pos)
				position = pos
			SEGMENT_TYPE.QUADRIC:
				var c : Vector2 = canvas*(segment[1])
				var pos : Vector2 = canvas*(segment[2])
				if index in selection && 0 in selection[index]:
					c += click_drag
				if index in selection && 1 in selection[index]:
					pos += click_drag
					point_selected = true
				interpolate_quadric(viewport_control, edscale, line, canvas_rect, position, c, pos)
				position = pos
			SEGMENT_TYPE.CUBIC:
				var c1 : Vector2 = canvas*(segment[1])
				var c2 : Vector2 = canvas*(segment[2])
				var pos : Vector2 = canvas*(segment[3])
				if index in selection && 0 in selection[index]:
					c1 += click_drag
				if index in selection && 1 in selection[index]:
					c2 += click_drag
				if index in selection && 2 in selection[index]:
					pos += click_drag
					point_selected = true
				interpolate_cubic(viewport_control, edscale, line, canvas_rect, position, c1, c2, pos)
				position = pos
			SEGMENT_TYPE.ARC:
				var c : Vector2 = canvas*(segment[2])
				if index in selection && 1 in selection[index]:
					c += click_drag
				var r1 : Vector2 = canvas*(segment[1])-c
				var r2 : Vector2 = canvas*(segment[3])-c
				var pos : Vector2 = canvas*(segment[4])
				if index in selection && 0 in selection[index]:
					r1 += click_drag
				if index in selection && 2 in selection[index]:
					r2 += click_drag
				if index in selection && 3 in selection[index]:
					pos += click_drag
					point_selected = true
				var axis : Transform2D = Transform2D(r1, r2, Vector2()).affine_inverse()
				var a1 : float = axis.basis_xform(position-c).angle()
				var a2 : float = axis.basis_xform(pos-c).angle()
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
				if a3 < a2:
					interpolate_arc(viewport_control, edscale, line, canvas_rect, Vector2(1, 0).rotated(a1), c, r1, r2, Vector2(1, 0).rotated(a3))
					while a3+0.5*PI < a2:
						interpolate_arc(viewport_control, edscale, line, canvas_rect, Vector2(1, 0).rotated(a3), c, r1, r2, Vector2(1, 0).rotated(a3+0.5*PI))
						a3 += 0.5*PI
					interpolate_arc(viewport_control, edscale, line, canvas_rect, Vector2(1, 0).rotated(a3), c, r1, r2, Vector2(1, 0).rotated(a2))
				else:
					interpolate_arc(viewport_control, edscale, line, canvas_rect, Vector2(1, 0).rotated(a1), c, r1, r2, Vector2(1, 0).rotated(a2))
				try_optimize_polyline(viewport_control, edscale, line, canvas_rect, [pos])
				line.append(pos)
				position = pos
		if click_release_type == 4 && point_selected:
			if mode == 1:
				if line.size() > 1:
					while line.size() > 8192:
						viewport_control.draw_polyline(PackedVector2Array(line.slice(0, 8192)), COLOR_LINE, WIDTH_LINE, true)
						line = line.slice(8192, line.size())
					viewport_control.draw_polyline(PackedVector2Array(line), COLOR_LINE, WIDTH_LINE, true)
				line.resize(0)
				line.append(click_create)
				position = click_create
			elif mode == 5:
				var c = 0.5*(position+click_create)
				var r = 0.5*(position-click_create)
				interpolate_arc(viewport_control, edscale, line, canvas_rect, Vector2(1, 0), c, r, -r.orthogonal(), Vector2(0, 1))
				interpolate_arc(viewport_control, edscale, line, canvas_rect, Vector2(0, 1), c, r, -r.orthogonal(), Vector2(-1, 0))
				position = click_create
			else:
				try_optimize_polyline(viewport_control, edscale, line, canvas_rect, [click_create])
				line.append(click_create)
				position = click_create
		index += 1
	if should_close && !position.is_equal_approx(start):
		line.append(start)
	if line.size() > 1:
		while line.size() > 8192:
			viewport_control.draw_polyline(PackedVector2Array(line.slice(0, 8192)), COLOR_LINE, WIDTH_LINE, true)
			line = line.slice(8192, line.size())
		viewport_control.draw_polyline(PackedVector2Array(line), COLOR_LINE, WIDTH_LINE, true)
	index = 0
	for segment in editing.get_shape():
		var point_selected : bool = false
		var pos : Vector2
		match segment[0]:
			SEGMENT_TYPE.START:
				pos = canvas*(segment[1])
				if index in selection && 0 in selection[index]:
					pos += click_drag
					point_selected = true
					viewport_control.draw_circle(pos, RADIUS_POINT_OUTLINE_SELECTED, COLOR_POINT_OUTLINE_SELECTED)
				else:
					viewport_control.draw_circle(pos, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
				viewport_control.draw_circle(pos, RADIUS_POINT, COLOR_INTERSECTION_POINT)
				if index == hover_index && 1 == hover_type:
					viewport_control.draw_string(viewport_control.get_theme_font("font", "Label"), pos+HOVER_TEXT_SHIFT, str(index)+" Start", 0, -1, viewport_control.get_theme_font_size("font", "Label"), HOVER_COLOR)
			SEGMENT_TYPE.LINEAR:
				pos = canvas*(segment[1])
				if index in selection && 0 in selection[index]:
					pos += click_drag
					point_selected = true
					viewport_control.draw_circle(pos, RADIUS_POINT_OUTLINE_SELECTED, COLOR_POINT_OUTLINE_SELECTED)
				else:
					viewport_control.draw_circle(pos, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
				viewport_control.draw_circle(pos, RADIUS_POINT, COLOR_INTERSECTION_POINT)
				if index == hover_index && 1 == hover_type:
					viewport_control.draw_string(viewport_control.get_theme_font("font", "Label"), pos+HOVER_TEXT_SHIFT, str(index)+" Linear End", 0, -1, viewport_control.get_theme_font_size("font", "Label"), HOVER_COLOR)
			SEGMENT_TYPE.QUADRIC:
				var c : Vector2 = canvas*(segment[1])
				pos = canvas*(segment[2])
				if index in selection && 0 in selection[index]:
					c += click_drag
					viewport_control.draw_circle(c, RADIUS_POINT_OUTLINE_SELECTED, COLOR_POINT_OUTLINE_SELECTED)
				else:
					viewport_control.draw_circle(c, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
				viewport_control.draw_circle(c, RADIUS_POINT, COLOR_CONTROL_POINT)
				if index == hover_index && 1 == hover_type:
					viewport_control.draw_string(viewport_control.get_theme_font("font", "Label"), c+HOVER_TEXT_SHIFT, str(index)+" Quadric Control", 0, -1, viewport_control.get_theme_font_size("font", "Label"), HOVER_COLOR)
				if index in selection && 1 in selection[index]:
					pos += click_drag
					point_selected = true
					viewport_control.draw_circle(pos, RADIUS_POINT_OUTLINE_SELECTED, COLOR_POINT_OUTLINE_SELECTED)
				else:
					viewport_control.draw_circle(pos, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
				viewport_control.draw_circle(pos, RADIUS_POINT, COLOR_INTERSECTION_POINT)
				if index == hover_index && 2 == hover_type:
					viewport_control.draw_string(viewport_control.get_theme_font("font", "Label"), pos+HOVER_TEXT_SHIFT, str(index)+" Quadric End", 0, -1, viewport_control.get_theme_font_size("font", "Label"), HOVER_COLOR)
			SEGMENT_TYPE.CUBIC:
				var c1 : Vector2 = canvas*(segment[1])
				var c2 : Vector2 = canvas*(segment[2])
				pos = canvas*(segment[3])
				if index in selection && 0 in selection[index]:
					c1 += click_drag
					viewport_control.draw_circle(c1, RADIUS_POINT_OUTLINE_SELECTED, COLOR_POINT_OUTLINE_SELECTED)
				else:
					viewport_control.draw_circle(c1, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
				viewport_control.draw_circle(c1, RADIUS_POINT, COLOR_CONTROL_POINT)
				if index == hover_index && 1 == hover_type:
					viewport_control.draw_string(viewport_control.get_theme_font("font", "Label"), c1+HOVER_TEXT_SHIFT, str(index)+" Cubic Control 1", 0, -1, viewport_control.get_theme_font_size("font", "Label"), HOVER_COLOR)
				if index in selection && 1 in selection[index]:
					c2 += click_drag
					viewport_control.draw_circle(c2, RADIUS_POINT_OUTLINE_SELECTED, COLOR_POINT_OUTLINE_SELECTED)
				else:
					viewport_control.draw_circle(c2, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
				viewport_control.draw_circle(c2, RADIUS_POINT, COLOR_CONTROL_POINT)
				if index == hover_index && 2 == hover_type:
					viewport_control.draw_string(viewport_control.get_theme_font("font", "Label"), c2+HOVER_TEXT_SHIFT, str(index)+" Cubic Control 2", 0, -1, viewport_control.get_theme_font_size("font", "Label"), HOVER_COLOR)
				if index in selection && 2 in selection[index]:
					pos += click_drag
					point_selected = true
					viewport_control.draw_circle(pos, RADIUS_POINT_OUTLINE_SELECTED, COLOR_POINT_OUTLINE_SELECTED)
				else:
					viewport_control.draw_circle(pos, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
				viewport_control.draw_circle(pos, RADIUS_POINT, COLOR_INTERSECTION_POINT)
				if index == hover_index && 3 == hover_type:
					viewport_control.draw_string(viewport_control.get_theme_font("font", "Label"), pos+HOVER_TEXT_SHIFT, str(index)+" Cubic End", 0, -1, viewport_control.get_theme_font_size("font", "Label"), HOVER_COLOR)
			SEGMENT_TYPE.ARC:
				var a1 : Vector2 = canvas*(segment[1])
				var c : Vector2 = canvas*(segment[2])
				var a2 : Vector2 = canvas*(segment[3])
				pos = canvas*(segment[4])
				if index in selection && 0 in selection[index]:
					a1 += click_drag
					viewport_control.draw_circle(a1, RADIUS_POINT_OUTLINE_SELECTED, COLOR_POINT_OUTLINE_SELECTED)
				else:
					viewport_control.draw_circle(a1, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
				viewport_control.draw_circle(a1, RADIUS_POINT, COLOR_CONTROL_POINT)
				if index == hover_index && 1 == hover_type:
					viewport_control.draw_string(viewport_control.get_theme_font("font", "Label"), a1+HOVER_TEXT_SHIFT, str(index)+" Arc Axis 1", 0, -1, viewport_control.get_theme_font_size("font", "Label"), HOVER_COLOR)
				if index in selection && 1 in selection[index]:
					c += click_drag
					viewport_control.draw_circle(c, RADIUS_POINT_OUTLINE_SELECTED, COLOR_POINT_OUTLINE_SELECTED)
				else:
					viewport_control.draw_circle(c, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
				viewport_control.draw_circle(c, RADIUS_POINT, COLOR_CONTROL_POINT)
				if index == hover_index && 2 == hover_type:
					viewport_control.draw_string(viewport_control.get_theme_font("font", "Label"), c+HOVER_TEXT_SHIFT, str(index)+" Arc Center", 0, -1, viewport_control.get_theme_font_size("font", "Label"), HOVER_COLOR)
				if index in selection && 2 in selection[index]:
					a2 += click_drag
					viewport_control.draw_circle(a2, RADIUS_POINT_OUTLINE_SELECTED, COLOR_POINT_OUTLINE_SELECTED)
				else:
					viewport_control.draw_circle(a2, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
				viewport_control.draw_circle(a2, RADIUS_POINT, COLOR_CONTROL_POINT)
				if index == hover_index && 3 == hover_type:
					viewport_control.draw_string(viewport_control.get_theme_font("font", "Label"), a2+HOVER_TEXT_SHIFT, str(index)+" Arc Axis 2", 0, -1, viewport_control.get_theme_font_size("font", "Label"), HOVER_COLOR)
				if index in selection && 3 in selection[index]:
					pos += click_drag
					point_selected = true
					viewport_control.draw_circle(pos, RADIUS_POINT_OUTLINE_SELECTED, COLOR_POINT_OUTLINE_SELECTED)
				else:
					viewport_control.draw_circle(pos, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
				viewport_control.draw_circle(pos, RADIUS_POINT, COLOR_INTERSECTION_POINT)
				if index == hover_index && 4 == hover_type:
					viewport_control.draw_string(viewport_control.get_theme_font("font", "Label"), pos+HOVER_TEXT_SHIFT, str(index)+" Arc End", 0, -1, viewport_control.get_theme_font_size("font", "Label"), HOVER_COLOR)
		if click_release_type == 4 && point_selected:
			match mode:
				3:
					var c : Vector2 = 0.5*(pos+click_create)
					viewport_control.draw_circle(c, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
					viewport_control.draw_circle(c, RADIUS_POINT, COLOR_CONTROL_POINT)
				4:
					var c1 : Vector2 = (2.0/3.0)*pos+(1.0/3.0)*click_create
					var c2 : Vector2 = (1.0/3.0)*pos+(2.0/3.0)*click_create
					viewport_control.draw_circle(c1, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
					viewport_control.draw_circle(c1, RADIUS_POINT, COLOR_CONTROL_POINT)
					viewport_control.draw_circle(c2, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
					viewport_control.draw_circle(c2, RADIUS_POINT, COLOR_CONTROL_POINT)
				5:
					var c : Vector2 = 0.5*(pos+click_create)
					var a : Vector2 = (click_create-pos).orthogonal()*0.5+c
					viewport_control.draw_circle(c, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
					viewport_control.draw_circle(c, RADIUS_POINT, COLOR_CONTROL_POINT)
					viewport_control.draw_circle(a, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
					viewport_control.draw_circle(a, RADIUS_POINT, COLOR_CONTROL_POINT)
					viewport_control.draw_circle(click_create, RADIUS_POINT_OUTLINE, COLOR_POINT_OUTLINE)
					viewport_control.draw_circle(click_create, RADIUS_POINT, COLOR_CONTROL_POINT)
		index += 1
	if click_release_type == 4:
		viewport_control.draw_circle(click_create, RADIUS_POINT_OUTLINE_SELECTED, COLOR_POINT_OUTLINE_SELECTED)
		viewport_control.draw_circle(click_create, RADIUS_POINT, COLOR_CREATE_POINT)

func _node_changed():
	if !editing:
		return
	if !is_instance_valid(editing) || !editing.is_inside_tree():
		editing = null
		update_buttons()
	update_overlays()

func get_canvas_size() -> Vector2:
	return get_editor_interface().get_edited_scene_root().get_parent().size

func get_canvas_transform(with_object : bool = true) -> Transform2D:
	return get_editor_interface().get_edited_scene_root().get_parent().get_global_canvas_transform()*(editing.get_global_transform() if with_object else Transform2D())

func is_point_in_range(segments : Array, pos : Vector2, canvas : Transform2D, index : int, type : int) -> bool:
	if index < 0 || index >= segments.size() || type < 1:
		return false
	var segment = segments[index]
	match segment[0]:
		SEGMENT_TYPE.START:
			if type > 1:
				return false
		SEGMENT_TYPE.LINEAR:
			if type > 1:
				return false
		SEGMENT_TYPE.QUADRIC:
			if type > 2:
				return false
		SEGMENT_TYPE.CUBIC:
			if type > 3:
				return false
		SEGMENT_TYPE.ARC:
			if type > 4:
				return false
		_:
			return false
	return (pos-canvas*(segment[type])).length() <= HOVER_RANGE

func snap_drag() -> void:
	if !snap_on:
		return
	var segments : Array = editing.get_shape()
	var canvas := get_canvas_transform()
	var canvas_base := get_canvas_transform(false)
	var grid_offset : Vector2 = canvas_base*(snap_offset)
	var grid_step : Vector2 = canvas_base.basis_xform(snap_step)
	var shift := grid_step*2
	shift = _snap_to_grid(click_drag, Vector2(), grid_step, shift)
	var point_count : int = 0
	var center_mass := Vector2()
	for i in selection:
		if i < 0 || i >= segments.size():
			continue
		var segment_points : int = 1
		match segments[i][0]:
			SEGMENT_TYPE.QUADRIC:
				segment_points = 2
			SEGMENT_TYPE.CUBIC:
				segment_points = 3
			SEGMENT_TYPE.ARC:
				segment_points = 4
		for point in segment_points:
			if point in selection[i]:
				point_count += 1
				center_mass += segments[i][point+1]
				shift = _snap_to_grid(canvas*(segments[i][point+1])+click_drag, grid_offset, grid_step, shift)
	if point_count > 0:
		center_mass /= point_count
		shift = _snap_to_grid(canvas*(center_mass)+click_drag, grid_offset, grid_step, shift)
	click_drag += shift

func snap_create() -> void:
	if !snap_on:
		return
	var segments : Array = editing.get_shape()
	var canvas := get_canvas_transform()
	var canvas_base := get_canvas_transform(false)
	var grid_offset : Vector2 = canvas_base*(snap_offset)
	var grid_step : Vector2 = canvas_base.basis_xform(snap_step)
	var shift := grid_step*2
	shift = _snap_to_grid(click_create, grid_offset, grid_step, shift)
	var point_count : int = 0
	var center_mass := Vector2()
	for i in selection:
		if i < 0 || i >= segments.size():
			continue
		var segment_points : int = 1
		match segments[i][0]:
			SEGMENT_TYPE.QUADRIC:
				segment_points = 2
			SEGMENT_TYPE.CUBIC:
				segment_points = 3
			SEGMENT_TYPE.ARC:
				segment_points = 4
		for point in segment_points:
			if point in selection[i]:
				point_count += 1
				center_mass += segments[i][point+1]
				shift = _snap_to_grid(click_create, canvas*(segments[i][point+1]), grid_step, shift)
	if point_count > 0:
		center_mass /= point_count
		shift = _snap_to_grid(click_create, canvas*(center_mass), grid_step, shift)
	click_create += shift

func _snap_to_grid(target : Vector2, offset : Vector2, step : Vector2, if_closer : Vector2) -> Vector2:
	var shift := (target-offset)/step
	shift.x = round(shift.x)
	shift.y = round(shift.y)
	shift *= step
	shift -= target-offset
	if abs(shift.x) < abs(if_closer.x):
		if abs(shift.y) < abs(if_closer.y):
			return shift
		return Vector2(shift.x, if_closer.y)
	elif abs(shift.y) < abs(if_closer.y):
		return Vector2(if_closer.x, shift.y)
	return if_closer

func apply_drag() -> void:
	var canvas := get_canvas_transform()
	var shift : Vector2 = canvas.affine_inverse().basis_xform(click_drag)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Move vector 2d shape points")
	for i in selection:
		if i < 0 || i >= editing.shape.segments.size():
			continue
		match editing.shape.segments[i][0]:
			SEGMENT_TYPE.START:
				if 0 in selection[i]:
					undo_redo.add_do_property(editing.shape, str(i)+"_start_position", editing.shape.segments[i][1]+shift)
					undo_redo.add_undo_property(editing.shape, str(i)+"_start_position", editing.shape.segments[i][1])
			SEGMENT_TYPE.LINEAR:
				if 0 in selection[i]:
					undo_redo.add_do_property(editing.shape, str(i)+"_linear_end", editing.shape.segments[i][1]+shift)
					undo_redo.add_undo_property(editing.shape, str(i)+"_linear_end", editing.shape.segments[i][1])
			SEGMENT_TYPE.QUADRIC:
				if 0 in selection[i]:
					undo_redo.add_do_property(editing.shape, str(i)+"_quadric_control", editing.shape.segments[i][1]+shift)
					undo_redo.add_undo_property(editing.shape, str(i)+"_quadric_control", editing.shape.segments[i][1])
				if 1 in selection[i]:
					undo_redo.add_do_property(editing.shape, str(i)+"_quadric_end", editing.shape.segments[i][2]+shift)
					undo_redo.add_undo_property(editing.shape, str(i)+"_quadric_end", editing.shape.segments[i][2])
			SEGMENT_TYPE.CUBIC:
				if 0 in selection[i]:
					undo_redo.add_do_property(editing.shape, str(i)+"_cubic_control1", editing.shape.segments[i][1]+shift)
					undo_redo.add_undo_property(editing.shape, str(i)+"_cubic_control1", editing.shape.segments[i][1])
				if 1 in selection[i]:
					undo_redo.add_do_property(editing.shape, str(i)+"_cubic_control2", editing.shape.segments[i][2]+shift)
					undo_redo.add_undo_property(editing.shape, str(i)+"_cubic_control2", editing.shape.segments[i][2])
				if 2 in selection[i]:
					undo_redo.add_do_property(editing.shape, str(i)+"_cubic_end", editing.shape.segments[i][3]+shift)
					undo_redo.add_undo_property(editing.shape, str(i)+"_cubic_end", editing.shape.segments[i][3])
			SEGMENT_TYPE.ARC:
				if 0 in selection[i]:
					undo_redo.add_do_property(editing.shape, str(i)+"_arc_axis1", editing.shape.segments[i][1]+shift)
					undo_redo.add_undo_property(editing.shape, str(i)+"_arc_axis1", editing.shape.segments[i][1])
				if 1 in selection[i]:
					undo_redo.add_do_property(editing.shape, str(i)+"_arc_center", editing.shape.segments[i][2]+shift)
					undo_redo.add_undo_property(editing.shape, str(i)+"_arc_center", editing.shape.segments[i][2])
				if 2 in selection[i]:
					undo_redo.add_do_property(editing.shape, str(i)+"_arc_axis2", editing.shape.segments[i][3]+shift)
					undo_redo.add_undo_property(editing.shape, str(i)+"_arc_axis2", editing.shape.segments[i][3])
				if 3 in selection[i]:
					undo_redo.add_do_property(editing.shape, str(i)+"_arc_end", editing.shape.segments[i][4]+shift)
					undo_redo.add_undo_property(editing.shape, str(i)+"_arc_end", editing.shape.segments[i][4])
	undo_redo.commit_action()

func apply_create() -> void:
	var canvas := get_canvas_transform()
	var end_point : Vector2 = canvas.affine_inverse()*(click_create)
	var undo_redo := get_undo_redo()
	match mode:
		1:
			undo_redo.create_action("Add vector 2d shape start point")
		2:
			undo_redo.create_action("Add vector 2d shape line")
		3:
			undo_redo.create_action("Add vector 2d shape quadric curve")
		4:
			undo_redo.create_action("Add vector 2d shape cubic curve")
		5:
			undo_redo.create_action("Add vector 2d shape elliptical arc")
	var segments : Array = []
	var index : int = 0
	var newindex : int = 0
	var newselection : Dictionary = {}
	for segment in editing.shape.segments:
		segments.append(segment)
		var end_type : int = 1
		match segment[0]:
			SEGMENT_TYPE.QUADRIC:
				end_type = 2
			SEGMENT_TYPE.CUBIC:
				end_type = 3
			SEGMENT_TYPE.ARC:
				end_type = 4
		if index in selection && (end_type-1) in selection[index]:
			newindex += 1
			var pos : Vector2 = segment[end_type]
			match mode:
				1:
					segments.append([SEGMENT_TYPE.START, end_point, 0])
					newselection[newindex] = {0: true}
				2:
					segments.append([SEGMENT_TYPE.LINEAR, end_point])
					newselection[newindex] = {0: true}
				3:
					segments.append([SEGMENT_TYPE.QUADRIC, 0.5*(pos+end_point), end_point])
					newselection[newindex] = {1: true}
				4:
					segments.append([SEGMENT_TYPE.CUBIC, (2.0/3.0)*pos+(1.0/3.0)*end_point, (1.0/3.0)*pos+(2.0/3.0)*end_point, end_point])
					newselection[newindex] = {2: true}
				5:
					var c : Vector2 = 0.5*(pos+end_point)
					segments.append([SEGMENT_TYPE.ARC, (end_point-pos).orthogonal()*0.5+c, c, end_point, end_point])
					newselection[newindex] = {3: true}
		index += 1
		newindex += 1
	if mode == 1 && index == newindex:
		segments.append([SEGMENT_TYPE.START, end_point, 0])
		newselection[newindex] = {0: true}
	undo_redo.add_do_method(self, "_update_element_segments", editing, segments, newselection)
	undo_redo.add_undo_method(self, "_update_element_segments", editing, editing.shape.segments, selection)
	undo_redo.commit_action()

func reload_snap_settings() -> void:
	var viewport = get_editor_interface().get_editor_main_screen()
	if !viewport || viewport.get_child_count() < 1:
		return
	var editor = viewport.get_child(0)
	if editor.get_child_count() < 1:
		return
	var canvas_toolbar = editor.get_child(0)
	if canvas_toolbar.get_child_count() < 1:
		return
	var main_actions_toolbar = canvas_toolbar.get_child(0)
	if main_actions_toolbar.get_child_count() < 14:
		return
	var snapbutton = main_actions_toolbar.get_child(12)
	if !(snapbutton is Button):
		return
	snap_on = snapbutton.is_pressed()
	if !snap_on && !snap_first_time:
		return
	var snapdialog : Node
	for i in editor.get_children():
		if i.is_class("SnapDialog"):
			snapdialog = i
			break
	if snap_first_time:
		snap_first_time = false
		snapbutton.pressed.connect(Callable(self, "reload_snap_settings"))
		snapdialog.confirmed.connect(Callable(self, "reload_snap_settings"))
		if !snap_on:
			return
	main_actions_toolbar.get_child(13).get_child(0).emit_signal("id_pressed", 11)
	snapdialog.visible = false
	var grid_settings = snapdialog.get_child(3).get_child(0)
	snap_offset = Vector2(grid_settings.get_child(1).value, grid_settings.get_child(2).value)
	snap_step = Vector2(grid_settings.get_child(4).value, grid_settings.get_child(5).value)

func update_buttons() -> void:
	if !is_instance_valid(editing) || !editing.is_inside_tree():
		editing = null
	var point_selected : bool = false
	if editing && !editing_readonly:
		var index : int = 0
		for segment in editing.shape.segments:
			match segment[0]:
				SEGMENT_TYPE.START:
					if index in selection && 0 in selection[index]:
						point_selected = true
				SEGMENT_TYPE.LINEAR:
					if index in selection && 0 in selection[index]:
						point_selected = true
				SEGMENT_TYPE.QUADRIC:
					if index in selection && 1 in selection[index]:
						point_selected = true
				SEGMENT_TYPE.CUBIC:
					if index in selection && 2 in selection[index]:
						point_selected = true
				SEGMENT_TYPE.ARC:
					if index in selection && 3 in selection[index]:
						point_selected = true
			if point_selected:
				break
			index += 1
	button_start.disabled = !editing || editing_readonly
	button_line.disabled = !point_selected
	button_quad.disabled = !point_selected
	button_cube.disabled = !point_selected
	button_arc.disabled = !point_selected
	button_delete.disabled = !point_selected
	if (!point_selected && mode > 1) || !editing || editing_readonly:
		set_mode(0)

func set_mode(p_mode : int) -> void:
	mode = p_mode
	button_select.set_pressed_no_signal(mode == 0)
	button_start.set_pressed_no_signal(mode == 1)
	button_line.set_pressed_no_signal(mode == 2)
	button_quad.set_pressed_no_signal(mode == 3)
	button_cube.set_pressed_no_signal(mode == 4)
	button_arc.set_pressed_no_signal(mode == 5)

func delete_selected() -> void:
	if editing && (!is_instance_valid(editing) || !editing.is_inside_tree()):
		editing = null
		update_overlays()
		update_buttons()
	if !editing || editing_readonly:
		return
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Delete vector 2d shape points")
	var segments : Array = []
	var index : int = 0
	var newindex : int = 0
	var newselection : Dictionary = {}
	for segment in editing.shape.segments:
		var end_type : int = 1
		match segment[0]:
			SEGMENT_TYPE.QUADRIC:
				end_type = 2
			SEGMENT_TYPE.CUBIC:
				end_type = 3
			SEGMENT_TYPE.ARC:
				end_type = 4
		if !(index in selection && (end_type-1) in selection[index]):
			segments.append(segment)
			if index in selection:
				newselection[newindex] = selection[index].duplicate()
			newindex += 1
		index += 1
	undo_redo.add_do_method(self, "_update_element_segments", editing, segments, newselection)
	undo_redo.add_undo_method(self, "_update_element_segments", editing, editing.shape.segments, selection)
	undo_redo.commit_action()
	update_overlays()
	update_buttons()

func _update_element_segments(element : Object, segments : Array, new_selection : Dictionary) -> void:
	element.shape.segments = segments
	element.shape.emit_signal("changed")
	if editing == element:
		selection = new_selection
		update_buttons()
