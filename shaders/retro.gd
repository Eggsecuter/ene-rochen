@tool
extends CompositorEffect
class_name RetroPostProcess


const TEMPLATE_SHADER: String = """
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 reserved;
} params;


void main() {
	ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	if (pixel_coord.x >= size.x || pixel_coord.y >= size.y) {
		return;
	}

	vec4 color = imageLoad(color_image, pixel_coord);

	#COMPUTE_CODE

	imageStore(color_image, pixel_coord, color);
}
"""


@export_category("Pixelation")

@export_range(2.0, 20.0, 2.0)
var pixel_size: float = 4.0:
	set(value):
		mutex.lock()
		pixel_size = value
		shader_is_dirty = true
		mutex.unlock()


@export_range(2.0, 100.0, 2.0)
var levels: float = 30.0:
	set(value):
		mutex.lock()
		levels = value
		shader_is_dirty = true
		mutex.unlock()


@export
var gamma: Vector2 = Vector2(0.125, 8.0):
	set(value):
		mutex.lock()
		gamma = value
		shader_is_dirty = true
		mutex.unlock()


@export_category("Dithering")

@export_range(0.0, 1.0, 0.01)
var dither_strength: float = 0.20:
	set(value):
		mutex.lock()
		dither_strength = value
		shader_is_dirty = true
		mutex.unlock()


@export_category("Glow")

@export_range(0.0, 1.0, 0.01)
var glow_strength: float = 0.08:
	set(value):
		mutex.lock()
		glow_strength = value
		shader_is_dirty = true
		mutex.unlock()


@export_range(0.0, 2.0, 0.01)
var glow_threshold: float = 0.75:
	set(value):
		mutex.lock()
		glow_threshold = value
		shader_is_dirty = true
		mutex.unlock()


var rd: RenderingDevice
var shader: RID
var pipeline: RID

var mutex: Mutex = Mutex.new()
var shader_is_dirty: bool = true


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			rd.free_rid(shader)


func _check_shader() -> bool:
	if not rd:
		return false

	var new_shader_code := ""

	mutex.lock()

	if shader_is_dirty:
		new_shader_code = _build_shader_code()
		shader_is_dirty = false

	mutex.unlock()

	if new_shader_code.is_empty():
		return pipeline.is_valid()

	new_shader_code = TEMPLATE_SHADER.replace(
		"#COMPUTE_CODE",
		new_shader_code
	)

	if shader.is_valid():
		rd.free_rid(shader)
		shader = RID()
		pipeline = RID()

	var shader_source := RDShaderSource.new()
	shader_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	shader_source.source_compute = new_shader_code

	var shader_spirv := rd.shader_compile_spirv_from_source(shader_source)

	if shader_spirv.compile_error_compute != "":
		push_error("Failed parse:")
		push_error(shader_spirv.compile_error_compute)
		push_error("Generated shader:")
		push_error(new_shader_code)
		return false

	shader = rd.shader_create_from_spirv(shader_spirv)

	if not shader.is_valid():
		push_error("Failed to create shader.")
		return false

	pipeline = rd.compute_pipeline_create(shader)

	return pipeline.is_valid()


