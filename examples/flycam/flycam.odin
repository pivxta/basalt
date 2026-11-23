package flycam_example
import brender "../../render"
import bwindow "../../window"
import binput "../../input"
import becs "../../ecs"
import bmath "../../math"
import bperf "../../perf"
import bimage "../../image"
import bmesh "../../mesh"
@(require) import "core:fmt"
@(require) import "core:mem"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:time"

Fly_Camera_Controls :: struct {
	walk_forward:      binput.Key,
	walk_backward:     binput.Key,
	walk_right:        binput.Key,
	walk_left:         binput.Key,
	go_up:             binput.Key,
	go_down:           binput.Key,
	boost:             binput.Key,
	zoom_amount:       f32,
	mouse_sensitivity: f32,
}

Fly_Camera :: struct {
	velocity:         [3]f32,
	yaw, pitch:       f32,
	target_zoom:      f32,
	zoom:             f32,
	options:          Fly_Camera_Options,	
}

Fly_Camera_Options :: struct {
	base_fov_radians: f32,
	damp:             f32,
	boost:            f32,
	speed:            f32,
	zoom_speed:       f32,
}

ROCKS_ALBEDO_PATH :: "examples/flycam/assets/rocksalbedo.jpg"
ROCKS_NORMAL_PATH :: "examples/flycam/assets/rocksnormal.jpg"

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

	window, window_err := bwindow.create(1280, 720, "window")
	if window_err != nil {
		os.exit(1)
	}
	defer bwindow.destroy(window)
	bwindow.set_cursor_state(window, .Disabled)

	renderer, renderer_err := brender.create_renderer(window)
	if renderer_err != nil {
		os.exit(1)
	}
	defer brender.destroy_renderer(renderer)

	cube := bmesh.make_cube(allocator = context.temp_allocator)
	cube_mesh, cube_err := brender.add_mesh(renderer, cube)
	if cube_err != nil {
		log.error("Failed to create cube mesh")
	}

	ball := bmesh.make_sphere(allocator = context.temp_allocator)
	ball_mesh, ball_err := brender.add_mesh(renderer, ball)
	if ball_err != nil {
		log.error("Failed to create ball mesh")
	}

	rocks_texture: brender.Texture_Handle
	if image, image_err := bimage.load_from_file(ROCKS_ALBEDO_PATH); image_err == nil {
		rocks_texture, _ = brender.add_texture(renderer, image)
		bimage.destroy(&image)
	} else {
		log.errorf("Failed to load texture: %v", image_err)
	}

	rocks_normal_map: brender.Texture_Handle
	if image, image_err := bimage.load_from_file(ROCKS_NORMAL_PATH); image_err == nil {
		rocks_normal_map, _ = brender.add_texture(renderer, image, {colorspace = .Linear})
		bimage.destroy(&image)
	} else {
		log.errorf("Failed to load texture: %v", image_err)
	}

	rocks_material, _ := brender.add_material(
		renderer,
		brender.Lambert_Material {
			base_color_factor = {1.0, 1.0, 1.0, 1.0},
			base_color_texture = rocks_texture,
			normal_map = rocks_normal_map,
			sampler = .Linear_Repeat,
		},
	)

	ball_material, _ := brender.add_material(
		renderer,
		brender.Unlit_Material{color_factor = {1.0, 1.0, 0.5}, sampler = .Linear_Repeat},
		brender.Material_Properties{double_sided = true},
	)

	world := becs.create_world()
	defer becs.destroy_world(world)

	becs.insert_resource(world, default_flycam_controls())
	becs.insert_resource(world, brender.Clear_Color({0.3, 0.6, 1.0, 1.0}))
	becs.spawn(
		world, 
		bmath.TRANSFORM_IDENTITY,
		brender.Camera{}, 
		Fly_Camera{options = default_flycam_options()},
	)
	becs.spawn(world, brender.Ambient_Light {
		color = {0.3, 0.6, 1.0},
		illuminance = 1.0,
	})
	becs.spawn(
		world, 
		bmath.transform_look_to({}, {0.4, -1.0, 0.2}),
		brender.Directional_Light {
			color = {1.0, 1.0, 1.0}, 
			illuminance = 2.0,
		},
	)
	becs.spawn(
		world,
		bmath.transform_make(translation = {0.0, 0.0, 0.0}),
		brender.Point_Light{color = {1.0, 1.0, 0.5}, power = 200.0, radius = 15.0},
	)

	rows := 10
	columns := 10
	spacing := f32(3.0)
	for i in 0 ..< rows {
		for j in 0 ..< columns {
			pos := [3]f32 {
				(f32(i) - f32(rows) * 0.5 + 0.5) * spacing,
				-2.0,
				(f32(j) - f32(columns) * 0.5 + 0.5) * spacing,
			}

			becs.spawn(
				world,
				bmath.transform_make(pos),
				brender.Mesh_3D {
					mesh = cube_mesh if (i + j) % 2 == 0 else ball_mesh,
					material = rocks_material if (i + j) % 2 == 0 else ball_material,
				},
			)
		}
	}

	input := binput.create(window)
	defer binput.destroy(input)
	tracker := bperf.make_tracker()
	defer bperf.destroy_tracker(&tracker)

	current_time := time.tick_now()
	for !bwindow.should_close(window) {
		delta_time := f32(time.duration_seconds(time.tick_since(current_time)))
		current_time = time.tick_now()

		bperf.start_frame(&tracker)
		bwindow.poll_events(window)

		if stats, ok := bperf.collect_stats_after(&tracker, 1.0); ok {
			log.infof(
				"FPS: %v, avg. frame time: %.02fms, median: %.02fms, low 1%%: %.02fms, low 0.1%%: %.02fms",
				int(stats.frames_per_second),
				time.duration_milliseconds(stats.average_frame_time),
				time.duration_milliseconds(stats.median_frame_time),
				time.duration_milliseconds(stats.low_1pct_frame_time),
				time.duration_milliseconds(stats.low_0_1pct_frame_time),
			)
		}

		state := bwindow.get_cursor_state(window)
		if (.Just_Pressed in binput.get_mouse_button(input, .Left) && state == .Normal) ||
		   .Just_Pressed in binput.get_key(input, .Escape) {
			#partial switch state {
			case .Normal:
				state = .Disabled
			case .Disabled:
				state = .Normal
			case:
				state = .Disabled
			}
			bwindow.set_cursor_state(window, state)
		}

		if state == .Disabled {
			control_flycam(world, input, delta_time)
			update_flycam(world, delta_time)
			update_camera(world)
		}

		if err := brender.draw(renderer, world); err != nil {
			log.errorf("Renderer draw error: %v", err)
			os.exit(1)
		}

		free_all(context.temp_allocator)
	}
}

