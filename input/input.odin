package binput
import "base:runtime"
import "core:c"
import "vendor:glfw"
import bwindow "../window"

Key :: enum {
	Space,
	Apostrophe,
	Comma,
	Minus,
	Period,
	Slash,
	Alpha_0,
	Alpha_1,
	Alpha_2,
	Alpha_3,
	Alpha_4,
	Alpha_5,
	Alpha_6,
	Alpha_7,
	Alpha_8,
	Alpha_9,
	Semicolon,
	Equal,
	A,
	B,
	C,
	D,
	E,
	F,
	G,
	H,
	I,
	J,
	K,
	L,
	M,
	N,
	O,
	P,
	Q,
	R,
	S,
	T,
	U,
	V,
	W,
	X,
	Y,
	Z,
	Left_Bracket,
	Backslash,
	Right_Bracket,
	Grave_Accent,
	World_1,
	World_2,
	Escape,
	Enter,
	Tab,
	Backspace,
	Insert,
	Delete,
	Right,
	Left,
	Down,
	Up,
	Page_Up,
	Page_Down,
	Home,
	End,
	Caps_Lock,
	Scroll_Lock,
	Num_Lock,
	Print_Screen,
	Pause,
	F1,
	F2,
	F3,
	F4,
	F5,
	F6,
	F7,
	F8,
	F9,
	F10,
	F11,
	F12,
	F13,
	F14,
	F15,
	F16,
	F17,
	F18,
	F19,
	F20,
	F21,
	F22,
	F23,
	F24,
	F25,
	Keypad_0,
	Keypad_1,
	Keypad_2,
	Keypad_3,
	Keypad_4,
	Keypad_5,
	Keypad_6,
	Keypad_7,
	Keypad_8,
	Keypad_9,
	Keypad_Decimal,
	Keypad_Divide,
	Keypad_Multiply,
	Keypad_Subtract,
	Keypad_Add,
	Keypad_Enter,
	Keypad_Equal,
	Left_Shift,
	Left_Control,
	Left_Alt,
	Left_Super,
	Right_Shift,
	Right_Control,
	Right_Alt,
	Right_Super,
	Menu,
}

Mouse_Button :: enum {
	Button_1,
	Button_2,
	Button_3,
	Button_4,
	Button_5,
	Button_6,
	Button_7,
	Button_8,
	Left = Button_1,
	Right = Button_2,
	Middle = Button_3,
}

Button_States :: bit_set[Button_State]

Button_State :: enum {
	Just_Pressed,
	Just_Released,
	Pressed,
	Released,
}

Button_Action :: enum {
	Pressed,
	Released,
	Repeated,
}

Modifiers :: bit_set[Modifier; i32]

Modifier :: enum {
	Shift = 0,
	Control = 1,
	Alt = 2,
	Super = 3,
	Caps_Lock = 4,
	Num_Lock = 5,
}

Key_Event :: struct {
	key:       Key,
	action:    Button_Action,
	modifiers: Modifiers,
}

Mouse_Button_Event :: struct {
	button:    Mouse_Button,
	action:    Button_Action,
	modifiers: Modifiers,
}

Text_Event :: struct {
	codepoint: rune,
}

Scroll_Event :: struct {
	delta: [2]f64,
}

Cursor_Move_Event :: struct {
	position: [2]f64,
	delta:    [2]f64,
}

Event :: union #no_nil {
	Key_Event,
	Mouse_Button_Event,
	Text_Event,
	Scroll_Event,
	Cursor_Move_Event,
}

Input :: struct {
	events:                 [dynamic]Event,
	keys_current:           bit_set[Key],
	keys_previous:          bit_set[Key],
	mouse_buttons_current:  bit_set[Mouse_Button],
	mouse_buttons_previous: bit_set[Mouse_Button],
	cursor_position:        [2]f64,
	cursor_delta:           [2]f64,
	scroll_delta:           [2]f64,
	registered_window:      ^bwindow.Window,
	allocator:              runtime.Allocator,
}

create :: proc(window: ^bwindow.Window, allocator := context.allocator) -> ^Input {
	assert(window != nil)
	assert(window.input_ptr == nil, "Window already has an input observer attached to it")

	input := new(Input, allocator)
	input.events = make([dynamic]Event, allocator)
	input.allocator = allocator
	input.registered_window = window
	input.cursor_position.x, input.cursor_position.y = glfw.GetCursorPos(window.handle)
	glfw.SetKeyCallback(window.handle, key_callback)
	glfw.SetMouseButtonCallback(window.handle, mouse_button_callback)
	glfw.SetCursorPosCallback(window.handle, cursor_callback)
	glfw.SetScrollCallback(window.handle, scroll_callback)
	glfw.SetCharCallback(window.handle, char_callback)

	window.input_reset_callback = reset_callback
	window.input_ptr = rawptr(input)
	return input
}

destroy :: proc(input: ^Input) {
	if input == nil {
		return
	}

	input.registered_window.input_ptr = nil
	input.registered_window.input_reset_callback = nil
	glfw.SetKeyCallback(input.registered_window.handle, nil)
	glfw.SetMouseButtonCallback(input.registered_window.handle, nil)
	glfw.SetCursorPosCallback(input.registered_window.handle, nil)
	glfw.SetScrollCallback(input.registered_window.handle, nil)
	glfw.SetCharCallback(input.registered_window.handle, nil)
	delete(input.events)
	free(input, input.allocator)
}

