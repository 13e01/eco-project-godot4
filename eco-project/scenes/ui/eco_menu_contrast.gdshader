shader_type canvas_item;

uniform float time = 0.0;

void fragment() {
	vec2 uv = UV;
	float split = 0.50 + sin(time * 0.35) * 0.035;
	float side = smoothstep(split - 0.18, split + 0.18, uv.x);
	float scan = sin((uv.y + time * 0.08) * 54.0) * 0.035;
	float glow = smoothstep(0.42, 0.0, abs(uv.x - split)) * 0.38;
	vec3 past = vec3(0.10, 0.24, 0.18) + vec3(0.06, 0.14, 0.05) * (1.0 - uv.y);
	vec3 future = vec3(0.22, 0.12, 0.13) + vec3(0.06, 0.02, 0.08) * uv.y;
	vec3 color = mix(past, future, side);
	color += vec3(0.65, 0.95, 0.56) * glow * (1.0 - side);
	color += vec3(0.95, 0.25, 0.18) * glow * side;
	color += scan * side;
	COLOR = vec4(color, 1.0);
}
