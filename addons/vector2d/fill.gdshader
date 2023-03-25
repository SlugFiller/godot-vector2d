shader_type canvas_item;
render_mode skip_vertex_transform, unshaded;

const int MAX_RECURSE = 1024;
const int MAX_LOOP = 4096;

uniform vec2 bbox_position;
uniform vec2 bbox_size;
uniform bool evenOdd;
uniform float feather;
uniform sampler2D segments : filter_nearest;
uniform sampler2D tree : filter_nearest;
uniform sampler2D bboxs : filter_nearest;
uniform int paint_type;
uniform vec2 gradient_point1;
uniform vec2 gradient_point2;
uniform float gradient_radius1;
uniform float gradient_radius2;
uniform mat4 gradient_transform;
uniform sampler2D gradient_stops : filter_nearest;
uniform sampler2D gradient_colors : filter_linear;
varying vec2 local_coord;
varying flat mat4 proj_mat;

void vertex() {
	mat4 matrix = CANVAS_MATRIX*MODEL_MATRIX;
	mat4 matrix_inv = inverse(CANVAS_MATRIX);
	vec2 proj_bbox_00 = (matrix * vec4(bbox_position, 0.0, 1.0)).xy;
	vec2 proj_bbox_01 = (matrix * vec4(bbox_position+vec2(0.0, bbox_size.y), 0.0, 1.0)).xy;
	vec2 proj_bbox_10 = (matrix * vec4(bbox_position+vec2(bbox_size.x, 0.0), 0.0, 1.0)).xy;
	vec2 proj_bbox_11 = (matrix * vec4(bbox_position+bbox_size, 0.0, 1.0)).xy;
	vec2 proj_bbox_min = min(min(proj_bbox_00, proj_bbox_01), min(proj_bbox_10, proj_bbox_11))-(feather+1.0)*vec2(1.0, 1.0);
	vec2 proj_bbox_max = max(max(proj_bbox_00, proj_bbox_01), max(proj_bbox_10, proj_bbox_11))+(feather+1.0)*vec2(1.0, 1.0);
	local_coord = proj_bbox_min+UV*(proj_bbox_max-proj_bbox_min);
	VERTEX = (matrix_inv * vec4(local_coord, 0.0, 1.0)).xy;
	proj_mat = matrix;
}

float calculate_distance_linear(vec2 start, vec2 end, float max_distance) {
	if (start.x <= -max_distance && end.x <= -max_distance) {
		return max_distance;
	}
	if (start.x >= max_distance && end.x >= max_distance) {
		return max_distance;
	}
	if (start.y <= -max_distance && end.y <= -max_distance) {
		return max_distance;
	}
	if (start.y >= max_distance && end.y >= max_distance) {
		return max_distance;
	}
	float d;
	d = length(start);
	if (max_distance > d) {
		max_distance = d;
	}
	d = length(end);
	if (max_distance > d) {
		max_distance = d;
	}
	d = dot(end, end-start);
	if (d > 0.0 && d < dot(end-start, end-start)) {
		d = abs(dot(vec2(end.y, -end.x), end-start)/distance(start, end));
		if (max_distance > d) {
			max_distance = d;
		}
	}
	return max_distance;
}

int calculate_winding_linear(vec2 start, vec2 end) {
	if (start.x < 0.0 && end.x < 0.0) {
		return 0;
	}
	if (start.y < 0.0 && end.y < 0.0) {
		return 0;
	}
	if (start.y > 0.0 && end.y > 0.0) {
		return 0;
	}
	if (start.y == 0.0) {
		if (start.x < 0.0) {
			return 0;
		}
		if (end.y == 0.0) {
			return 0;
		}
		if (end.y > 0.0) {
			return 1;
		}
		return -1;
	}
	if (end.y == 0.0) {
		if (end.x < 0.0) {
			return 0;
		}
		if (start.y == 0.0) {
			return 0;
		}
		if (start.y < 0.0) {
			return 1;
		}
		return -1;
	}
	if (end.y > start.y) {
		if (start.x*(end.y-start.y) < start.y*(end.x-start.x)) {
			return 0;
		}
	}
	else {
		if (start.x*(end.y-start.y) > start.y*(end.x-start.x)) {
			return 0;
		}
	}
	if (start.y > 0.0) {
		return -2;
	}
	return 2;
}

