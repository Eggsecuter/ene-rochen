shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float pixel_size : hint_range(2.0, 20.0, 2.0);
uniform float levels : hint_range(2.0, 100.0, 2.0);
uniform vec2 gamma;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 texture_size = vec2(textureSize(screen_texture, 0));
	vec2 pixel_count = texture_size / pixel_size;
	vec2 pixelated_uv = floor(SCREEN_UV * pixel_count) / pixel_count;
	vec4 color = texture(screen_texture, pixelated_uv);
	
	color.rgb = pow(color.rgb, vec3(gamma.x));
	
	float grayscale = max(color.r, max(color.g, color.b));
	float lower = floor(grayscale * levels) / levels;
	float higher = ceil(grayscale * levels) / levels;
	
	float lower_difference = abs(lower - grayscale);
	float higher_difference = abs(higher - grayscale);
	
	float level = lower_difference < higher_difference ? lower : higher;
	float color_adjustment = grayscale > 0.0 ? level / grayscale : 0.0;
	
	color.rgb *= color_adjustment;
	color.rgb = pow(color.rgb, vec3(gamma.y));
	
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
