package bimage
import "base:runtime"
import "core:math"
import "core:mem"
import "core:slice"
import "core:strings"
import stbi "vendor:stb/image"

Image :: struct {
	width:     int,
	height:    int,
	bytes:     []byte,
	format:    Format,
	allocator: runtime.Allocator,
}

Format :: enum {
	R_U8,
	Rg_U8,
	Rgba_U8,
	R_F16,
	Rg_F16,
	Rgba_F16,
}

Load_Error :: enum {
	None = 0,
	Invalid_Or_Nonexistent_File,
}

Error :: union #shared_nil {
	Load_Error,
	runtime.Allocator_Error,
}

make_empty :: proc(
	width, height: int,
	format: Format,
	allocator := context.allocator,
) -> (
	image: Image,
	err: runtime.Allocator_Error,
) {
	image.format = format
	image.width = width
	image.height = height
	image.allocator = allocator
	image.bytes = make([]byte, width * height * get_format_texel_size(format), allocator) or_return
	return
}

destroy :: proc(image: ^Image) {
	delete(image.bytes, image.allocator)
	image^ = {}
}

load_from_file :: proc(
	filename: string,
	allocator := context.allocator,
) -> (
	image: Image,
	err: Error,
) {
	cfilename := strings.clone_to_cstring(filename)
	defer delete(cfilename)

	width, height, components: i32
	if stbi.info(cfilename, &width, &height, &components) == 0 {
		return {}, Load_Error.Invalid_Or_Nonexistent_File
	}

	if components == 3 {
		components = 4
	}

	is_hdr := stbi.is_hdr(cfilename) != 0
	format: Format
	if is_hdr {
		switch components {
		case 1:
			format = .R_F16
		case 2:
			format = .Rg_F16
		case 4:
			format = .Rgba_F16
		case:
			unreachable()
		}
	} else {
		switch components {
		case 1:
			format = .R_U8
		case 2:
			format = .Rg_U8
		case 4:
			format = .Rgba_U8
		case:
			unreachable()
		}
	}

	image = make_empty(int(width), int(height), format, allocator) or_return
	defer if err != nil {
		destroy(&image)
	}

	if is_hdr {
		loaded_values := stbi.loadf(cfilename, &width, &height, nil, components)
		if loaded_values == nil {
			err = Load_Error.Invalid_Or_Nonexistent_File
			return
		}

		values := slice.reinterpret([]f16, image.bytes)
		for i in 0 ..< len(values) {
			values[i] = f16(clamp(loaded_values[i], -65504, 65504))
		}

		stbi.image_free(loaded_values)
	} else {
		loaded_values := stbi.load(cfilename, &width, &height, nil, components)
		if loaded_values == nil {
			err = Load_Error.Invalid_Or_Nonexistent_File
			return
		}

		mem.copy(raw_data(image.bytes), loaded_values, len(image.bytes))
		stbi.image_free(loaded_values)
	}

	return image, nil
}

@(require_results)
get_pixels :: proc($T: typeid, image: ^Image) -> []T {
	assert(size_of(T) == get_format_texel_size(image.format))
	return slice.reinterpret([]T, image.bytes)
}

@(require_results)
get_max_mip_levels :: proc(image: Image) -> int {
	return int(math.floor(math.log2(f32(max(image.width, image.height))))) + 1
}

@(require_results)
is_valid :: proc(image: Image) -> bool {
	return(
		image.width > 0 &&
		image.height > 0 &&
		len(image.bytes) == image.width * image.height * get_format_texel_size(image.format) \
	)
}

get_format_texel_size :: proc(fmt: Format) -> int {
	switch fmt {
	case .R_U8:
		return 1
	case .Rg_U8:
		return 2
	case .Rgba_U8:
		return 4
	case .R_F16:
		return 2
	case .Rg_F16:
		return 4
	case .Rgba_F16:
		return 8
	}
	unreachable()
}
