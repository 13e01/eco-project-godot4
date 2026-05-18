shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float effect_power : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 diff = center - uv;
	vec2 distorted_uv = uv + diff * effect_power * length(diff);
	vec4 color = texture(SCREEN_TEXTURE, distorted_uv);
	
	float d = length(diff);
	color.rgb *= mix(1.0, 0.6, d * effect_power * 3.0);
	
	COLOR = color;
}