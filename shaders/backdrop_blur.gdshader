shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur : hint_range(0.0, 6.0) = 3.0;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 0.35);

void fragment() {
	// sample a mip level and soften it with a small 3x3 kernel
	vec2 texel = SCREEN_PIXEL_SIZE * exp2(blur);
	vec3 color = vec3(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			color += textureLod(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * texel, blur).rgb;
		}
	}
	color /= 9.0;

	COLOR = vec4(mix(color, tint.rgb, tint.a * (blur / 6.0)), 1.0);
}
