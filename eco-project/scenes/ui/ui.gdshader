shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float shake_power = 0.03;
uniform float shake_rate = 0.2;
uniform float shake_speed = 5.0;
uniform float shake_block_size = 30.5;
uniform float shake_color_rate = 0.01;

float random(float seed) {
	return fract(sin(seed) * 43758.5453123);
}

void fragment() {
	float enable_shift = float(random(trunc(TIME * shake_speed)) < shake_rate);
	
	vec2 fixed_uv = SCREEN_UV;
	fixed_uv.x += (random(trunc(SCREEN_UV.y * shake_block_size) + TIME) - 0.5) * shake_power * enable_shift;
	
	vec4 pixel_color = texture(SCREEN_TEXTURE, fixed_uv);
	pixel_color.r = texture(SCREEN_TEXTURE, fixed_uv + vec2(shake_color_rate, 0.0)).r;
	pixel_color.b = texture(SCREEN_TEXTURE, fixed_uv - vec2(shake_color_rate, 0.0)).b;
	
	COLOR = pixel_color;
}