vec2 readVec(int u, int v) {
	u++;
	vec4 t = texelFetch(segments, ivec2(u, v), 0);
	return vec2((t.r < 0.5)?(2.0-1.0/t.r):(1.0/(1.0-t.r)-2.0), (t.g < 0.5)?(2.0-1.0/t.g):(1.0/(1.0-t.g)-2.0));
}

vec2 readVecProjected(int u, int v) {
	return (proj_mat*vec4(readVec(u, v), 0.0, 1.0)).xy-local_coord.xy;
}

vec2 readVecProjectedAffine(int u, int v) {
	return (proj_mat*vec4(readVec(u, v), 0.0, 0.0)).xy;
}

int readIndex(int u, int v) {
	vec4 t = texelFetch(tree, ivec2(u, v), 0);
	return int(t.r*255.0+0.5) | (int(t.g*255.0+0.5) << 8);
}

bool checkBBoxWinding(int v) {
	vec4 t = texelFetch(bboxs, ivec2(0, v), 0);
	vec2 topleft = vec2((t.r < 0.5)?(2.0-1.0/t.r):(1.0/(1.0-t.r)-2.0), (t.g < 0.5)?(2.0-1.0/t.g):(1.0/(1.0-t.g)-2.0));
	t = texelFetch(bboxs, ivec2(1, v), 0);
	vec2 bottomright = vec2((t.r < 0.5)?(2.0-1.0/t.r):(1.0/(1.0-t.r)-2.0), (t.g < 0.5)?(2.0-1.0/t.g):(1.0/(1.0-t.g)-2.0));
	vec2 topright = vec2(bottomright.x, topleft.y);
	vec2 bottomleft = vec2(topleft.x, bottomright.y);
	topleft = (proj_mat*vec4(topleft, 0.0, 1.0)).xy-local_coord.xy;
	bottomright = (proj_mat*vec4(bottomright, 0.0, 1.0)).xy-local_coord.xy;
	topright = (proj_mat*vec4(topright, 0.0, 1.0)).xy-local_coord.xy;
	bottomleft = (proj_mat*vec4(bottomleft, 0.0, 1.0)).xy-local_coord.xy;
	if (calculate_winding_linear(topleft, topright) != 0) {
		return true;
	}
	if (calculate_winding_linear(bottomleft, bottomright) != 0) {
		return true;
	}
	if (calculate_winding_linear(topright, bottomright) != 0) {
		return true;
	}
	if (calculate_winding_linear(topleft, bottomleft) != 0) {
		return true;
	}
	return false;
}

bool checkBBoxDistance(int v, float max_distance) {
	if (max_distance <= 0.0) {
		return false;
	}
	vec4 t = texelFetch(bboxs, ivec2(0, v), 0);
	vec2 topleft = vec2((t.r < 0.5)?(2.0-1.0/t.r):(1.0/(1.0-t.r)-2.0), (t.g < 0.5)?(2.0-1.0/t.g):(1.0/(1.0-t.g)-2.0));
	t = texelFetch(bboxs, ivec2(1, v), 0);
	vec2 bottomright = vec2((t.r < 0.5)?(2.0-1.0/t.r):(1.0/(1.0-t.r)-2.0), (t.g < 0.5)?(2.0-1.0/t.g):(1.0/(1.0-t.g)-2.0));
	vec2 topright = vec2(bottomright.x, topleft.y);
	vec2 bottomleft = vec2(topleft.x, bottomright.y);
	topleft = (proj_mat*vec4(topleft, 0.0, 1.0)).xy-local_coord.xy;
	bottomright = (proj_mat*vec4(bottomright, 0.0, 1.0)).xy-local_coord.xy;
	topright = (proj_mat*vec4(topright, 0.0, 1.0)).xy-local_coord.xy;
	bottomleft = (proj_mat*vec4(bottomleft, 0.0, 1.0)).xy-local_coord.xy;
	if (calculate_winding_linear(topleft, topright)+calculate_winding_linear(bottomright, bottomleft)+calculate_winding_linear(topright, bottomright)+calculate_winding_linear(bottomleft, topleft) != 0) {
		return true;
	}
	if (calculate_distance_linear(topleft, topright, max_distance) < max_distance) {
		return true;
	}
	if (calculate_distance_linear(bottomleft, bottomright, max_distance) < max_distance) {
		return true;
	}
	if (calculate_distance_linear(topright, bottomright, max_distance) < max_distance) {
		return true;
	}
	if (calculate_distance_linear(topleft, bottomleft, max_distance) < max_distance) {
		return true;
	}
	return false;
}

