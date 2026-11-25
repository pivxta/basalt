package bwindow
import "base:runtime"
import "core:c"
import "core:strings"
import "vendor:glfw"
import vk "vendor:vulkan"

@(private = "file")
glfw_users := 0

Window :: struct {
	handle:               glfw.WindowHandle,
	events:               [dynamic]Event,
	resized:              bool,
	user_ptr:             rawptr,
	input_ptr:            rawptr,
	input_reset_callback: proc(input_ptr: rawptr),
	allocator:            runtime.Allocator,
	ctx:                  runtime.Context,
}

Error :: enum {
	None = 0,
	Library_Failure,
	Creation_Failure,
}

Event :: union #no_nil {
	Close_Event,
	Minimize_Event,
	Maximize_Event,
	Focus_Event,
	Resize_Event,
	Framebuffer_Resize_Event,
	Move_Event,
}

Close_Event :: struct {}

Minimize_Event :: struct {
	minimized: bool,
}

Maximize_Event :: struct {
	maximized: bool,
}

Focus_Event :: struct {
	focused: bool,
}

Resize_Event :: struct {
	width, height: int,
}

Framebuffer_Resize_Event :: struct {
	width, height: int,
}

Move_Event :: struct {
	x, y: int,
}

Cursor_State :: enum {
	Normal,
	Hidden,
	Captured,
	Disabled,
}

create :: proc(
	width, height: int,
	title: string,
	allocator := context.allocator,
) -> (
	^Window,
	Error,
) {
	if glfw_users == 0 {
		if !glfw.Init() {
			return nil, .Library_Failure
		}
	}
	glfw_users += 1

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
	ctitle := strings.clone_to_cstring(title, context.temp_allocator)
	handle := glfw.CreateWindow(i32(width), i32(height), ctitle, nil, nil)
	if handle == nil {
		glfw_users -= 1
		if glfw_users == 0 {
			glfw.Terminate()
		}
		return nil, .Creation_Failure
	}

	window := new(Window, allocator)
	window.handle = handle
	window.ctx = context
	window.allocator = allocator
	window.events = make([dynamic]Event, allocator)
	glfw.SetWindowUserPointer(window.handle, window)
	glfw.SetWindowCloseCallback(window.handle, close_callback)
	glfw.SetWindowIconifyCallback(window.handle, iconify_callback)
	glfw.SetWindowMaximizeCallback(window.handle, maximize_callback)
	glfw.SetWindowFocusCallback(window.handle, focus_callback)
	glfw.SetWindowPosCallback(window.handle, pos_callback)
	glfw.SetWindowSizeCallback(window.handle, size_callback)
	glfw.SetFramebufferSizeCallback(window.handle, framebuffer_size_callback)
	return window, nil
}

destroy :: proc(window: ^Window) {
	if window == nil {
		return
	}

	assert(window.input_ptr == nil, "Window with attached input is being destroyed")
	if window.handle != nil {
		glfw.DestroyWindow(window.handle)

		glfw_users -= 1
		if glfw_users == 0 {
			glfw.Terminate()
		}
	}

	delete(window.events)
	free(window, window.allocator)
}

create_surface :: proc(window: ^Window, instance: vk.Instance) -> (vk.SurfaceKHR, vk.Result) {
	assert(window != nil)
	surface: vk.SurfaceKHR
	result := glfw.CreateWindowSurface(instance, window.handle, nil, &surface)
	return surface, result
}

set_cursor_state :: proc(window: ^Window, state: Cursor_State) {
	assert(window != nil)
	glfw.SetInputMode(window.handle, glfw.CURSOR, cursor_state_to_glfw(state))
}

set_title :: proc(window: ^Window, title: string) {
	assert(window != nil)
	ctitle := strings.clone_to_cstring(title)
	glfw.SetWindowTitle(window.handle, ctitle)
	delete(ctitle)
}

set_size :: proc(window: ^Window, width, height: int) {
	assert(window != nil)
	glfw.SetWindowSize(window.handle, c.int(width), c.int(height))
}

set_size_limits :: proc(
	window: ^Window,
	min_width: Maybe(int),
	min_height: Maybe(int),
	max_width: Maybe(int),
	max_height: Maybe(int),
) {
	assert(window != nil)
	glfw.SetWindowSizeLimits(
		window.handle,
		c.int(min_width.? or_else glfw.DONT_CARE),
		c.int(min_height.? or_else glfw.DONT_CARE),
		c.int(max_width.? or_else glfw.DONT_CARE),
		c.int(max_height.? or_else glfw.DONT_CARE),
	)
}

set_position :: proc(window: ^Window, x, y: int) {
	assert(window != nil)
	glfw.SetWindowPos(window.handle, c.int(x), c.int(y))
}

set_minimized :: proc(window: ^Window, minimize: bool) {
	assert(window != nil)
	if minimize {
		glfw.IconifyWindow(window.handle)
	} else {
		if is_minimized(window) {
			restore(window)
		}
	}
}

set_maximized :: proc(window: ^Window, maximize: bool) {
	assert(window != nil)
	if maximize {
		glfw.MaximizeWindow(window.handle)
	} else {
		if is_maximized(window) {
			restore(window)
		}
	}
}

set_should_close :: proc(window: ^Window, close: bool) {
	assert(window != nil)
	glfw.SetWindowShouldClose(window.handle, b32(close))
}

restore :: proc(window: ^Window) {
	assert(window != nil)
	glfw.RestoreWindow(window.handle)
}

