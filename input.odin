package basalt

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

Button_State :: enum {
	Just_Pressed,
	Just_Released,
	Pressed,
	Released,
}

Input_State :: struct {
	keys_current:           bit_set[Key],
	keys_previous:          bit_set[Key],
	mouse_buttons_current:  bit_set[Mouse_Button],
	mouse_buttons_previous: bit_set[Mouse_Button],
	cursor_position:        [2]f64,
	cursor_delta:           [2]f64,
	scroll_delta:           [2]f64,
}

input_get_key :: proc(input: ^Input_State, key: Key) -> bit_set[Button_State] {
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

input_get_mouse_button :: proc(
	input: ^Input_State,
	button: Mouse_Button,
) -> bit_set[Button_State] {
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
