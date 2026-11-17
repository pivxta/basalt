package basalt
import "base:runtime"
import vk "vendor:vulkan"

Swapchain :: struct {
	handle:                 vk.SwapchainKHR,
	textures:               []Texture,
	presentable_semaphores: []vk.Semaphore,
	extent:                 vk.Extent2D,
	format:                 vk.Format,
	colorspace:             vk.ColorSpaceKHR,
	allocator:              runtime.Allocator,
}

Swapchain_Texture :: struct {
	index:       u32,
	texture:     ^Texture,
	presentable: vk.Semaphore,
}

Swapchain_Configure_Error :: enum {
	None = 0,
	No_Surface_Formats,
	No_Present_Modes,
}

Swapchain_Error :: union #shared_nil {
	Swapchain_Configure_Error,
	Texture_Error,
	vk.Result,
}

swapchain_destroy :: proc(swapchain: ^Swapchain, device: Device) {
	for &texture in swapchain.textures {
		texture_destroy(&texture, device)
	}

	for semaphore in swapchain.presentable_semaphores {
		if semaphore != 0 {
			vk.DestroySemaphore(device.logical, semaphore, nil)
		}
	}

	if swapchain.handle != 0 {
		vk.DestroySwapchainKHR(device.logical, swapchain.handle, nil)
	}

	delete(swapchain.textures, swapchain.allocator)
	delete(swapchain.presentable_semaphores, swapchain.allocator)
	swapchain^ = {}
}

@(require_results)
swapchain_present :: proc(swapchain: Swapchain, device: Device, texture: Swapchain_Texture) -> vk.Result {
	swapchain_handle := swapchain.handle
	semaphore := texture.presentable
	index := texture.index
	present_info := vk.PresentInfoKHR {
		sType              = .PRESENT_INFO_KHR,
		pSwapchains        = &swapchain_handle,
		swapchainCount     = 1,
		pWaitSemaphores    = &semaphore,
		waitSemaphoreCount = 1,
		pImageIndices      = &index,
	}
	return vk.QueuePresentKHR(device.graphics_queue, &present_info)
}

@(require_results)
swapchain_acquire_texture :: proc(
	swapchain: Swapchain,
	device: Device,
	available: vk.Semaphore,
) -> (
	texture: Swapchain_Texture,
	result: vk.Result,
) {
	index: u32
	result = vk.AcquireNextImageKHR(
		device.logical,
		swapchain.handle,
		max(u64),
		available,
		0,
		&index,
	)

	if result != .SUCCESS && result != .SUBOPTIMAL_KHR {
		return
	}

	texture = {
		index       = index,
		texture     = &swapchain.textures[index],
		presentable = swapchain.presentable_semaphores[index],
	}

	return
}

@(require_results)
swapchain_configure :: proc(
	swapchain: ^Swapchain, 
	device: Device, 
	surface: Surface,
	allocator := context.allocator,
) -> (err: Swapchain_Error) {
	caps := surface_query_capabilities(surface, device) or_return
	if len(caps.formats) == 0 {
		return Swapchain_Configure_Error.No_Surface_Formats
	}
	if len(caps.present_modes) == 0 {
		return Swapchain_Configure_Error.No_Present_Modes
	}

	extent, ok := pick_extent(caps.caps, surface.window)
	if !ok {
		return nil
	}

	format := pick_format(caps.formats)
	present_mode := pick_present_mode(caps.present_modes)
	min_image_count := pick_min_image_count(caps.caps)

	swapchain_info := vk.SwapchainCreateInfoKHR {
		sType            = .SWAPCHAIN_CREATE_INFO_KHR,
		surface          = surface.surface,
		minImageCount    = min_image_count,
		presentMode      = present_mode,
		imageFormat      = format.format,
		imageColorSpace  = format.colorSpace,
		imageExtent      = extent,
		imageArrayLayers = 1,
		imageUsage       = {.COLOR_ATTACHMENT},
		preTransform     = caps.caps.currentTransform,
		compositeAlpha   = {.OPAQUE},
		clipped          = true,
		oldSwapchain     = swapchain.handle,
	}

	new_swapchain: Swapchain
	defer if err != nil {
		swapchain_destroy(&new_swapchain, device)
	}

	vk.CreateSwapchainKHR(device.logical, &swapchain_info, nil, &new_swapchain.handle) or_return
	new_swapchain.allocator = allocator
	new_swapchain.extent = extent
	new_swapchain.format = format.format
	new_swapchain.colorspace = format.colorSpace
	create_swapchain_textures(&new_swapchain, device) or_return
	create_swapchain_semaphores(&new_swapchain, device) or_return
	swapchain_destroy(swapchain, device)
	swapchain^ = new_swapchain
	return nil

}

