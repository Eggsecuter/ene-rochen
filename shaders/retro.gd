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
		vec2 gamma_value = vec2(%.6f, %.6f);

		// Current pixel -> normalized screen UV.
		vec2 screen_uv = vec2(pixel_coord) / params.raster_size;

		// Pixelate the screen.
		vec2 pixel_count = params.raster_size / pixel_size_value;

		vec2 pixelated_uv =
			floor(screen_uv * pixel_count) / pixel_count;

		ivec2 sample_position = ivec2(
			pixelated_uv * params.raster_size
		);

		// Read the pixelated pixel.
		color = imageLoad(
			color_image,
			sample_position
		);

		// First gamma adjustment.
		color.rgb = pow(
			max(color.rgb, vec3(0.0)),
			vec3(gamma_value.x)
		);

		// Posterize based on the brightest RGB channel.
		float grayscale = max(
			color.r,
			max(color.g, color.b)
		);

		float lower =
			floor(grayscale * levels_value)
			/ levels_value;

		float higher =
			ceil(grayscale * levels_value)
			/ levels_value;

		float lower_difference =
			abs(lower - grayscale);

		float higher_difference =
			abs(higher - grayscale);

		float level =
			lower_difference < higher_difference
			? lower
			: higher;

		float color_adjustment = 0.0;

		// Avoid division by zero for black pixels.
		if (grayscale > 0.00001) {
			color_adjustment =
				level / grayscale;
		}

		color.rgb *= color_adjustment;

		// Second gamma adjustment.
		color.rgb = pow(
			max(color.rgb, vec3(0.0)),
			vec3(gamma_value.y)
		);
	""" % [
		pixel_size,
		levels,
		gamma.x,
		gamma.y
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

		var x_groups := (size.x - 1) / 8 + 1
		var y_groups := (size.y - 1) / 8 + 1
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