control_flycam :: proc(world: ^becs.World, input: ^binput.Input, dt: f32) {
	default_controls := default_flycam_controls()
	controls := becs.get_resource(world, Fly_Camera_Controls) or_else &default_controls
	flycam, transform, _, err := becs.query_single(world, Fly_Camera, bmath.Transform)
	if err != nil {
		return
	}

	// Walk around
	right := bmath.transform_right(transform^)
	front := bmath.transform_forward(transform^)
	front.y = 0.0

	wish := [3]f32{0.0, 0.0, 0.0}
	if .Pressed in binput.get_key(input, controls.walk_forward) {
		wish += front
	}
	if .Pressed in binput.get_key(input, controls.walk_backward) {
		wish -= front
	}
	if .Pressed in binput.get_key(input, controls.walk_left) {
		wish -= right
	}
	if .Pressed in binput.get_key(input, controls.walk_right) {
		wish += right
	}
	if .Pressed in binput.get_key(input, controls.go_up) {
		wish.y += 1.0
	}
	if .Pressed in binput.get_key(input, controls.go_down) {
		wish.y -= 1.0
	}

	wish = linalg.normalize0(wish)
	speed := flycam.options.speed
	if .Pressed in binput.get_key(input, controls.boost) {
		speed *= flycam.options.boost
	}

	flycam.velocity += (wish * speed - flycam.velocity) * (1 - math.exp(-flycam.options.damp * dt))

	// Look around and zoom
	flycam.yaw -= f32(input.cursor_delta.x) * controls.mouse_sensitivity
	flycam.pitch -= f32(input.cursor_delta.y) * controls.mouse_sensitivity
	flycam.pitch = clamp(flycam.pitch, -1.56, 1.56)
	flycam.target_zoom += controls.zoom_amount * f32(input.scroll_delta.y)
}

update_flycam :: proc(world: ^becs.World, dt: f32) {
	flycam, transform, _, err := becs.query_single(world, Fly_Camera, bmath.Transform)
	if err != nil {
		return
	}

	transform.translation += flycam.velocity * dt
	flycam.zoom = linalg.lerp(flycam.zoom, flycam.target_zoom, min(flycam.options.zoom_speed * dt, 1.0))
}

update_camera :: proc(world: ^becs.World) {
	flycam, camera, transform, _, err := becs.query_single(
		world, 
		Fly_Camera, 
		brender.Camera, 
		bmath.Transform,
	)
	if err != nil {
		return
	}

	transform.rotation = linalg.quaternion_from_euler_angles(
		flycam.yaw,
		flycam.pitch,
		0.0,
		.YXZ,
	)

	switch &p in camera.projection {
	case bmath.Orthographic_Projection:
	case bmath.Perspective_Projection:
		fov := 2 * math.atan(math.tan(flycam.options.base_fov_radians * 0.5) / math.exp(flycam.zoom))
		max_fov := math.to_radians_f32(140.0)
		p.fov_radians = min(fov, max_fov)
	}
}

default_flycam_options :: proc() -> Fly_Camera_Options {
	return {
		base_fov_radians = math.to_radians_f32(90.0),
		zoom_speed = 10.0,
		boost = 1.5,
		speed = 4.0,
		damp = 15.0,
	}
}

default_flycam_controls :: proc() -> Fly_Camera_Controls {
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
