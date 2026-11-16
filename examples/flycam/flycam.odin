package flycam_example
import "../../basalt"
@(require) import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
@(require) import "core:mem"
import "core:os"
import "core:time"

Controls :: struct {
	walk_forward:      basalt.Key,
	walk_backward:     basalt.Key,
	walk_right:        basalt.Key,
	walk_left:         basalt.Key,
	go_up:             basalt.Key,
	go_down:           basalt.Key,
	boost:             basalt.Key,
	zoom_amount:       f32,
	mouse_sensitivity: f32,
}

Fly_Camera :: struct {
	position:         [3]f32,
	velocity:         [3]f32,
	yaw, pitch:       f32,
	base_fov_radians: f32,
	target_zoom:      f32,
	zoom:             f32,
	damp:             f32,
	boost:            f32,
	speed:            f32,
	zoom_speed:       f32,
}

main :: proc() {
	context.logger = log.create_console_logger(opt = {.Level, .Terminal_Color})
	defer log.destroy_console_logger(context.logger)

	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	window, window_err := basalt.window_create(1280, 720, "window")
	if window_err != nil {
		os.exit(1)
	}
	defer basalt.window_destroy(window)

	renderer, renderer_err := basalt.renderer_create(window)
	if renderer_err != nil {
		os.exit(1)
	}
	defer basalt.renderer_destroy(renderer)

	basalt.window_set_cursor_state(window, .Disabled)

	scene: basalt.Scene
	basalt.scene_init(&scene)
	defer basalt.scene_destroy(&scene)

	scene.clear_color = {0.3, 0.6, 1.0, 1.0}
	scene.ambient_light.color = {0.3, 0.6, 1.0}

	append(
		&scene.directional_lights,
		{direction = {0.4, -1.0, 0.2}, color = {1.0, 1.0, 1.0}, illuminance = 2.0},
	)

	append(
		&scene.point_lights,
		{position = {0.0, 0.0, 0.0}, color = {1.0, 1.0, 0.5}, power = 200.0, radius = 15.0},
	)

	cube := basalt.make_cube(allocator = context.temp_allocator)
	cube_mesh, cube_err := basalt.renderer_add_mesh(renderer, cube)
	if cube_err != nil {
		log.error("Failed to create cube mesh")
	}

	ball := basalt.make_sphere(allocator = context.temp_allocator)
	ball_mesh, ball_err := basalt.renderer_add_mesh(renderer, ball)
	if ball_err != nil {
		log.error("Failed to create ball mesh")
	}

	rocks_texture: basalt.Texture_Handle
	if image, image_err := basalt.image_load_from_file("assets/rocksalbedo.jpg"); image_err == nil {
		rocks_texture, _ = basalt.renderer_add_texture(renderer, image)
		basalt.image_destroy(&image)
	} else {
		log.errorf("Failed to load texture: %v", image_err)
	}

	rocks_normal_map: basalt.Texture_Handle
	if image, image_err := basalt.image_load_from_file("assets/rocksnormal.jpg"); image_err == nil {
		rocks_normal_map, _ = basalt.renderer_add_texture(renderer, image, {colorspace = .Linear})
		basalt.image_destroy(&image)
	} else {
		log.errorf("Failed to load texture: %v", image_err)
	}

	rocks_material, _ := basalt.renderer_add_material(
		renderer,
		basalt.Lambert_Material {
			base_color_factor = {1.0, 1.0, 1.0, 1.0},
			base_color_texture = rocks_texture,
			normal_map = rocks_normal_map,
			sampler = .Linear_Repeat,
		},
	)

	ball_material, _ := basalt.renderer_add_material(
		renderer,
		basalt.Unlit_Material{color_factor = {1.0, 1.0, 0.5}, sampler = .Linear_Repeat},
		basalt.Material_Properties{double_sided = true},
	)

	rows := 10
	columns := 10
	spacing := f32(3.0)
	for i in 0 ..< rows {
		for j in 0 ..< columns {
			append(
				&scene.mesh_objects,
				{
					transform = basalt.affine_make(
						{
							(f32(i) - f32(rows) * 0.5 + 0.5) * spacing,
							-2.0,
							(f32(j) - f32(columns) * 0.5 + 0.5) * spacing,
						},
					),
					mesh = cube_mesh if (i + j) % 2 == 0 else ball_mesh,
					material = rocks_material if (i + j) % 2 == 0 else ball_material,
				},
			)
		}
	}

	flycam := default_flycam()
	controls := default_controls()
	perf := basalt.perf_make()
	defer basalt.perf_destroy(&perf)

	current_time := time.tick_now()
	for !basalt.window_should_close(window) {
		delta_time := f32(time.duration_seconds(time.tick_since(current_time)))
		current_time = time.tick_now()

		basalt.perf_start_frame(&perf)
		basalt.poll_window_events(window)

		if stats, ok := basalt.perf_collect_stats_after(&perf, 1.0); ok {
			log.infof(
				"FPS: %v, avg. frame time: %.02fms, median: %.02fms, low 1%%: %.02fms, low 0.1%%: %.02fms",
				int(stats.frames_per_second),
				time.duration_milliseconds(stats.average_frame_time),
				time.duration_milliseconds(stats.median_frame_time),
				time.duration_milliseconds(stats.low_1pct_frame_time),
				time.duration_milliseconds(stats.low_0_1pct_frame_time),
			)
		}

		cursor_state := basalt.window_get_cursor_state(window)
		if (.Just_Pressed in basalt.get_mouse_button(window, .Left) && cursor_state == .Normal) ||
		   .Just_Pressed in basalt.get_key(window, .Escape) {
			#partial switch cursor_state {
			case .Normal:
				cursor_state = .Disabled
			case .Disabled:
				cursor_state = .Normal
			case:
				cursor_state = .Disabled
			}
			basalt.window_set_cursor_state(window, cursor_state)
		}

		if cursor_state == .Disabled {
			look_around(&flycam, window, controls)
			walk_around(&flycam, window, controls, delta_time)
			zoom(&flycam, window, controls)
			update_flycam(&flycam, delta_time)
		}

		update_camera(&scene.camera, flycam)

		if err := basalt.renderer_draw(renderer, scene); err != nil {
			log.errorf("Renderer draw error: %v", err)
			os.exit(1)
		}

		free_all(context.temp_allocator)
	}
}

