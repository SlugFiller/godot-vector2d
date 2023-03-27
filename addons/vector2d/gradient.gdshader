shader_type canvas_item;
render_mode unshaded;

uniform int paint_type;
uniform vec2 gradient_point1;
uniform vec2 gradient_point2;
uniform float gradient_radius1;
uniform float gradient_radius2;
uniform mat4 gradient_transform;
uniform sampler2D gradient_stops : filter_nearest;
uniform sampler2D gradient_colors : filter_linear;
varying vec2 local_coord;

void vertex() {
	local_coord = VERTEX;
}

void fragment() {
	bool skip = false;
	float gradpoint = 0.0;
	if (paint_type >= 1 && paint_type <= 3) {
		vec2 gp1 = (gradient_transform*vec4(gradient_point1, 0.0, 1.0)).xy-local_coord.xy;
		vec2 gp2 = (gradient_transform*vec4(gradient_point2, 0.0, 1.0)).xy-local_coord.xy;
		vec2 gpt = (gradient_point2-gradient_point1);
		gpt = (gradient_transform*vec4(gradient_point1+vec2(gpt.y, -gpt.x), 0.0, 1.0)).xy-local_coord.xy;
		gradpoint = -(inverse(mat2(gp2-gp1, gpt-gp1))*gp1).x;
	}
	else {
		vec2 testpoint = (inverse(gradient_transform)*vec4(local_coord, 0.0, 1.0)).xy-gradient_point1;
		vec2 testshift = gradient_point2-gradient_point1;
		float dr = gradient_radius2-gradient_radius1;
		float ts2 = dot(testshift, testshift)-dr*dr;
		dr = dr*gradient_radius1+dot(testshift, testpoint);
		if (ts2 > -1e-10 && ts2 < 1e-10) {
			if (dr > -1e-10 && dr < 1e-10) {
				discard;
				skip = true;
			}
			else {
				gradpoint = 0.5*(dot(testpoint, testpoint)-gradient_radius1*gradient_radius1)/dr;
			}
		}
		else {
			float tp2 = (dot(testpoint, testpoint)-gradient_radius1*gradient_radius1)/ts2;
			dr /= ts2;
			if (dr*dr < tp2) {
				discard;
				skip = true;
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
					skip = true;
				}
			}
		}
	}
	if (!skip) {
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
}
