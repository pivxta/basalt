package slang
foreign import "system:slang"

API_VERSION :: 0

Result :: i32
Bool :: bool
Int :: int
UInt :: uint

File_System :: struct {}

Matrix_Layout_Mode :: enum u32 {
	Unknown,
	Row_Major,
	Column_Major,
}

Compile_Target :: enum i32 {
	Unknown = 0,
	None = 1,
	GLSL = 2,
	GLSL_Vulkan_Deprecated = 3,
	GLSL_Vulkan_One_Desc_Deprecated = 4,
	HLSL = 5,
	SPIRV = 6,
	SPIRV_Asm = 7,
	DXBC = 8,
	DXBC_Asm = 9,
	DXIL = 10,
	DXIL_Asm = 11,
	C_Source = 12,
	CPP_Source = 13,
	Host_Executable = 14,
	Shader_Shared_Library = 15,
	Shader_Host_Callable = 16,
	CUDA_Source = 17,
	PTX = 18,
	CUDA_Object_Code = 19,
	Object_Code = 20,
	Host_CPP_Source = 21,
	Host_Host_Callable = 22,
	CPP_PyTorch_Binding = 23,
	Metal = 24,
	Metal_Lib = 25,
	Metal_Lib_Asm = 26,
	Host_Shared_Library = 27,
	WGSL = 28,
	WGSL_SPIRV_Asm = 29,
	WGSL_SPIRV = 30,
	Host_VM = 31,
	CPP_Header = 32,
	CUDA_Header = 33,
	Host_Object_Code = 34,
	Host_LLVM_IR = 35,
	Shader_LLVM_IR = 36,
	Count_Of,
}

Profile_Id :: distinct u32
PROFILE_UNKNOWN :: Profile_Id(0)

Target_Flags :: bit_set[Target_Flag; u32]

Target_Flag :: enum {
	Parameter_Blocks_Use_Register_Spaces = 4,
	Generate_Whole_Program = 8,
	Dump_IR = 9,
	Generate_SPIRV_Directly = 10,
}

Floating_Point_Mode :: enum u32 {
	Default = 0,
	Fast = 1,
	Precise = 2,
}

Line_Directive_Mode :: enum u32 {
	Default = 0,
	None = 1,
	Standard = 2,
	Glsl = 3,
	Source_Map = 4,
}

