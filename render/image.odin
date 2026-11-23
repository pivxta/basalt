package brender
import bimage "../image"
import vk "vendor:vulkan"

image_format_matches_vk :: proc(fmt: bimage.Format, vkfmt: vk.Format) -> bool {
	#partial switch vkfmt {
	case .R8_UNORM, .R8_SRGB, .R8_UINT:
		return fmt == .R_U8
	case .R8G8_UNORM, .R8G8_SRGB, .R8G8_UINT:
		return fmt == .Rg_U8
	case .R8G8B8A8_UNORM, .R8G8B8A8_SRGB, .R8G8B8A8_UINT:
		return fmt == .Rgba_U8
	case .R16_SFLOAT:
		return fmt == .R_F16
	case .R16G16_SFLOAT:
		return fmt == .Rg_F16
	case .R16G16B16A16_SFLOAT:
		return fmt == .Rgba_F16
	case:
		return false
	}
}

image_format_to_vk :: proc(fmt: bimage.Format, colorspace: Texture_Colorspace) -> vk.Format {
	switch colorspace {
	case .Srgb:
		switch fmt {
		case .R_U8:
			return .R8_UNORM
		case .Rg_U8:
			return .R8G8_UNORM
		case .Rgba_U8:
			return .R8G8B8A8_SRGB
		case .R_F16:
			return .R16_SFLOAT
		case .Rg_F16:
			return .R16G16_SFLOAT
		case .Rgba_F16:
			return .R16G16B16A16_SFLOAT
		}
	case .Linear:
		switch fmt {
		case .R_U8:
			return .R8_UNORM
		case .Rg_U8:
			return .R8G8_UNORM
		case .Rgba_U8:
			return .R8G8B8A8_UNORM
		case .R_F16:
			return .R16_SFLOAT
		case .Rg_F16:
			return .R16G16_SFLOAT
		case .Rgba_F16:
			return .R16G16B16A16_SFLOAT
		}
	}
	unreachable()
}
