package brender
import "base:runtime"
import vk "vendor:vulkan"
import bwindow "../window"

Surface :: struct {
	window:  ^bwindow.Window,
	surface: vk.SurfaceKHR,
}

Surface_Capabilities :: struct {
	caps:          vk.SurfaceCapabilitiesKHR,
	formats:       []vk.SurfaceFormatKHR,
	present_modes: []vk.PresentModeKHR,
	allocator:     runtime.Allocator,
}

@(require_results)
surface_init :: proc(surface: ^Surface, instance: Instance, window: ^bwindow.Window) -> vk.Result {
	surface.window = window
	surface.surface = bwindow.create_surface(window, instance.handle) or_return
	return nil
}

surface_destroy :: proc(surface: ^Surface, instance: Instance) {
	if surface.surface != 0 {
		vk.DestroySurfaceKHR(instance.handle, surface.surface, nil)
	}
	surface^ = {}
}

@(require_results)
surface_is_ready :: proc(surface: Surface) -> bool {
	width, height := bwindow.get_framebuffer_size(surface.window)
	return width != 0 || height != 0
}

@(require_results)
surface_should_resize :: proc(surface: Surface) -> bool {
	return surface.window.resized
}

surface_query_capabilities :: proc(
	surface: Surface,
	device: Device,
	allocator := context.temp_allocator,
) -> (
	caps: Surface_Capabilities,
	result: vk.Result,
) {
	caps.allocator = allocator
	defer if result != .SUCCESS {
		surface_capabilities_destroy(&caps)
	}

	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
		device.physical,
		surface.surface,
		&caps.caps,
	) or_return

	present_mode_count: u32
	vk.GetPhysicalDeviceSurfacePresentModesKHR(
		device.physical,
		surface.surface,
		&present_mode_count,
		nil,
	) or_return

	caps.present_modes = make([]vk.PresentModeKHR, present_mode_count, allocator)
	vk.GetPhysicalDeviceSurfacePresentModesKHR(
		device.physical,
		surface.surface,
		&present_mode_count,
		raw_data(caps.present_modes),
	) or_return

	format_count: u32
	vk.GetPhysicalDeviceSurfaceFormatsKHR(
		device.physical,
		surface.surface,
		&format_count,
		nil,
	) or_return

	caps.formats = make([]vk.SurfaceFormatKHR, format_count, allocator)
	vk.GetPhysicalDeviceSurfaceFormatsKHR(
		device.physical,
		surface.surface,
		&format_count,
		raw_data(caps.formats),
	) or_return

	return
}

surface_capabilities_destroy :: proc(caps: ^Surface_Capabilities) {
	delete(caps.present_modes, caps.allocator)
	delete(caps.formats, caps.allocator)
	caps^ = {}
}
