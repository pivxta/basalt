package bmath
import "core:math/linalg"

TRANSFORM_IDENTITY :: Transform {
	scale    = 1,
	rotation = 1,
}

AXIS_X :: [3]f32{1, 0, 0} 
AXIS_Y :: [3]f32{0, 1, 0} 
AXIS_Z :: [3]f32{0, 0, 1}

Transform :: struct {
	scale:       [3]f32,
	rotation:    quaternion128,
	translation: [3]f32,
}

transform_right :: proc(t: Transform) -> [3]f32 {
	return linalg.quaternion_mul_vector3(t.rotation, AXIS_X)
}

transform_up :: proc(t: Transform) -> [3]f32 {
	return linalg.quaternion_mul_vector3(t.rotation, AXIS_Y)
}

transform_backward :: proc(t: Transform) -> [3]f32 {
	return linalg.quaternion_mul_vector3(t.rotation, AXIS_Z)
}

transform_left :: proc(t: Transform) -> [3]f32 {
	return -transform_right(t)
}

transform_down :: proc(t: Transform) -> [3]f32 {
	return -transform_up(t)
}

transform_forward :: proc(t: Transform) -> [3]f32 {
	return -transform_backward(t)
}

transform_axes :: proc(t: Transform) -> (right, up, forward: [3]f32) {
	return transform_right(t), transform_up(t), transform_forward(t)
}

transform_make :: proc(
	translation := [3]f32{},
	rotation := quaternion128(1),
	scale: f32 = 1,
) -> Transform {
	return {scale = scale, rotation = rotation, translation = translation}
}

transform_look_at :: proc(eye, target: [3]f32, up := [3]f32{0, 1, 0}) -> Transform {
	return {
		scale = 1,
		rotation = linalg.quaternion_look_at(eye, target, up),
		translation = eye,
	}
}

transform_look_to :: proc(eye, direction: [3]f32, up := [3]f32{0, 1, 0}) -> Transform {
	return transform_look_at(eye, eye + direction, up)
}

transform_mul :: proc(a, b: Transform) -> Transform {
	return {
		scale = a.scale * b.scale,
		rotation = a.rotation * b.rotation,
		translation = a.translation +
		a.scale * linalg.quaternion_mul_vector3(a.rotation, b.translation),
	}
}

transform_inverse :: proc(t: Transform) -> Transform {
	inv_scale := 1 / t.scale
	inv_rotation := conj(t.rotation)
	return {
		scale = inv_scale,
		rotation = inv_rotation,
		translation = -inv_scale * linalg.quaternion_mul_vector3(inv_rotation, t.translation),
	}
}

transform_point :: proc(t: Transform, p: [3]f32) -> [3]f32 {
	return linalg.quaternion_mul_vector3(t.rotation, p * t.scale) + t.translation
}

transform_vector :: proc(t: Transform, v: [3]f32) -> [3]f32 {
	return linalg.quaternion_mul_vector3(t.rotation, v * t.scale)
}

transform_to_matrix3x4 :: proc(t: Transform) -> matrix[3, 4]f32 {
	full := transform_to_matrix(t)

	m: matrix[3, 4]f32
	for row in 0 ..< 3 {
		for col in 0 ..< 4 {
			m[row, col] = full[row, col]
		}
	}

	return m
}

transform_to_matrix :: proc(t: Transform) -> matrix[4, 4]f32 {
	return linalg.matrix4_from_trs(t.translation, t.rotation, t.scale)
}

transform_to_view_matrix :: proc(camera: Transform) -> matrix[4, 4]f32 {
	return transform_to_matrix(transform_inverse(camera))
}

transform_lerp :: proc(a, b: Transform, t: f32) -> Transform {
	return {
		scale = a.scale + (b.scale - a.scale) * t,
		rotation = linalg.quaternion_slerp(a.rotation, b.rotation, t),
		translation = a.translation + (b.translation - a.translation) * t,
	}
}

transform_normalized :: proc(t: Transform) -> Transform {
	result := t
	result.rotation = linalg.quaternion_normalize(t.rotation)
	return result
}