look_around :: proc(flycam: ^Fly_Camera, window: ^basalt.Window, controls: Controls) {
	flycam.yaw += f32(window.cursor_delta.x) * controls.mouse_sensitivity
	flycam.pitch += f32(window.cursor_delta.y) * controls.mouse_sensitivity
	flycam.pitch = clamp(flycam.pitch, -1.56, 1.56)
}

walk_around :: proc(flycam: ^Fly_Camera, window: ^basalt.Window, controls: Controls, dt: f32) {
	right := [3]f32{math.cos(flycam.yaw), 0.0, -math.sin(flycam.yaw)}
	front := [3]f32{math.sin(flycam.yaw), 0.0, math.cos(flycam.yaw)}

	wish := [3]f32{0.0, 0.0, 0.0}
	if .Pressed in basalt.get_key(window, controls.walk_forward) {
		wish += front
	}
	if .Pressed in basalt.get_key(window, controls.walk_backward) {
		wish -= front
	}
	if .Pressed in basalt.get_key(window, controls.walk_left) {
		wish -= right
	}
	if .Pressed in basalt.get_key(window, controls.walk_right) {
		wish += right
	}
	if .Pressed in basalt.get_key(window, controls.go_up) {
		wish.y += 1.0
	}
	if .Pressed in basalt.get_key(window, controls.go_down) {
		wish.y -= 1.0
	}

	wish = linalg.normalize0(wish)
	speed := flycam.speed
	if .Pressed in basalt.get_key(window, controls.boost) {
		speed *= flycam.boost
	}

	flycam.velocity += (wish * speed - flycam.velocity) * (1 - math.exp(-flycam.damp * dt))
}

zoom :: proc(flycam: ^Fly_Camera, window: ^basalt.Window, controls: Controls) {
	flycam.target_zoom += controls.zoom_amount * f32(window.scroll_delta.y)
}

update_flycam :: proc(flycam: ^Fly_Camera, dt: f32) {
	flycam.position += flycam.velocity * dt
	flycam.zoom = linalg.lerp(flycam.zoom, flycam.target_zoom, min(flycam.zoom_speed * dt, 1.0))
}

update_camera :: proc(camera: ^basalt.Camera, flycam: Fly_Camera) {
	camera.transform.translation = flycam.position
	camera.transform.rotation = linalg.quaternion_from_euler_angles(
		flycam.yaw,
		flycam.pitch,
		0.0,
		.YXZ,
	)
	switch &p in camera.projection {
	case basalt.Orthographic_Projection:
	case basalt.Perspective_Projection:
		fov := 2 * math.atan(math.tan(flycam.base_fov_radians * 0.5) / math.exp(flycam.zoom))
		max_fov := math.to_radians_f32(140.0)
		p.fov_radians = min(fov, max_fov)
	}
}

default_flycam :: proc() -> Fly_Camera {
	return {
		base_fov_radians = math.to_radians_f32(90.0),
		zoom_speed = 10.0,
		boost = 1.5,
		speed = 4.0,
		damp = 15.0,
	}
}

default_controls :: proc() -> Controls {
	return {
		walk_forward = .W,
		walk_backward = .S,
		walk_left = .A,
		walk_right = .D,
		go_up = .Space,
		go_down = .Left_Control,
		boost = .Left_Shift,
		zoom_amount = 0.1,
		mouse_sensitivity = 0.002,
	}
}