Compiler_Option_Name :: enum i32 {
	Macro_Define = 0,
	Dep_File = 1,
	Entry_Point_Name = 2,
	Specialize = 3,
	Help = 4,
	Help_Style = 5,
	Include = 6,
	Language = 7,
	Matrix_Layout_Column = 8,
	Matrix_Layout_Row = 9,
	Zero_Initialize = 10,
	Ignore_Capabilities = 11,
	Restrictive_Capability_Check = 12,
	Module_Name = 13,
	Output = 14,
	Profile = 15,
	Stage = 16,
	Target = 17,
	Version = 18,
	Warnings_As_Errors = 19,
	Disable_Warnings = 20,
	Enable_Warning = 21,
	Disable_Warning = 22,
	Dump_Warning_Diagnostics = 23,
	Input_Files_Remain = 24,
	Emit_Ir = 25,
	Report_Downstream_Time = 26,
	Report_Perf_Benchmark = 27,
	Report_Checkpoint_Intermediates = 28,
	Skip_SPIRV_Validation = 29,
	Source_Embed_Style = 30,
	Source_Embed_Name = 31,
	Source_Embed_Language = 32,
	Disable_Short_Circuit = 33,
	Minimum_Slang_Optimization = 34,
	Disable_Non_Essential_Validations = 35,
	Disable_Source_Map = 36,
	Unscoped_Enum = 37,
	Preserve_Parameters = 38,
	Capability = 39,
	Default_Image_Format_Unknown = 40,
	Disable_Dynamic_Dispatch = 41,
	Disable_Specialization = 42,
	Floating_Point_Mode = 43,
	Debug_Information = 44,
	Line_Directive_Mode = 45,
	Optimization = 46,
	Obfuscate = 47,
	Vulkan_Bind_Shift = 48,
	Vulkan_Bind_Globals = 49,
	Vulkan_Invert_Y = 50,
	Vulkan_Use_Dx_Position_W = 51,
	Vulkan_Use_Entry_Point_Name = 52,
	Vulkan_Use_GL_Layout = 53,
	Vulkan_Emit_Reflection = 54,
	GLSL_Force_Scalar_Layout = 55,
	Enable_Effect_Annotations = 56,
	Emit_Spirv_Via_GLSL = 57,
	Emit_Spirv_Directly = 58,
	SPIRV_Core_Grammar_JSON = 59,
	Incomplete_Library = 60,
	Compiler_Path = 61,
	Default_Downstream_Compiler = 62,
	Downstream_Args = 63,
	Pass_Through = 64,
	Dump_Repro = 65,
	Dump_Repro_On_Error = 66,
	Extract_Repro = 67,
	Load_Repro = 68,
	Load_Repro_Directory = 69,
	Repro_Fallback_Directory = 70,
	Dump_Ast = 71,
	Dump_Intermediate_Prefix = 72,
	Dump_Intermediates = 73,
	Dump_Ir = 74,
	Dump_Ir_Ids = 75,
	Preprocessor_Output = 76,
	Output_Includes = 77,
	Repro_File_System = 78,
	REMOVED_Serial_IR = 79,
	Skip_Code_Gen = 80,
	Validate_Ir = 81,
	Verbose_Paths = 82,
	Verify_Debug_Serial_Ir = 83,
	No_Code_Gen = 84,
	File_System = 85,
	Heterogeneous = 86,
	No_Mangle = 87,
	No_HLSL_Binding = 88,
	No_HLSL_Pack_Constant_Buffer_Elements = 89,
	Validate_Uniformity = 90,
	Allow_GLSL = 91,
	Enable_Experimental_Passes = 92,
	Bindless_Space_Index = 93,
	SPIRV_Resource_Heap_Stride = 94,
	SPIRV_Sampler_Heap_Stride = 95,
	Archive_Type = 96,
	Compile_Core_Module = 97,
	Doc = 98,
	Ir_Compression = 99,
	Load_Core_Module = 100,
	Reference_Module = 101,
	Save_Core_Module = 102,
	Save_Core_Module_Bin_Source = 103,
	Track_Liveness = 104,
	Loop_Inversion = 105,
	Parameter_Blocks_Use_Register_Spaces = 106,
	Language_Version = 107,
	Type_Conformance = 108,
	Enable_Experimental_Dynamic_Dispatch = 109,
	Emit_Reflection_JSON = 110,
	Count_Of_Parsable_Options = 111,
	Debug_Information_Format = 112,
	Vulkan_Bind_Shift_All = 113,
	Generate_Whole_Program = 114,
	Use_Up_To_Date_Binary_Module = 115,
	Embed_Downstream_IR = 116,
	Force_DX_Layout = 117,
	Emit_Spirv_Method = 118,
	Save_GLSL_Module_Bin_Source = 119,
	Skip_Downstream_Linking = 120,
	Dump_Module = 121,
	Get_Module_Info = 122,
	Get_Supported_Module_Versions = 123,
	Emit_Separate_Debug = 124,
	Denormal_Mode_Fp16 = 125,
	Denormal_Mode_Fp32 = 126,
	Denormal_Mode_Fp64 = 127,
	Use_MSVC_Style_Bitfield_Packing = 128,
	Force_C_Layout = 129,
	Experimental_Feature = 130,
	Report_Detailed_Perf_Benchmark = 131,
	Validate_IR_Detailed = 132,
	Dump_IR_Before = 133,
	Dump_IR_After = 134,
	Emit_CPU_Method = 135,
	Emit_CPU_Via_CPP = 136,
	Emit_CPU_Via_LLVM = 137,
	LLVM_Target_Triple = 138,
	LLVM_CPU = 139,
	LLVM_Features = 140,
	Enable_Rich_Diagnostics = 141,
	Report_Dynamic_Dispatch_Sites = 142,
	Enable_Machine_Readable_Diagnostics = 143,
	Diagnostic_Color = 144,
	Trace_Coverage = 145,
	Trace_Coverage_Binding = 146,
	Trace_Coverage_Reserved_Space = 147,
	Trace_Function_Coverage = 148,
	Trace_Branch_Coverage = 149,
	Coverage_Manifest_Output = 150,
	Trace_Coverage_Counter_Byte_Width = 151,
	Trace_Coverage_Boolean = 152,
	SPIRV_Unified_Descriptor_Heap_Stride = 154,
	Warning_Level = 155,
	Separate_Debug_Info_Output = 156,
	Debug_Info_Include_Source = 157,
	Trace_Coverage_Bindless_Index = 158,
	Get_Compiler_Path = 159,
}