@(private = "file")
create_swapchain_textures :: proc(
	swapchain: ^Swapchain,
	device: Device,
) -> Texture_Error {
	image_count: u32
	vk.GetSwapchainImagesKHR(device.logical, swapchain.handle, &image_count, nil) or_return
	images := make([]vk.Image, image_count, context.temp_allocator)
	vk.GetSwapchainImagesKHR(device.logical, swapchain.handle, &image_count, raw_data(images)) or_return

	swapchain.textures = make([]Texture, image_count, swapchain.allocator)
	for image, n in images {
		texture_wrap(
			&swapchain.textures[n],
			device,
			image = image,
			type = .D2,
			format = swapchain.format,
			extent = {swapchain.extent.width, swapchain.extent.height, 1},
			usage = {.COLOR_ATTACHMENT},
		) or_return
	}

	return nil
}

@(private = "file")
create_swapchain_semaphores :: proc(swapchain: ^Swapchain, device: Device) -> vk.Result {
	swapchain.presentable_semaphores = make(
		[]vk.Semaphore, 
		len(swapchain.textures), 
		swapchain.allocator,
	)

	semaphore_info := vk.SemaphoreCreateInfo {
		sType = .SEMAPHORE_CREATE_INFO,
	}
	for &semaphore in swapchain.presentable_semaphores {
		if result := vk.CreateSemaphore(device.logical, &semaphore_info, nil, &semaphore);
		   result != .SUCCESS {
			return result
		}
	}

	return .SUCCESS
}

@(private = "file")
pick_format :: proc(formats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
	for format in formats {
		if (format.format == .B8G8R8A8_SRGB || format.format == .R8G8B8A8_SRGB) &&
		   format.colorSpace == .SRGB_NONLINEAR {
			return format
		}
	}
	return formats[0]
}

@(private = "file")
pick_present_mode :: proc(modes: []vk.PresentModeKHR) -> vk.PresentModeKHR {
	for mode in modes {
		if mode == .MAILBOX {
			return mode
		}
	}
	return .FIFO
}

@(private = "file")
pick_extent :: proc(caps: vk.SurfaceCapabilitiesKHR, window: ^Window) -> (vk.Extent2D, bool) {
	extent := caps.currentExtent
	if extent.width == max(u32) {
		width, height := window_get_framebuffer_size(window)
		extent = {
			width  = clamp(
				u32(max(width, 0)),
				caps.minImageExtent.width,
				caps.maxImageExtent.width,
			),
			height = clamp(
				u32(max(height, 0)),
				caps.minImageExtent.height,
				caps.maxImageExtent.height,
			),
		}
	}

	if extent.width == 0 || extent.height == 0 {
		return {}, false
	}

	return extent, true
}

@(private = "file")
pick_min_image_count :: proc(caps: vk.SurfaceCapabilitiesKHR) -> u32 {
	image_count := caps.minImageCount + 1
	if caps.maxImageCount > 0 {
		image_count = min(image_count, caps.maxImageCount)
	}
	return image_count
}