void fragment() {
	while (true) {
		if (textureSize(segments, 0).x < 8) {
			COLOR.a = 0.0;
			break;
		}
		vec2 stack[1024];
		int recurse_ptr;
		int winding = 0;
		int node = 0;
		while (true) {
			if (checkBBoxWinding(node)) {
				int segment = readIndex(3, node);
				if (segment > 0) {
					segment--;
					float type = texelFetch(segments, ivec2(0, segment), 0).r;
					if (type < 0.5) {
						if (type < 0.25) {
							winding += calculate_winding_linear(readVecProjected(0, segment), readVecProjected(1, segment));
						}
						else {
							vec2 start = readVecProjected(0, segment);
							vec2 control = readVecProjected(1, segment);
							vec2 end = readVecProjected(2, segment);
							recurse_ptr = 0;
							for (int j = 0; j < MAX_LOOP; j++) {
								int calc_winding = calculate_winding_linear(start, end);
								int test_winding = calculate_winding_linear(start, control)+calculate_winding_linear(control, end);
								if (recurse_ptr+3 > MAX_RECURSE || calc_winding == test_winding || distance(start, control)+distance(control, end) < 0.5) {
									winding += calculate_winding_linear(start, end);
									if (recurse_ptr < 3) {
										break;
									}
									end = stack[--recurse_ptr];
									control = stack[--recurse_ptr];
									start = stack[--recurse_ptr];
									continue;
								}
								vec2 a1 = 0.5*(start+control);
								vec2 a2 = 0.5*(control+end);
								vec2 b = 0.5*(a1+a2);
								stack[recurse_ptr++] = b;
								stack[recurse_ptr++] = a2;
								stack[recurse_ptr++] = end;
								control = a1;
								end = b;
							}
						}
					}
					else {
						if (type < 0.75) {
							vec2 start = readVecProjected(0, segment);
							vec2 control1 = readVecProjected(1, segment);
							vec2 control2 = readVecProjected(2, segment);
							vec2 end = readVecProjected(3, segment);
							recurse_ptr = 0;
							for (int j = 0; j < MAX_LOOP; j++) {
								int calc_winding = calculate_winding_linear(start, end);
								int wind_s1 = calculate_winding_linear(start, control1);
								int wind_s2 = calculate_winding_linear(start, control2);
								int wind_se = calculate_winding_linear(start, end);
								int wind_12 = calculate_winding_linear(control1, control2);
								int wind_1e = calculate_winding_linear(control1, end);
								int wind_2e = calculate_winding_linear(control2, end);
								if (recurse_ptr+4 > MAX_RECURSE || (wind_s1+wind_s2 == wind_12 && wind_s1+wind_1e == wind_se && wind_s2+wind_2e == wind_se && wind_12+wind_2e == wind_1e) || distance(start, control1)+distance(control1, control2)+distance(control2, end) < 0.5) {
									winding += calc_winding;
									if (recurse_ptr < 4) {
										break;
									}
									end = stack[--recurse_ptr];
									control2 = stack[--recurse_ptr];
									control1 = stack[--recurse_ptr];
									start = stack[--recurse_ptr];
									continue;
								}
								vec2 a1 = 0.5*(start+control1);
								vec2 a2 = 0.5*(control1+control2);
								vec2 a3 = 0.5*(control2+end);
								vec2 b1 = 0.5*(a1+a2);
								vec2 b2 = 0.5*(a2+a3);
								vec2 c = 0.5*(b1+b2);
								stack[recurse_ptr++] = c;
								stack[recurse_ptr++] = b2;
								stack[recurse_ptr++] = a3;
								stack[recurse_ptr++] = end;
								control1 = a1;
								control2 = b1;
								end = c;
							}
						}
						else {
							vec2 start = normalize(readVec(0, segment));
							vec2 end = normalize(readVec(1, segment));
							vec2 center = readVecProjected(2, segment);
							vec2 radius1 = readVecProjectedAffine(3, segment);
							vec2 radius2 = readVecProjectedAffine(4, segment);
							vec2 pstart = readVecProjected(5, segment);
							vec2 pend = readVecProjected(6, segment);
							bool xfirst = (start.y < end.y)?(start.x < end.x):(start.x > end.x);
							winding += calculate_winding_linear(pstart, center+start.x*radius1+start.y*radius2);
							winding += calculate_winding_linear(center+end.x*radius1+end.y*radius2, pend);
							recurse_ptr = 0;
							for (int j = 0; j < MAX_LOOP; j++) {
								vec2 mid = xfirst?vec2(end.x, start.y):vec2(start.x, end.y);
								vec2 p1 = center+start.x*radius1+start.y*radius2;
								vec2 p2 = center+mid.x*radius1+mid.y*radius2;
								vec2 p3 = center+end.x*radius1+end.y*radius2;
								int calc_winding = calculate_winding_linear(p1, p3);
								int test_winding = calculate_winding_linear(p1, p2)+calculate_winding_linear(p2, p3);
								if (recurse_ptr+2 > MAX_RECURSE || calc_winding == test_winding || distance(p1, p2)+distance(p2, p3) < 0.5) {
									winding += calc_winding;
									if (recurse_ptr < 2) {
										break;
									}
									end = stack[--recurse_ptr];
									start = stack[--recurse_ptr];
									continue;
								}
								vec2 m = normalize(start+end);
								stack[recurse_ptr++] = m;
								stack[recurse_ptr++] = end;
								end = m;
							}
						}
					}
				}
				int child = readIndex(1, node);
				if (child > 0) {
					node = child;
					continue;
				}
			}
			int next = readIndex(2, node);
			while (next <= 0) {
				node = readIndex(0, node);
				if (node <= 0) {
					break;
				}
				next = readIndex(2, node);
			}
			if (next <= 0) {
				break;
			}
			node = next;
		}
		bool applyFeather = false;
		float applyFeatherValue = 1.0;
		if (winding == 0 || (evenOdd && (winding & 2) == 0)) {
			float d = feather;
			while (true) {
				if (checkBBoxDistance(node, d)) {
					int segment = readIndex(3, node);
					if (segment > 0) {
						segment--;
						float type = texelFetch(segments, ivec2(0, segment), 0).r;
						if (type < 0.5) {
							if (type < 0.25) {
								d = calculate_distance_linear(readVecProjected(0, segment), readVecProjected(1, segment), d);
							}
							else {
								vec2 start = readVecProjected(0, segment);
								vec2 control = readVecProjected(1, segment);
								vec2 end = readVecProjected(2, segment);
								recurse_ptr = 0;
								for (int j = 0; j < MAX_LOOP; j++) {
									if ((start.x < -d && control.x < -d && end.x < -d) ||
										(start.y < -d && control.y < -d && end.y < -d) ||
										(start.x > d && control.x > d && end.x > d) ||
										(start.y > d && control.y > d && end.y > d)) {
										if (recurse_ptr < 3) {
											break;
										}
										end = stack[--recurse_ptr];
										control = stack[--recurse_ptr];
										start = stack[--recurse_ptr];
										continue;
									}
									if (recurse_ptr+3 > MAX_RECURSE || (distance(start, control) < 0.5 && distance(control, end) < 0.5)) {
										d = calculate_distance_linear(start, end, d);
										if (recurse_ptr < 3) {
											break;
										}
										end = stack[--recurse_ptr];
										control = stack[--recurse_ptr];
										start = stack[--recurse_ptr];
										continue;
									}
									vec2 a1 = 0.5*(start+control);
									vec2 a2 = 0.5*(control+end);
									vec2 b = 0.5*(a1+a2);
									stack[recurse_ptr++] = b;
									stack[recurse_ptr++] = a2;
									stack[recurse_ptr++] = end;
									control = a1;
									end = b;
								}
							}
						}
						else {
							if (type < 0.75) {
								vec2 start = readVecProjected(0, segment);
								vec2 control1 = readVecProjected(1, segment);
								vec2 control2 = readVecProjected(2, segment);
								vec2 end = readVecProjected(3, segment);
								recurse_ptr = 0;
								for (int j = 0; j < MAX_LOOP; j++) {
									if ((start.x < -d && control1.x < -d && control2.x < -d && end.x < -d) ||
										(start.y < -d && control1.y < -d && control2.y < -d && end.y < -d) ||
										(start.x > d && control1.x > d && control2.x > d && end.x > d) ||
										(start.y > d && control1.y > d && control2.y > d && end.y > d)) {
										if (recurse_ptr < 4) {
											break;
										}
										end = stack[--recurse_ptr];
										control2 = stack[--recurse_ptr];
										control1 = stack[--recurse_ptr];
										start = stack[--recurse_ptr];
										continue;
									}
									if (recurse_ptr+4 > MAX_RECURSE || (distance(start, control1) < 0.5 && distance(control1, control2) < 0.5 && distance(control2, end) < 0.5)) {
										d = calculate_distance_linear(start, end, d);
										if (recurse_ptr < 4) {
											break;
										}
										end = stack[--recurse_ptr];
										control2 = stack[--recurse_ptr];
										control1 = stack[--recurse_ptr];
										start = stack[--recurse_ptr];
										continue;
									}
									vec2 a1 = 0.5*(start+control1);
									vec2 a2 = 0.5*(control1+control2);
									vec2 a3 = 0.5*(control2+end);
									vec2 b1 = 0.5*(a1+a2);
									vec2 b2 = 0.5*(a2+a3);
									vec2 c = 0.5*(b1+b2);
									stack[recurse_ptr++] = c;
									stack[recurse_ptr++] = b2;
									stack[recurse_ptr++] = a3;
									stack[recurse_ptr++] = end;
									control1 = a1;
									control2 = b1;
									end = c;
								}
							}
							else {
								vec2 start = normalize(readVec(0, segment));
								vec2 end = normalize(readVec(1, segment));
								vec2 center = readVecProjected(2, segment);
								vec2 radius1 = readVecProjectedAffine(3, segment);
								vec2 radius2 = readVecProjectedAffine(4, segment);
								vec2 pstart = readVecProjected(5, segment);
								vec2 pend = readVecProjected(6, segment);
								d = calculate_distance_linear(pstart, center+start.x*radius1+start.y*radius2, d);
								d = calculate_distance_linear(center+end.x*radius1+end.y*radius2, pend, d);
								recurse_ptr = 0;
								for (int j = 0; j < MAX_LOOP; j++) {
									if ((center.x+start.x*radius1.x+start.y*radius2.x < -d && center.x+end.x*radius1.x+start.y*radius2.x < -d && center.x+start.x*radius1.x+end.y*radius2.x < -d && center.x+end.x*radius1.x+end.y*radius2.x < -d) ||
										(center.y+start.x*radius1.y+start.y*radius2.y < -d && center.y+end.x*radius1.y+start.y*radius2.y < -d && center.y+start.x*radius1.y+end.y*radius2.y < -d && center.y+end.x*radius1.y+end.y*radius2.y < -d) ||
										(center.x+start.x*radius1.x+start.y*radius2.x > d && center.x+end.x*radius1.x+start.y*radius2.x > d && center.x+start.x*radius1.x+end.y*radius2.x > d && center.x+end.x*radius1.x+end.y*radius2.x > d) ||
										(center.y+start.x*radius1.y+start.y*radius2.y > d && center.y+end.x*radius1.y+start.y*radius2.y > d && center.y+start.x*radius1.y+end.y*radius2.y > d && center.y+end.x*radius1.y+end.y*radius2.y > d)) {
										if (recurse_ptr < 2) {
											break;
										}
										end = stack[--recurse_ptr];
										start = stack[--recurse_ptr];
										continue;
									}
									if (recurse_ptr+2 > MAX_RECURSE || distance(start, end) < 1e-3) {
										d = calculate_distance_linear(center+start.x*radius1+start.y*radius2, center+end.x*radius1+end.y*radius2, d);
										if (recurse_ptr < 2) {
											break;
										}
										end = stack[--recurse_ptr];
										start = stack[--recurse_ptr];
										continue;
									}
									vec2 m = normalize(start+end);
									stack[recurse_ptr++] = m;
									stack[recurse_ptr++] = end;
									end = m;
								}
							}
						}
					}
					int child = readIndex(1, node);
					if (child > 0) {
						node = child;
						continue;
					}
				}
				int next = readIndex(2, node);
				while (next <= 0) {
					node = readIndex(0, node);
					if (node <= 0) {
						break;
					}
					next = readIndex(2, node);
				}
				if (next <= 0) {
					break;
				}
				node = next;
			}
			if (feather > 0.0 && d < feather) {
				applyFeather = true;
				applyFeatherValue = 1.0-d/feather;
			}
			else {
				discard;
				break;
			}
		}
		if (paint_type >= 1 && paint_type <= 6) {
			float gradpoint = 0.0;
			if (paint_type >= 1 && paint_type <= 3) {
				vec2 gp1 = (proj_mat*gradient_transform*vec4(gradient_point1, 0.0, 1.0)).xy-local_coord.xy;
				vec2 gp2 = (proj_mat*gradient_transform*vec4(gradient_point2, 0.0, 1.0)).xy-local_coord.xy;
				vec2 gpt = (gradient_point2-gradient_point1);
				gpt = (proj_mat*gradient_transform*vec4(gradient_point1+vec2(gpt.y, -gpt.x), 0.0, 1.0)).xy-local_coord.xy;
				gradpoint = -(inverse(mat2(gp2-gp1, gpt-gp1))*gp1).x;
			}
			else {
				vec2 testpoint = (inverse(proj_mat*gradient_transform)*vec4(local_coord, 0.0, 1.0)).xy-gradient_point1;
				vec2 testshift = gradient_point2-gradient_point1;
				float dr = gradient_radius2-gradient_radius1;
				float ts2 = dot(testshift, testshift)-dr*dr;
				dr = dr*gradient_radius1+dot(testshift, testpoint);
				if (ts2 > -1e-10 && ts2 < 1e-10) {
					if (dr > -1e-10 && dr < 1e-10) {
						discard;
						break;
					}
					gradpoint = 0.5*(dot(testpoint, testpoint)-gradient_radius1*gradient_radius1)/dr;
				}
				else {
					float tp2 = (dot(testpoint, testpoint)-gradient_radius1*gradient_radius1)/ts2;
					dr /= ts2;
					if (dr*dr < tp2) {
						discard;
						break;
					}
					else {
						tp2 = sqrt(dr*dr-tp2);
						if (gradient_radius1 >= (gradient_radius1-gradient_radius2)*(dr-tp2)) {
							gradpoint = dr-tp2;
						}
						else if (gradient_radius1 >= (gradient_radius1-gradient_radius2)*(dr+tp2)) {
							gradpoint = dr+tp2;
						}
						else {
							discard;
							break;
						}
					}
				}
			}
			if (gradpoint < 0.0) {
				if (paint_type == 1 || paint_type == 4) {
					gradpoint = 0.0;
				}
				else if (paint_type == 3 || paint_type == 6) {
					gradpoint = -gradpoint;
				}
				else {
					gradpoint = 1.0-fract(-gradpoint);
				}
			}
			if (gradpoint > 1.0) {
				if (paint_type == 1 || paint_type == 4) {
					gradpoint = 1.0;
				}
				else if (paint_type == 3 || paint_type == 6) {
					gradpoint = 2.0*fract(0.5*gradpoint);
					if (gradpoint > 1.0) {
						gradpoint = 2.0-gradpoint;
					}
				}
				else {
					gradpoint = fract(gradpoint);
				}
			}
			COLOR.r = gradpoint;
			COLOR.g = gradpoint;
			COLOR.b = gradpoint;
			int stopCount = textureSize(gradient_stops, 0).x;
			float lastPoint = 0.0;
			bool found = false;
			for (int j = 0; j < stopCount; j++) {
				vec4 t = texelFetch(gradient_stops, ivec2(j, 0), 0);
				if (gradpoint < t.r) {
					gradpoint = ((gradpoint-lastPoint)/(t.r-lastPoint)+float(j))/float(stopCount);
					found = true;
					break;
				}
				lastPoint = t.r;
			}
			if (!found) {
				gradpoint = 1.0;
			}
			COLOR = texture(gradient_colors, vec2(gradpoint, 0.5));
		}
		if (applyFeather) {
			COLOR.a *= applyFeatherValue;
		}
		break;
	}
}
