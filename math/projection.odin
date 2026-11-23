package bmath
import "core:math"

Projection :: union #no_nil {
	Perspective_Projection,
	Orthographic_Projection,
}

Perspective_Projection :: struct {
	fov_radians: Maybe(f32),
	near:        Maybe(f32),
	far:         Maybe(f32),
}

Orthographic_Projection :: struct {
	scale: Maybe(f32),
	near:  Maybe(f32),
	far:   Maybe(f32),
}

get_view_to_clip_matrix :: proc(
	projection: Projection,
	width: int,
	height: int,
) -> matrix[4, 4]f32 {
	aspect := f32(width) / f32(height) if height != 0 else 0

	transform: matrix[4, 4]f32
	switch p in projection {
	case Perspective_Projection:
		transform = matrix4_perspective_reverse_z_infinite(
			fovy = p.fov_radians.? or_else math.to_radians_f32(90.0),
			near = p.near.? or_else 0.001,
			aspect = aspect,
		)
	case Orthographic_Projection:
		scale := p.scale.? or_else 1.0
		near := p.near.? or_else 0.001
		far := p.far.? or_else 1000.0
		transform = matrix4_orthographic_reverse_z(
			left = -0.5 * aspect * scale,
			right = 0.5 * aspect * scale,
			top = 0.5 * scale,
			bottom = -0.5 * scale,
			near = near,
			far = far,
		)
	}

	return transform
}

@(private = "file")
matrix4_perspective_reverse_z_infinite :: proc(fovy, aspect, near: f32) -> matrix[4, 4]f32 {
	tan_half_fovy := math.tan(0.5 * fovy)
	m: matrix[4, 4]f32
	m[0, 0] = 1 / (aspect * tan_half_fovy)
	m[1, 1] = -1 / tan_half_fovy
	m[2, 3] = near
	m[3, 2] = -1
	return m
}

@(private = "file")
matrix4_orthographic_reverse_z :: proc(
	left, right, bottom, top, near, far: f32,
) -> matrix[4, 4]f32 {
	m: matrix[4, 4]f32
	m[0, 0] = 2 / (right - left)
	m[0, 3] = -(right + left) / (right - left)
	m[1, 1] = -2 / (top - bottom)
	m[1, 3] = (top + bottom) / (top - bottom)
	m[2, 2] = 1 / (far - near)
	m[2, 3] = far / (far - near)
	m[3, 3] = 1
	return m
}