get_cursor_position :: proc(input: ^Input) -> [2]f64 {
	return input.cursor_position
}

get_cursor_delta :: proc(input: ^Input) -> [2]f64 {
	return input.cursor_delta
}

get_scroll_delta :: proc(input: ^Input) -> [2]f64 {
	return input.scroll_delta
}

get_key :: proc(input: ^Input, key: Key) -> Button_States {
	assert(input != nil)

	pressed := key in input.keys_current
	was_pressed := key in input.keys_previous

	result: bit_set[Button_State]
	if pressed {
		result |= {.Pressed}
	}
	if pressed && !was_pressed {
		result |= {.Just_Pressed}
	}
	if !pressed {
		result |= {.Released}
	}
	if !pressed && was_pressed {
		result |= {.Just_Released}
	}

	return result
}

get_mouse_button :: proc(
	input: ^Input,
	button: Mouse_Button,
) -> Button_States {
	assert(input != nil)

	pressed := button in input.mouse_buttons_current
	was_pressed := button in input.mouse_buttons_previous

	result: bit_set[Button_State]
	if pressed {
		result |= {.Pressed}
	}
	if pressed && !was_pressed {
		result |= {.Just_Pressed}
	}
	if !pressed {
		result |= {.Released}
	}
	if !pressed && was_pressed {
		result |= {.Just_Released}
	}

	return result
}

@(private = "file")
reset_callback :: proc(input_raw: rawptr) {
	input := cast(^Input)input_raw 
	input.keys_previous = input.keys_current
	input.mouse_buttons_previous = input.mouse_buttons_current
	input.cursor_delta = {0, 0}
	input.scroll_delta = {0, 0}
	clear(&input.events)
}

@(private = "file")
char_callback :: proc "cdecl" (handle: glfw.WindowHandle, codepoint: rune) {
	window := cast(^bwindow.Window)glfw.GetWindowUserPointer(handle)
	input := cast(^Input)window.input_ptr
	context = window.ctx
	append(&input.events, Text_Event { 
		codepoint = codepoint,
	})
}

@(private = "file")
key_callback :: proc "cdecl" (
	handle: glfw.WindowHandle,
	key: c.int,
	scancode: c.int,
	action: c.int,
	mods: c.int,
) {
	window := cast(^bwindow.Window)glfw.GetWindowUserPointer(handle)
	input := cast(^Input)window.input_ptr

	key, key_ok := key_from_glfw(key)
	if !key_ok {
		return
	}

	switch action {
	case glfw.PRESS:
		input.keys_current |= {key}
	case glfw.RELEASE:
		input.keys_current &= ~{key}
	}

	modifiers := modifiers_from_glfw(mods)
	action, action_ok := button_action_from_glfw(action)
	if !action_ok {
		return
	}

	context = window.ctx
	append(&input.events, Key_Event {
		modifiers = modifiers,
		action = action,
		key = key,
	})
}

@(private = "file")
mouse_button_callback :: proc "cdecl" (
	handle: glfw.WindowHandle,
	button: c.int,
	action: c.int,
	mods: c.int,
) {
	window := cast(^bwindow.Window)glfw.GetWindowUserPointer(handle)
	input := cast(^Input)window.input_ptr

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
	
	modifiers := modifiers_from_glfw(mods)
	action, action_ok := button_action_from_glfw(action)
	if !action_ok {
		return
	}

	context = window.ctx
	append(&input.events, Mouse_Button_Event {
		modifiers = modifiers,
		action = action,
		button = button,
	})
}

@(private = "file")
cursor_callback :: proc "cdecl" (handle: glfw.WindowHandle, x: f64, y: f64) {
	window := cast(^bwindow.Window)glfw.GetWindowUserPointer(handle)
	input := cast(^Input)window.input_ptr

	position := [2]f64 {x, y}
	delta := position - input.cursor_position
	input.cursor_delta += delta
	input.cursor_position = position

	context = window.ctx
	append(&input.events, Cursor_Move_Event {
		position = position,
		delta = delta,
	})
}

@(private = "file")
scroll_callback :: proc "cdecl" (handle: glfw.WindowHandle, x: f64, y: f64) {
	window := cast(^bwindow.Window)glfw.GetWindowUserPointer(handle)
	input := cast(^Input)window.input_ptr

	input.scroll_delta.x += x
	input.scroll_delta.y += y

	context = window.ctx
	append(&input.events, Scroll_Event {
		delta = {x, y},
	})
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

mouse_button_from_glfw :: proc "contextless" (code: c.int) -> (button: Mouse_Button, ok: bool) {
	if code < 0 || code > glfw.MOUSE_BUTTON_LAST {
		return
	}
	return Mouse_Button(code), true
}

@(private = "file")
button_action_from_glfw :: proc "contextless" (action: c.int) -> (Button_Action, bool) {
	switch action {
	case glfw.PRESS:
		return .Pressed, true
	case glfw.RELEASE:
		return .Released, true
	case glfw.REPEAT:
		return .Repeated, true
	}
	return {}, false
}

@(private = "file")
modifiers_from_glfw :: proc "contextless" (mods: c.int) -> Modifiers {
	return transmute(Modifiers)(mods & 0x3f)
}