set_visible :: proc(window: ^Window, visible: bool) {
	assert(window != nil)
	if visible {
		glfw.ShowWindow(window.handle)
	} else {
		glfw.HideWindow(window.handle)
	}
}

focus :: proc(window: ^Window) {
	assert(window != nil)
	glfw.FocusWindow(window.handle)
}

get_cursor_state :: proc(window: ^Window) -> Cursor_State {
	assert(window != nil)
	switch glfw.GetInputMode(window.handle, glfw.CURSOR) {
	case glfw.CURSOR_NORMAL:
		return .Normal
	case glfw.CURSOR_HIDDEN:
		return .Hidden
	case glfw.CURSOR_CAPTURED:
		return .Captured
	case glfw.CURSOR_DISABLED:
		return .Disabled
	}
	unreachable()
}

get_title :: proc(window: ^Window) -> string {
	assert(window != nil)
	return string(glfw.GetWindowTitle(window.handle))
}

get_content_scale :: proc(window: ^Window) -> (f32, f32) {
	assert(window != nil)
	return glfw.GetWindowContentScale(window.handle)
}

get_size :: proc(window: ^Window) -> (int, int) {
	assert(window != nil)
	width, height := glfw.GetWindowSize(window.handle)
	return int(width), int(height)
}

get_framebuffer_size :: proc(window: ^Window) -> (int, int) {
	assert(window != nil)
	width, height := glfw.GetFramebufferSize(window.handle)
	return int(width), int(height)
}

get_position :: proc(window: ^Window) -> (int, int) {
	assert(window != nil)
	x, y := glfw.GetWindowPos(window.handle)
	return int(x), int(y)
}

is_minimized :: proc(window: ^Window) -> bool {
	assert(window != nil)
	return glfw.GetWindowAttrib(window.handle, glfw.ICONIFIED) != 0
}

is_maximized :: proc(window: ^Window) -> bool {
	assert(window != nil)
	return glfw.GetWindowAttrib(window.handle, glfw.MAXIMIZED) != 0
}

is_visible :: proc(window: ^Window) -> bool {
	assert(window != nil)
	return glfw.GetWindowAttrib(window.handle, glfw.VISIBLE) != 0
}

is_focused :: proc(window: ^Window) -> bool {
	assert(window != nil)
	return glfw.GetWindowAttrib(window.handle, glfw.FOCUSED) != 0
}

should_close :: proc(window: ^Window) -> bool {
	assert(window != nil)
	return glfw.WindowShouldClose(window.handle) != glfw.FALSE
}

poll_events :: proc(windows: ..^Window) {
	for window in windows {
		assert(window != nil)
		clear(&window.events)
		window.resized = false
		if window.input_reset_callback != nil {
			window.input_reset_callback(window.input_ptr)
		}
	}

	glfw.PollEvents()
}

get_events :: proc(window: ^Window) -> []Event {
	return window.events[:]
}

@(private = "file")
close_callback :: proc "cdecl" (handle: glfw.WindowHandle) {
	window := cast(^Window)glfw.GetWindowUserPointer(handle)
	context = window.ctx
	append(&window.events, Close_Event{})
}

@(private = "file")
size_callback :: proc "cdecl" (handle: glfw.WindowHandle, width: c.int, height: c.int) {
	window := cast(^Window)glfw.GetWindowUserPointer(handle)
	context = window.ctx
	append(&window.events, Resize_Event{width = int(width), height = int(height)})
}

@(private = "file")
framebuffer_size_callback :: proc "cdecl" (
	handle: glfw.WindowHandle,
	width: c.int,
	height: c.int,
) {
	window := cast(^Window)glfw.GetWindowUserPointer(handle)
	window.resized = true
	context = window.ctx
	append(&window.events, Framebuffer_Resize_Event{width = int(width), height = int(height)})
}

@(private = "file")
pos_callback :: proc "cdecl" (handle: glfw.WindowHandle, x: c.int, y: c.int) {
	window := cast(^Window)glfw.GetWindowUserPointer(handle)
	context = window.ctx
	append(&window.events, Move_Event{x = int(x), y = int(y)})
}

@(private = "file")
iconify_callback :: proc "cdecl" (handle: glfw.WindowHandle, iconified: c.int) {
	window := cast(^Window)glfw.GetWindowUserPointer(handle)
	context = window.ctx
	append(&window.events, Minimize_Event{minimized = bool(iconified)})
}

@(private = "file")
maximize_callback :: proc "cdecl" (handle: glfw.WindowHandle, maximized: c.int) {
	window := cast(^Window)glfw.GetWindowUserPointer(handle)
	context = window.ctx
	append(&window.events, Maximize_Event{maximized = bool(maximized)})
}

@(private = "file")
focus_callback :: proc "cdecl" (handle: glfw.WindowHandle, focused: c.int) {
	window := cast(^Window)glfw.GetWindowUserPointer(handle)
	context = window.ctx
	append(&window.events, Focus_Event{focused = bool(focused)})
}

cursor_state_to_glfw :: proc "contextless" (state: Cursor_State) -> c.int {
	switch state {
	case .Normal:
		return glfw.CURSOR_NORMAL
	case .Hidden:
		return glfw.CURSOR_HIDDEN
	case .Captured:
		return glfw.CURSOR_CAPTURED
	case .Disabled:
		return glfw.CURSOR_DISABLED
	}
	unreachable()
}