Compiler_Option_Value_Kind :: enum i32 {
	Int = 0,
	String = 1,
}

#assert(size_of(rawptr) != 8 || size_of(Compiler_Option_Value) == 32)
Compiler_Option_Value :: struct {
	kind: Compiler_Option_Value_Kind,
	int_value_0: i32,
	int_value_1: i32,
	string_value_0: cstring,
	string_value_1: cstring,
}

#assert(size_of(rawptr) != 8 || size_of(Compiler_Option_Entry) == 40)
Compiler_Option_Entry :: struct {
	name: Compiler_Option_Name,
	value: Compiler_Option_Value,
}

#assert(size_of(rawptr) != 8 || size_of(Target_Desc) == 48)
Target_Desc :: struct {
	structure_size: uint,
	format: Compile_Target,
	profile: Profile_Id,
	flags: Target_Flags,
	floating_point_mode: Floating_Point_Mode,
	line_directive_mode: Line_Directive_Mode,
	force_glsl_scaler_buffer_layout: bool,
	compiler_option_entry: [^]Compiler_Option_Entry,
	compiler_option_entry_count: u32,
}

#assert(size_of(rawptr) != 8 || size_of(Preprocessor_Macro_Desc) == 16)
Preprocessor_Macro_Desc :: struct {
	name: cstring,
	value: cstring,
}

#assert(size_of(rawptr) != 8 || size_of(Session_Desc) == 96)
Session_Desc :: struct {
	structure_size: uint,
	targets: [^]Target_Desc,
	target_count: Int,
	session_flags: u32,
	default_matrix_layout_mode: Matrix_Layout_Mode,
	search_paths: [^]cstring,
	search_path_count: Int,
	preprocessor_macros: [^]Preprocessor_Macro_Desc,
	preprocessor_macro_count: Int,
	file_system: ^File_System,
	enable_effect_annotations: bool,
	allow_glsl_syntax: bool,
	compiler_option_entries: [^]Compiler_Option_Entry,
	compiler_option_entry_count: u32,
	skip_spirv_validation: bool,
}

Specialization_Arg_Kind :: enum i32 {
	Unknown = 0,
	Type = 1,
	Expr = 2,
}

#assert(size_of(rawptr) != 8 || size_of(Specialization_Arg) == 16)
Specialization_Arg :: struct {
	kind: Specialization_Arg_Kind,
	using value: struct #raw_union {
		type: ^Type_Reflection,
		expr: cstring,
	},
}

Type_Reflection :: struct {}

Reflection :: struct {}

Program_Layout :: Reflection

Unknown :: struct {
	using vtable: ^Unknown_Vtable,
}

Unknown_Vtable :: struct {
	query_interface: rawptr,
	add_ref: proc "system" (unknown: ^Unknown) -> u32,
	release: proc "system" (unknown: ^Unknown) -> u32,
}

Component_Type :: struct #raw_union {
	#subtype unknown: Unknown,
	using vtable: ^Component_Type_Vtable,
}

