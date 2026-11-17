package basalt
import "core:c"
import "core:strings"
import "vendor:glfw"
import vk "vendor:vulkan"

@(private = "file")
glfw_users := 0

Window :: struct {
	handle:      glfw.WindowHandle,
	resized:     bool,
	input_state: ^Input_State,
}

Window_Error :: enum {
	Library_Init_Failure,
	Creation_Failure,
}

Cursor_State :: enum {
	Normal,
	Hidden,
	Captured,
	Disabled,
}

window_create :: proc(
	width, height: int, 
	title: string,
) -> (
	^Window, 
	^Input_State, 
	Window_Error,
) {
	if glfw_users == 0 {
		if !glfw.Init() {
			return nil, nil, .Library_Init_Failure
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
		return nil, nil, .Creation_Failure
	}

	window := new(Window)
	input := new(Input_State)
	window.handle = handle
	window.input_state = input
	input.cursor_position.x, input.cursor_position.y = glfw.GetCursorPos(window.handle)
	glfw.SetWindowUserPointer(window.handle, window)
	glfw.SetFramebufferSizeCallback(window.handle, framebuffer_size_callback)
	glfw.SetKeyCallback(window.handle, key_callback)
	glfw.SetMouseButtonCallback(window.handle, mouse_button_callback)
	glfw.SetCursorPosCallback(window.handle, cursor_callback)
	glfw.SetScrollCallback(window.handle, scroll_callback)
	if glfw.RawMouseMotionSupported() {
		glfw.SetInputMode(window.handle, glfw.RAW_MOUSE_MOTION, c.int(glfw.TRUE))
	}
	return window, input, nil
}

window_create_surface :: proc(window: ^Window, instance: vk.Instance) -> (vk.SurfaceKHR, vk.Result) {
	assert(window != nil)
	surface: vk.SurfaceKHR
	result := glfw.CreateWindowSurface(instance, window.handle, nil, &surface)
	return surface, result
}

window_set_cursor_state :: proc(window: ^Window, state: Cursor_State) {
	assert(window != nil)
	glfw.SetInputMode(window.handle, glfw.CURSOR, cursor_state_to_glfw(state))
}

window_set_title :: proc(window: ^Window, title: string) {
	assert(window != nil)
	ctitle := strings.clone_to_cstring(title)
	glfw.SetWindowTitle(window.handle, ctitle)
	delete(ctitle)
}

window_set_size :: proc(window: ^Window, width, height: int) {
	assert(window != nil)
	glfw.SetWindowSize(window.handle, c.int(width), c.int(height))
}

window_set_size_limits :: proc(
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

window_set_position :: proc(window: ^Window, x, y: int) {
	assert(window != nil)
	glfw.SetWindowPos(window.handle, c.int(x), c.int(y))
}

window_set_minimized :: proc(window: ^Window, minimize: bool) {
	assert(window != nil)
	if minimize {
		glfw.IconifyWindow(window.handle)
	} else {
		if window_is_minimized(window) {
			window_restore(window)
		}
	}
}

window_set_maximized :: proc(window: ^Window, maximize: bool) {
	assert(window != nil)
	if maximize {
		glfw.MaximizeWindow(window.handle)
	} else {
		if window_is_maximized(window) {
			window_restore(window)
		}
	}
}

window_restore :: proc(window: ^Window) {
	assert(window != nil)
	glfw.RestoreWindow(window.handle)
}

window_set_visible :: proc(window: ^Window, visible: bool) {
	assert(window != nil)
	if visible {
		glfw.ShowWindow(window.handle)
	} else {
		glfw.HideWindow(window.handle)
	}
}

window_focus :: proc(window: ^Window) {
	assert(window != nil)
	glfw.FocusWindow(window.handle)
}

window_get_cursor_state :: proc(window: ^Window) -> Cursor_State {
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

window_get_title :: proc(window: ^Window) -> string {
	assert(window != nil)
	return string(glfw.GetWindowTitle(window.handle))
}

window_get_content_scale :: proc(window: ^Window) -> (f32, f32) {
	assert(window != nil)
	return glfw.GetWindowContentScale(window.handle)
}

window_get_size :: proc(window: ^Window) -> (int, int) {
	assert(window != nil)
	width, height := glfw.GetWindowSize(window.handle)
	return int(width), int(height)
}

window_get_framebuffer_size :: proc(window: ^Window) -> (int, int) {
	assert(window != nil)
	width, height := glfw.GetFramebufferSize(window.handle)
	return int(width), int(height)
}

window_get_position :: proc(window: ^Window) -> (int, int) {
	assert(window != nil)
	x, y := glfw.GetWindowPos(window.handle)
	return int(x), int(y)
}

window_is_minimized :: proc(window: ^Window) -> bool {
	assert(window != nil)
	return glfw.GetWindowAttrib(window.handle, glfw.ICONIFIED) != 0
}

window_is_maximized :: proc(window: ^Window) -> bool {
	assert(window != nil)
	return glfw.GetWindowAttrib(window.handle, glfw.MAXIMIZED) != 0
}

window_is_visible :: proc(window: ^Window) -> bool {
	assert(window != nil)
	return glfw.GetWindowAttrib(window.handle, glfw.VISIBLE) != 0
}

window_is_focused :: proc(window: ^Window) -> bool {
	assert(window != nil)
	return glfw.GetWindowAttrib(window.handle, glfw.FOCUSED) != 0
}

window_should_close :: proc(window: ^Window) -> bool {
	assert(window != nil)
	return glfw.WindowShouldClose(window.handle) != glfw.FALSE
}

window_destroy :: proc(window: ^Window) {
	if window == nil {
		return
	}

	if window.handle != nil {
		glfw.DestroyWindow(window.handle)

		glfw_users -= 1
		if glfw_users == 0 {
			glfw.Terminate()
		}
	}

	free(window.input_state)
	free(window)
}

poll_window_events :: proc(windows: ..^Window) {
	for w in windows {
		assert(w != nil)
		prepare_input_poll(w)
	}

	glfw.PollEvents()
}

@(private = "file")
prepare_input_poll :: proc(window: ^Window) {
	window.resized = false

	input := window.input_state
	input.keys_previous = input.keys_current
	input.mouse_buttons_previous = input.mouse_buttons_current
	input.cursor_delta = {0, 0}
	input.scroll_delta = {0, 0}
}

@(private = "file")
framebuffer_size_callback :: proc "cdecl" (
	window: glfw.WindowHandle, 
	width: c.int, 
	height: c.int,
) {
	window := cast(^Window)glfw.GetWindowUserPointer(window)
	window.resized = true
}

@(private = "file")
key_callback :: proc "cdecl" (
	window: glfw.WindowHandle,
	key: c.int,
	scancode: c.int,
	action: c.int,
	mods: c.int,
) {
	window := cast(^Window)glfw.GetWindowUserPointer(window)
	input := window.input_state

	key, ok := key_from_glfw(key)
	if !ok {
		return
	}

	switch action {
	case glfw.PRESS:
		input.keys_current |= {key}
	case glfw.RELEASE:
		input.keys_current &= ~{key}
	}
}

@(private = "file")
mouse_button_callback :: proc "cdecl" (
	window: glfw.WindowHandle,
	button: c.int,
	action: c.int,
	mods: c.int,
) {
	window := cast(^Window)glfw.GetWindowUserPointer(window)
	input := window.input_state

	button, ok := mouse_button_from_glfw(button)
	if !ok {
		return
	}

	switch action {
	case glfw.PRESS:
		input.mouse_buttons_current |= {button}
	case glfw.RELEASE:
		input.mouse_buttons_current &= ~{button}
	}
}

@(private = "file")
cursor_callback :: proc "cdecl" (window: glfw.WindowHandle, x: f64, y: f64) {
	window := cast(^Window)glfw.GetWindowUserPointer(window)
	input := window.input_state

	input.cursor_delta.x += x - input.cursor_position.x
	input.cursor_delta.y += y - input.cursor_position.y
	input.cursor_position.x = x
	input.cursor_position.y = y
}

@(private = "file")
scroll_callback :: proc "cdecl" (window: glfw.WindowHandle, x: f64, y: f64) {
	window := cast(^Window)glfw.GetWindowUserPointer(window)
	input := window.input_state

	input.scroll_delta.x += x
	input.scroll_delta.y += y
}

key_to_glfw :: proc "contextless" (key: Key) -> c.int {
	switch key {
	case .Space:
		return glfw.KEY_SPACE
	case .Apostrophe:
		return glfw.KEY_APOSTROPHE
	case .Comma:
		return glfw.KEY_COMMA
	case .Minus:
		return glfw.KEY_MINUS
	case .Period:
		return glfw.KEY_PERIOD
	case .Slash:
		return glfw.KEY_SLASH
	case .Alpha_0:
		return glfw.KEY_0
	case .Alpha_1:
		return glfw.KEY_1
	case .Alpha_2:
		return glfw.KEY_2
	case .Alpha_3:
		return glfw.KEY_3
	case .Alpha_4:
		return glfw.KEY_4
	case .Alpha_5:
		return glfw.KEY_5
	case .Alpha_6:
		return glfw.KEY_6
	case .Alpha_7:
		return glfw.KEY_7
	case .Alpha_8:
		return glfw.KEY_8
	case .Alpha_9:
		return glfw.KEY_9
	case .Semicolon:
		return glfw.KEY_SEMICOLON
	case .Equal:
		return glfw.KEY_EQUAL
	case .A:
		return glfw.KEY_A
	case .B:
		return glfw.KEY_B
	case .C:
		return glfw.KEY_C
	case .D:
		return glfw.KEY_D
	case .E:
		return glfw.KEY_E
	case .F:
		return glfw.KEY_F
	case .G:
		return glfw.KEY_G
	case .H:
		return glfw.KEY_H
	case .I:
		return glfw.KEY_I
	case .J:
		return glfw.KEY_J
	case .K:
		return glfw.KEY_K
	case .L:
		return glfw.KEY_L
	case .M:
		return glfw.KEY_M
	case .N:
		return glfw.KEY_N
	case .O:
		return glfw.KEY_O
	case .P:
		return glfw.KEY_P
	case .Q:
		return glfw.KEY_Q
	case .R:
		return glfw.KEY_R
	case .S:
		return glfw.KEY_S
	case .T:
		return glfw.KEY_T
	case .U:
		return glfw.KEY_U
	case .V:
		return glfw.KEY_V
	case .W:
		return glfw.KEY_W
	case .X:
		return glfw.KEY_X
	case .Y:
		return glfw.KEY_Y
	case .Z:
		return glfw.KEY_Z
	case .Left_Bracket:
		return glfw.KEY_LEFT_BRACKET
	case .Backslash:
		return glfw.KEY_BACKSLASH
	case .Right_Bracket:
		return glfw.KEY_RIGHT_BRACKET
	case .Grave_Accent:
		return glfw.KEY_GRAVE_ACCENT
	case .World_1:
		return glfw.KEY_WORLD_1
	case .World_2:
		return glfw.KEY_WORLD_2
	case .Escape:
		return glfw.KEY_ESCAPE
	case .Enter:
		return glfw.KEY_ENTER
	case .Tab:
		return glfw.KEY_TAB
	case .Backspace:
		return glfw.KEY_BACKSPACE
	case .Insert:
		return glfw.KEY_INSERT
	case .Delete:
		return glfw.KEY_DELETE
	case .Right:
		return glfw.KEY_RIGHT
	case .Left:
		return glfw.KEY_LEFT
	case .Down:
		return glfw.KEY_DOWN
	case .Up:
		return glfw.KEY_UP
	case .Page_Up:
		return glfw.KEY_PAGE_UP
	case .Page_Down:
		return glfw.KEY_PAGE_DOWN
	case .Home:
		return glfw.KEY_HOME
	case .End:
		return glfw.KEY_END
	case .Caps_Lock:
		return glfw.KEY_CAPS_LOCK
	case .Scroll_Lock:
		return glfw.KEY_SCROLL_LOCK
	case .Num_Lock:
		return glfw.KEY_NUM_LOCK
	case .Print_Screen:
		return glfw.KEY_PRINT_SCREEN
	case .Pause:
		return glfw.KEY_PAUSE
	case .F1:
		return glfw.KEY_F1
	case .F2:
		return glfw.KEY_F2
	case .F3:
		return glfw.KEY_F3
	case .F4:
		return glfw.KEY_F4
	case .F5:
		return glfw.KEY_F5
	case .F6:
		return glfw.KEY_F6
	case .F7:
		return glfw.KEY_F7
	case .F8:
		return glfw.KEY_F8
	case .F9:
		return glfw.KEY_F9
	case .F10:
		return glfw.KEY_F10
	case .F11:
		return glfw.KEY_F11
	case .F12:
		return glfw.KEY_F12
	case .F13:
		return glfw.KEY_F13
	case .F14:
		return glfw.KEY_F14
	case .F15:
		return glfw.KEY_F15
	case .F16:
		return glfw.KEY_F16
	case .F17:
		return glfw.KEY_F17
	case .F18:
		return glfw.KEY_F18
	case .F19:
		return glfw.KEY_F19
	case .F20:
		return glfw.KEY_F20
	case .F21:
		return glfw.KEY_F21
	case .F22:
		return glfw.KEY_F22
	case .F23:
		return glfw.KEY_F23
	case .F24:
		return glfw.KEY_F24
	case .F25:
		return glfw.KEY_F25
	case .Keypad_0:
		return glfw.KEY_KP_0
	case .Keypad_1:
		return glfw.KEY_KP_1
	case .Keypad_2:
		return glfw.KEY_KP_2
	case .Keypad_3:
		return glfw.KEY_KP_3
	case .Keypad_4:
		return glfw.KEY_KP_4
	case .Keypad_5:
		return glfw.KEY_KP_5
	case .Keypad_6:
		return glfw.KEY_KP_6
	case .Keypad_7:
		return glfw.KEY_KP_7
	case .Keypad_8:
		return glfw.KEY_KP_8
	case .Keypad_9:
		return glfw.KEY_KP_9
	case .Keypad_Decimal:
		return glfw.KEY_KP_DECIMAL
	case .Keypad_Divide:
		return glfw.KEY_KP_DIVIDE
	case .Keypad_Multiply:
		return glfw.KEY_KP_MULTIPLY
	case .Keypad_Subtract:
		return glfw.KEY_KP_SUBTRACT
	case .Keypad_Add:
		return glfw.KEY_KP_ADD
	case .Keypad_Enter:
		return glfw.KEY_KP_ENTER
	case .Keypad_Equal:
		return glfw.KEY_KP_EQUAL
	case .Left_Shift:
		return glfw.KEY_LEFT_SHIFT
	case .Left_Control:
		return glfw.KEY_LEFT_CONTROL
	case .Left_Alt:
		return glfw.KEY_LEFT_ALT
	case .Left_Super:
		return glfw.KEY_LEFT_SUPER
	case .Right_Shift:
		return glfw.KEY_RIGHT_SHIFT
	case .Right_Control:
		return glfw.KEY_RIGHT_CONTROL
	case .Right_Alt:
		return glfw.KEY_RIGHT_ALT
	case .Right_Super:
		return glfw.KEY_RIGHT_SUPER
	case .Menu:
		return glfw.KEY_MENU
	}
	unreachable()
}

key_from_glfw :: proc "contextless" (code: c.int) -> (key: Key, ok: bool) {
	switch code {
	case glfw.KEY_SPACE:
		return .Space, true
	case glfw.KEY_APOSTROPHE:
		return .Apostrophe, true
	case glfw.KEY_COMMA:
		return .Comma, true
	case glfw.KEY_MINUS:
		return .Minus, true
	case glfw.KEY_PERIOD:
		return .Period, true
	case glfw.KEY_SLASH:
		return .Slash, true
	case glfw.KEY_0:
		return .Alpha_0, true
	case glfw.KEY_1:
		return .Alpha_1, true
	case glfw.KEY_2:
		return .Alpha_2, true
	case glfw.KEY_3:
		return .Alpha_3, true
	case glfw.KEY_4:
		return .Alpha_4, true
	case glfw.KEY_5:
		return .Alpha_5, true
	case glfw.KEY_6:
		return .Alpha_6, true
	case glfw.KEY_7:
		return .Alpha_7, true
	case glfw.KEY_8:
		return .Alpha_8, true
	case glfw.KEY_9:
		return .Alpha_9, true
	case glfw.KEY_SEMICOLON:
		return .Semicolon, true
	case glfw.KEY_EQUAL:
		return .Equal, true
	case glfw.KEY_A:
		return .A, true
	case glfw.KEY_B:
		return .B, true
	case glfw.KEY_C:
		return .C, true
	case glfw.KEY_D:
		return .D, true
	case glfw.KEY_E:
		return .E, true
	case glfw.KEY_F:
		return .F, true
	case glfw.KEY_G:
		return .G, true
	case glfw.KEY_H:
		return .H, true
	case glfw.KEY_I:
		return .I, true
	case glfw.KEY_J:
		return .J, true
	case glfw.KEY_K:
		return .K, true
	case glfw.KEY_L:
		return .L, true
	case glfw.KEY_M:
		return .M, true
	case glfw.KEY_N:
		return .N, true
	case glfw.KEY_O:
		return .O, true
	case glfw.KEY_P:
		return .P, true
	case glfw.KEY_Q:
		return .Q, true
	case glfw.KEY_R:
		return .R, true
	case glfw.KEY_S:
		return .S, true
	case glfw.KEY_T:
		return .T, true
	case glfw.KEY_U:
		return .U, true
	case glfw.KEY_V:
		return .V, true
	case glfw.KEY_W:
		return .W, true
	case glfw.KEY_X:
		return .X, true
	case glfw.KEY_Y:
		return .Y, true
	case glfw.KEY_Z:
		return .Z, true
	case glfw.KEY_LEFT_BRACKET:
		return .Left_Bracket, true
	case glfw.KEY_BACKSLASH:
		return .Backslash, true
	case glfw.KEY_RIGHT_BRACKET:
		return .Right_Bracket, true
	case glfw.KEY_GRAVE_ACCENT:
		return .Grave_Accent, true
	case glfw.KEY_WORLD_1:
		return .World_1, true
	case glfw.KEY_WORLD_2:
		return .World_2, true
	case glfw.KEY_ESCAPE:
		return .Escape, true
	case glfw.KEY_ENTER:
		return .Enter, true
	case glfw.KEY_TAB:
		return .Tab, true
	case glfw.KEY_BACKSPACE:
		return .Backspace, true
	case glfw.KEY_INSERT:
		return .Insert, true
	case glfw.KEY_DELETE:
		return .Delete, true
	case glfw.KEY_RIGHT:
		return .Right, true
	case glfw.KEY_LEFT:
		return .Left, true
	case glfw.KEY_DOWN:
		return .Down, true
	case glfw.KEY_UP:
		return .Up, true
	case glfw.KEY_PAGE_UP:
		return .Page_Up, true
	case glfw.KEY_PAGE_DOWN:
		return .Page_Down, true
	case glfw.KEY_HOME:
		return .Home, true
	case glfw.KEY_END:
		return .End, true
	case glfw.KEY_CAPS_LOCK:
		return .Caps_Lock, true
	case glfw.KEY_SCROLL_LOCK:
		return .Scroll_Lock, true
	case glfw.KEY_NUM_LOCK:
		return .Num_Lock, true
	case glfw.KEY_PRINT_SCREEN:
		return .Print_Screen, true
	case glfw.KEY_PAUSE:
		return .Pause, true
	case glfw.KEY_F1:
		return .F1, true
	case glfw.KEY_F2:
		return .F2, true
	case glfw.KEY_F3:
		return .F3, true
	case glfw.KEY_F4:
		return .F4, true
	case glfw.KEY_F5:
		return .F5, true
	case glfw.KEY_F6:
		return .F6, true
	case glfw.KEY_F7:
		return .F7, true
	case glfw.KEY_F8:
		return .F8, true
	case glfw.KEY_F9:
		return .F9, true
	case glfw.KEY_F10:
		return .F10, true
	case glfw.KEY_F11:
		return .F11, true
	case glfw.KEY_F12:
		return .F12, true
	case glfw.KEY_F13:
		return .F13, true
	case glfw.KEY_F14:
		return .F14, true
	case glfw.KEY_F15:
		return .F15, true
	case glfw.KEY_F16:
		return .F16, true
	case glfw.KEY_F17:
		return .F17, true
	case glfw.KEY_F18:
		return .F18, true
	case glfw.KEY_F19:
		return .F19, true
	case glfw.KEY_F20:
		return .F20, true
	case glfw.KEY_F21:
		return .F21, true
	case glfw.KEY_F22:
		return .F22, true
	case glfw.KEY_F23:
		return .F23, true
	case glfw.KEY_F24:
		return .F24, true
	case glfw.KEY_F25:
		return .F25, true
	case glfw.KEY_KP_0:
		return .Keypad_0, true
	case glfw.KEY_KP_1:
		return .Keypad_1, true
	case glfw.KEY_KP_2:
		return .Keypad_2, true
	case glfw.KEY_KP_3:
		return .Keypad_3, true
	case glfw.KEY_KP_4:
		return .Keypad_4, true
	case glfw.KEY_KP_5:
		return .Keypad_5, true
	case glfw.KEY_KP_6:
		return .Keypad_6, true
	case glfw.KEY_KP_7:
		return .Keypad_7, true
	case glfw.KEY_KP_8:
		return .Keypad_8, true
	case glfw.KEY_KP_9:
		return .Keypad_9, true
	case glfw.KEY_KP_DECIMAL:
		return .Keypad_Decimal, true
	case glfw.KEY_KP_DIVIDE:
		return .Keypad_Divide, true
	case glfw.KEY_KP_MULTIPLY:
		return .Keypad_Multiply, true
	case glfw.KEY_KP_SUBTRACT:
		return .Keypad_Subtract, true
	case glfw.KEY_KP_ADD:
		return .Keypad_Add, true
	case glfw.KEY_KP_ENTER:
		return .Keypad_Enter, true
	case glfw.KEY_KP_EQUAL:
		return .Keypad_Equal, true
	case glfw.KEY_LEFT_SHIFT:
		return .Left_Shift, true
	case glfw.KEY_LEFT_CONTROL:
		return .Left_Control, true
	case glfw.KEY_LEFT_ALT:
		return .Left_Alt, true
	case glfw.KEY_LEFT_SUPER:
		return .Left_Super, true
	case glfw.KEY_RIGHT_SHIFT:
		return .Right_Shift, true
	case glfw.KEY_RIGHT_CONTROL:
		return .Right_Control, true
	case glfw.KEY_RIGHT_ALT:
		return .Right_Alt, true
	case glfw.KEY_RIGHT_SUPER:
		return .Right_Super, true
	case glfw.KEY_MENU:
		return .Menu, true
	}
	return {}, false
}

mouse_button_to_glfw :: proc "contextless" (button: Mouse_Button) -> c.int {
	return c.int(button)
}

mouse_button_from_glfw :: proc "contextless" (code: c.int) -> (
	button: Mouse_Button, 
	ok: bool,
) {
	if code < 0 || code > glfw.MOUSE_BUTTON_LAST {
		return
	}
	return Mouse_Button(code), true,
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
