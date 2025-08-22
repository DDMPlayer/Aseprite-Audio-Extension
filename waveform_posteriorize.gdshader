shader_type canvas_item;

vec4 pow_parts(vec4 vec, float a) {
	return vec4(pow(vec.r, a), pow(vec.g, a), pow(vec.b, a), vec.a);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if(col.r + col.g >= 0.7) {
		col = vec4(vec3(1.0), col.a);
	} else if(col.r > col.g) {
		col = vec4(vec3(0.93f, 0.76f, 0.88f), col.a);
	} else {
		col = vec4(vec3(0.56f, 0.44f, 0.53f), col.a);
	}

	if(col.a != 0.0) col.a = 1.0;

	COLOR = col;
}