Component_Type_Vtable :: struct {
	using unknown_vtable: Unknown_Vtable,
	get_session: proc "system" (this: ^Component_Type) -> ^Session,
	get_layout: proc "system" (
		this: ^Component_Type,
		target_index: Int,
		out_diagnostics: ^^Blob,
	) -> ^Program_Layout,
	get_specialization_param_count: proc "system" (
		this: ^Component_Type,
	) -> Int,
	get_entry_point_code: proc "system" (
		this: ^Component_Type,
		entry_point_index: Int,
		target_index: Int,
		out_code: ^^Blob,
		out_diagnostics: ^^Blob,
	) -> Result,
	get_result_as_file_system: rawptr,
	get_entry_point_hash: proc "system" (
		this: ^Component_Type, 
		entry_point_index: Int,
		target_index: Int,
		out_hash: ^^Blob,
	),
	specialize: proc "system" (
		this: ^Component_Type, 
		specialization_args: [^]Specialization_Arg,
		specialization_arg_count: Int,
		out_specialized_component_type: ^^Component_Type,
		out_diagnostics: ^^Blob,
	) -> Result,
	link: proc "system" (
		this: ^Component_Type, 
		out_linked_component_type: ^^Component_Type,
		out_diagnostics: ^^Blob,
	) -> Result,
	get_entry_point_host_callable: rawptr,
	rename_entry_point,
	link_with_options: rawptr,
	get_target_code: rawptr,
	get_target_metadata: rawptr,
	get_entry_point_metadata: rawptr,
}

Blob :: struct #raw_union {
    #subtype unknown: Unknown,
	using vtable: ^struct {
		using unknown_vtable: Unknown_Vtable,
		get_buffer_pointer: proc "system" (this: ^Blob) -> rawptr,
		get_buffer_size: proc "system" (this: ^Blob) -> uint,
	},
}

Entry_Point :: struct #raw_union {
	#subtype component_type: Component_Type,
	using vtable: ^struct {
		using component_type_vtable: Component_Type_Vtable,
	},
}

Module :: struct #raw_union {
	#subtype component_type: Component_Type,
	using vtable: ^struct {
		using component_type_vtable: Component_Type_Vtable,
		find_entry_point_by_name: proc "system" (
			this: ^Module,
			name: cstring, 
			out_entry_point: ^^Entry_Point,
		) -> Result,
	},
}

Session :: struct #raw_union {
    #subtype unknown: Unknown,
	using vtable: ^struct {
		using unknown_vtable: Unknown_Vtable,
		get_global_session: proc "system" (this: ^Session) -> ^Global_Session,
		load_module: proc "system" (
			this: ^Session, 
			name: cstring, 
			out_diagnostics: ^^Blob,
		) -> ^Module,
		load_module_from_source: proc "system" (
			this: ^Session,
			module_name: cstring,
			path: cstring,
			source: ^Blob,
			out_diagnostics: ^^Blob,
		),
		create_composite_component_type: proc "system" (
			this: ^Session,
			component_types: [^]^Component_Type,
			component_type_count: Int,
			out_composite_component_type: ^^Component_Type,
			out_diagnostics: ^^Blob,
		) -> Result,
	},
}

Global_Session :: struct #raw_union {
	#subtype unknown: Unknown,
	using vtable: ^struct {
		using unknown_vtable: Unknown_Vtable,

		create_session: proc "system" (
			this: ^Global_Session, 
			#by_ptr session_desc: Session_Desc, 
			session: ^^Session,
		) -> Result,

		find_profile: proc "system" (this: ^Global_Session, name: cstring) -> Profile_Id,
		set_downstream_compiler_path: rawptr,
		set_downstream_compiler_prelude: rawptr,
		get_downstream_compiler_prelude: rawptr,
		get_build_tag_string: proc "system" (this: ^Global_Session) -> cstring,
	},
}

@(default_calling_convention = "c")
foreign slang {
	@(link_name = "slang_createGlobalSession")
	create_global_session :: proc(
		api_version: Int, 
		out_global_session: ^^Global_Session,
	) -> Result ---

	@(link_name = "spReflection_FindTypeByName")
	reflection_find_type_by_name :: proc(
		reflection: ^Reflection,
		name: cstring,
	) -> ^Type_Reflection ---
}
