package brender
import "../math"

Clear_Color :: distinct [4]f32

Mesh_3D :: struct {
	mesh:     Mesh_Handle,
	material: Material_Handle,
}

Ambient_Light :: struct {
	illuminance: f32,
	color:       [3]f32,
}

Point_Light :: struct {
	radius: f32,
	power:  f32,
	color:  [3]f32,
}

Directional_Light :: struct {
	illuminance: f32,
	color:       [3]f32,
}

Camera :: struct {
	projection: math.Projection,
}

get_world_to_clip_matrix :: proc(
	camera: Camera,
	transform: math.Transform,
	width, height: int,
) -> matrix[4, 4]f32 {
	return(
		math.get_view_to_clip_matrix(camera.projection, width, height) *
		math.transform_to_view_matrix(transform) \
	)
}