func _build_shader_code() -> String:
	return """
		float pixel_size_value = %.6f;
		float levels_value = %.6f;

		vec2 gamma_value = vec2(
			%.6f,
			%.6f
		);

		float dither_strength_value = %.6f;
		float glow_strength_value = %.6f;
		float glow_threshold_value = %.6f;


		// ------------------------------------------------------------
		// PIXELATION
		// ------------------------------------------------------------

		vec2 screen_uv =
			vec2(pixel_coord) / params.raster_size;

		vec2 pixel_count =
			params.raster_size / pixel_size_value;

		vec2 pixelated_uv =
			floor(screen_uv * pixel_count)
			/ pixel_count;

		ivec2 sample_position = ivec2(
			pixelated_uv * params.raster_size
		);

		color = imageLoad(
			color_image,
			sample_position
		);


		// ------------------------------------------------------------
		// FIRST GAMMA
		// ------------------------------------------------------------

		color.rgb = pow(
			max(color.rgb, vec3(0.0)),
			vec3(gamma_value.x)
		);


		// ------------------------------------------------------------
		// SUBTLE STYLIZED GLOW
		//
		// This isn't a bloom blur. Instead, bright pixels receive
		// a very small luminance boost.
		// ------------------------------------------------------------

		float brightness = max(
			color.r,
			max(color.g, color.b)
		);

		float glow_mask = smoothstep(
			glow_threshold_value,
			1.0,
			brightness
		);

		color.rgb +=
			color.rgb
			* glow_mask
			* glow_strength_value;


		// ------------------------------------------------------------
		// ORDERED 4x4 DITHER
		// ------------------------------------------------------------

		int x = pixel_coord.x & 3;
		int y = pixel_coord.y & 3;

		float dither_value = 0.0;

		if (y == 0) {
			if (x == 0) dither_value = 0.0;
			if (x == 1) dither_value = 8.0;
			if (x == 2) dither_value = 2.0;
			if (x == 3) dither_value = 10.0;
		}

		if (y == 1) {
			if (x == 0) dither_value = 12.0;
			if (x == 1) dither_value = 4.0;
			if (x == 2) dither_value = 14.0;
			if (x == 3) dither_value = 6.0;
		}

		if (y == 2) {
			if (x == 0) dither_value = 3.0;
			if (x == 1) dither_value = 11.0;
			if (x == 2) dither_value = 1.0;
			if (x == 3) dither_value = 9.0;
		}

		if (y == 3) {
			if (x == 0) dither_value = 15.0;
			if (x == 1) dither_value = 7.0;
			if (x == 2) dither_value = 13.0;
			if (x == 3) dither_value = 5.0;
		}

		float dither =
			(dither_value / 16.0 - 0.5)
			* dither_strength_value;


		// ------------------------------------------------------------
		// POSTERIZATION
		// ------------------------------------------------------------

		float grayscale = max(
			color.r,
			max(color.g, color.b)
		);

		// Apply dither before selecting the nearest color level.
		float dithered_grayscale =
			clamp(
				grayscale + dither / levels_value,
				0.0,
				1.0
			);

		float lower =
			floor(
				dithered_grayscale
				* levels_value
			)
			/ levels_value;

		float higher =
			ceil(
				dithered_grayscale
				* levels_value
			)
			/ levels_value;

		float lower_difference =
			abs(
				lower
				- dithered_grayscale
			);

		float higher_difference =
			abs(
				higher
				- dithered_grayscale
			);

		float level =
			lower_difference < higher_difference
			? lower
			: higher;


		// ------------------------------------------------------------
		// PRESERVE ORIGINAL COLOR
		// ------------------------------------------------------------

		float color_adjustment = 0.0;

		if (grayscale > 0.00001) {
			color_adjustment =
				level / grayscale;
		}

		color.rgb *= color_adjustment;


		// ------------------------------------------------------------
		// SECOND GAMMA
		// ------------------------------------------------------------

		color.rgb = pow(
			max(color.rgb, vec3(0.0)),
			vec3(gamma_value.y)
		);

		color.rgb = clamp(
			color.rgb,
			vec3(0.0),
			vec3(1.0)
		);
	""" % [
		pixel_size,
		levels,
		gamma.x,
		gamma.y,
		dither_strength,
		glow_strength,
		glow_threshold
	]


func _render_callback(
	p_effect_callback_type: int,
	p_render_data: RenderData
) -> void:

	if (
		rd
		and
		p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
		and
		_check_shader()
	):
		var render_scene_buffers: RenderSceneBuffersRD = (
			p_render_data.get_render_scene_buffers()
		)

		if render_scene_buffers == null:
			return

		var size := render_scene_buffers.get_internal_size()

		if size.x == 0 or size.y == 0:
			return

		var x_groups := ceili(size.x / 8.0)
		var y_groups := ceili(size.y / 8.0)
		var z_groups := 1

		var push_constant := PackedFloat32Array()

		push_constant.push_back(size.x)
		push_constant.push_back(size.y)
		push_constant.push_back(0.0)
		push_constant.push_back(0.0)

		var view_count := render_scene_buffers.get_view_count()

		for view in range(view_count):

			var input_image := (
				render_scene_buffers.get_color_layer(view)
			)

			var uniform := RDUniform.new()

			uniform.uniform_type = (
				RenderingDevice.UNIFORM_TYPE_IMAGE
			)

			uniform.binding = 0
			uniform.add_id(input_image)

			var uniform_set := (
				UniformSetCacheRD.get_cache(
					shader,
					0,
					[uniform]
				)
			)

			var compute_list := rd.compute_list_begin()

			rd.compute_list_bind_compute_pipeline(
				compute_list,
				pipeline
			)

			rd.compute_list_bind_uniform_set(
				compute_list,
				uniform_set,
				0
			)

			rd.compute_list_set_push_constant(
				compute_list,
				push_constant.to_byte_array(),
				push_constant.size() * 4
			)

			rd.compute_list_dispatch(
				compute_list,
				x_groups,
				y_groups,
				z_groups
			)

			rd.compute_list_end()
