package brender
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:slice"
import "core:strings"
import "../bindings/slang"
import vk "vendor:vulkan"

Shader_Program_Id :: distinct u32

Shader_Error :: union #shared_nil {
	Slang_Error,
	vk.Result,
}

Slang_Error :: enum {
	None = 0,
	Global_Session_Initialization_Failed,
	Session_Initialization_Failed,
	Profile_Not_Found,
	Module_Load_Failed,
	Specialization_Module_Load_Failed,
	Specialization_Arg_Count_Mismatch,
	Specialization_Type_Not_Found,
	Specialization_Failed,
	Get_Layout_Failed,
	No_Such_Entry_Point,
	Composite_Creation_Failed,
	Linking_Failed,
	Code_Generation_Failed,
}

Shaders :: struct {
	global_session:  ^slang.Global_Session,
	session:         ^slang.Session,
	search_paths:    []string,
	programs:        [dynamic]Shader_Program,
	programs_by_key: map[Shader_Program_Key]Shader_Program_Id,
	allocator:       runtime.Allocator,
}

Type_Specialization_Arg :: struct {
	type_name:   string,
	module_name: string,
}

Expr_Specialization_Arg :: struct {
	expression:  string,
	module_name: string,
}

Specialization_Arg :: union #no_nil {
	Expr_Specialization_Arg,
	Type_Specialization_Arg,
}

get_specialization_arg_module_name :: proc(spec_arg: Specialization_Arg) -> string {
	switch arg in spec_arg {
	case Type_Specialization_Arg:
		return arg.module_name
	case Expr_Specialization_Arg:
		return arg.module_name
	}
	return ""
}

@(private = "file")
Shader_Program_Key :: struct {
	module_name:    string,
	entry_name:     string,
	specialization: string,
	stage:          vk.ShaderStageFlag,
}

@(private = "file")
Shader_Program :: struct {
	module_name:    string,
	entry_name:     cstring,
	specialization: string,
	stage:          vk.ShaderStageFlag,
	module:         vk.ShaderModule,
}

@(require_results)
shaders_init :: proc(
	shaders: ^Shaders,
	search_paths: []string,
	allocator := context.allocator,
) -> (
	err: Slang_Error,
) {
	shaders^ = {}

	result := slang.create_global_session(slang.API_VERSION, &shaders.global_session)
	if result < 0 {
		return .Global_Session_Initialization_Failed
	}
	defer if err != nil {
		shaders_destroy_no_device(shaders)
	}

	shaders.allocator = allocator
	shaders.search_paths = make([]string, len(search_paths), allocator)
	for search_path, i in search_paths {
		shaders.search_paths[i] = strings.clone(search_path, allocator)
	}

	shaders.session = create_slang_session(shaders.global_session, shaders.search_paths) or_return
	shaders.programs = make([dynamic]Shader_Program, allocator)
	shaders.programs_by_key = make(map[Shader_Program_Key]Shader_Program_Id, allocator)
	append(&shaders.programs, Shader_Program{})
	return nil
}

shaders_destroy :: proc(shaders: ^Shaders, device: Device) {
	for program in shaders.programs {
		if program.module != 0 {
			vk.DestroyShaderModule(device.logical, program.module, nil)
		}
	}

	shaders_destroy_no_device(shaders)
}

@(private = "file")
shaders_destroy_no_device :: proc(shaders: ^Shaders) {
	if shaders.session != nil {
		shaders.session->release()
	}

	if shaders.global_session != nil {
		shaders.global_session->release()
	}

	for program in shaders.programs {
		delete(program.module_name, shaders.allocator)
		delete(program.entry_name, shaders.allocator)
	}

	for search_path in shaders.search_paths {
		delete(search_path, shaders.allocator)
	}

	for key, _ in shaders.programs_by_key {
		delete(key.entry_name, shaders.allocator)
		delete(key.specialization, shaders.allocator)
	}

	delete(shaders.search_paths, shaders.allocator)
	delete(shaders.programs)
	delete(shaders.programs_by_key)
	shaders^ = {}
}

@(require_results)
shaders_get_program :: proc(
	shaders: ^Shaders,
	device: Device,
	stage: vk.ShaderStageFlag,
	module: string,
	entry: string,
	specialization_args: []Specialization_Arg = nil,
) -> (
	id: Shader_Program_Id,
	err: Shader_Error,
) {
	specialization := get_specialization_string(specialization_args, context.temp_allocator)
	if program_id, ok := shaders.programs_by_key[{module, entry, specialization, stage}]; ok {
		return program_id, nil
	}

	spirv := load_shader_spirv(shaders.session, module, entry, specialization_args) or_return
	new_module: vk.ShaderModule
	new_module_info := vk.ShaderModuleCreateInfo {
		sType    = .SHADER_MODULE_CREATE_INFO,
		codeSize = slice.size(spirv),
		pCode    = raw_data(spirv),
	}
	vk.CreateShaderModule(device.logical, &new_module_info, nil, &new_module) or_return

	program_id := Shader_Program_Id(len(shaders.programs))
	spec_name := strings.clone(specialization, shaders.allocator)
	module_name := strings.clone(module, shaders.allocator)
	entry_name := strings.clone(entry, shaders.allocator)
	entry_cname := strings.clone_to_cstring(entry, shaders.allocator)
	program_key := Shader_Program_Key {
		module_name    = module_name,
		entry_name     = entry_name,
		specialization = spec_name,
		stage          = stage,
	}
	append(
		&shaders.programs,
		{
			module_name = module_name,
			entry_name = entry_cname,
			specialization = spec_name,
			stage = stage,
			module = new_module,
		},
	)
	shaders.programs_by_key[program_key] = program_id
	return program_id, nil
}

@(private = "file", require_results)
get_specialization_string :: proc(
	specialization_args: []Specialization_Arg,
	allocator := context.allocator,
) -> string {
	builder := strings.builder_make(allocator)
	for specialization_arg in specialization_args {
		switch arg in specialization_arg {
		case Type_Specialization_Arg:
			fmt.sbprintf(&builder, "@@Type@%v@%v", arg.type_name, arg.module_name)
		case Expr_Specialization_Arg:
			fmt.sbprintf(&builder, "@@Expr@%v@%v", arg.expression, arg.module_name)
		}
	}
	return strings.to_string(builder)
}

@(require_results)
shaders_get_stage_info :: proc(
	shaders: Shaders,
	program_id: Shader_Program_Id,
) -> vk.PipelineShaderStageCreateInfo {
	assert(int(program_id) != 0)
	assert(int(program_id) < len(shaders.programs))

	program := shaders.programs[program_id]
	return {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = {program.stage},
		pName = program.entry_name,
		module = program.module,
	}
}

@(private = "file", require_results)
load_shader_spirv :: proc(
	session: ^slang.Session,
	module_name: string,
	entry_name: string,
	spec_args: []Specialization_Arg,
	allocator := context.temp_allocator,
) -> (
	[]u32,
	Slang_Error,
) {
	load_diagnostics: ^slang.Blob
	module_cname := strings.clone_to_cstring(module_name, context.temp_allocator)
	module := session->load_module(module_cname, &load_diagnostics)

	failed := module == nil
	log_diagnostics(load_diagnostics, failed, "loading module '%v'", module_name)
	if failed {
		return nil, .Module_Load_Failed
	}

	spec_modules := make([dynamic]^slang.Module, context.temp_allocator)
	for spec_arg in spec_args {
		spec_module_name := get_specialization_arg_module_name(spec_arg)
		if spec_module_name == "" {
			continue
		}

		spec_load_diagnostics: ^slang.Blob
		spec_module_cname := strings.clone_to_cstring(spec_module_name, context.temp_allocator)
		spec_module := session->load_module(spec_module_cname, &spec_load_diagnostics)

		spec_failed := spec_module == nil
		log_diagnostics(
			spec_load_diagnostics,
			spec_failed,
			"loading specialization module '%v'",
			spec_module_name,
		)
		if spec_failed {
			return nil, .Specialization_Module_Load_Failed
		}

		if spec_module != module && !slice.contains(spec_modules[:], spec_module) {
			append(&spec_modules, spec_module)
		}
	}

	entry_point: ^slang.Entry_Point
	entry_cname := strings.clone_to_cstring(entry_name, context.temp_allocator)
	result := module->find_entry_point_by_name(entry_cname, &entry_point)
	if result < 0 || entry_point == nil {
		log.errorf("No such entry point '%v' for module '%v'", entry_name, module_name)
		return nil, .No_Such_Entry_Point
	}

	component_types := make(
		[dynamic]^slang.Component_Type,
		0,
		len(spec_modules) + 2,
		context.temp_allocator,
	)
	append(&component_types, module)
	for spec_module in spec_modules {
		append(&component_types, spec_module)
	}
	append(&component_types, entry_point)

	composite: ^slang.Component_Type
	composite_diagnostics: ^slang.Blob
	result = session->create_composite_component_type(
		raw_data(component_types),
		len(component_types),
		&composite,
		&composite_diagnostics,
	)
	entry_point->release()

	failed = result < 0 || composite == nil
	log_diagnostics(
		composite_diagnostics,
		failed,
		"creating composite from module '%v' and entry point '%v'",
		module_name,
		entry_name,
	)
	if failed {
		return nil, .Composite_Creation_Failed
	}

	expected_arg_count := composite->get_specialization_param_count()
	if expected_arg_count != len(spec_args) {
		composite->release()
		log.errorf(
			"Mismatch between the specialization requirements of the entry point '%v' " +
			"from module '%v', which expects %v parameters, and the given arguments, " +
			"which were %v",
			entry_name,
			module_name,
			expected_arg_count,
			len(spec_args),
		)
		return nil, .Specialization_Arg_Count_Mismatch
	}

	layout_diagnostics: ^slang.Blob
	layout := composite->get_layout(0, &layout_diagnostics)
	failed = layout == nil
	log_diagnostics(
		layout_diagnostics,
		failed,
		"getting program layout from module '%v' and entry point '%v'",
		module_name,
		entry_name,
	)
	if failed {
		composite->release()
		return nil, .Get_Layout_Failed
	}

	args := make([dynamic]slang.Specialization_Arg, 0, len(spec_args), context.temp_allocator)
	for spec_arg in spec_args {
		switch arg in spec_arg {
		case Type_Specialization_Arg:
			type_cname := strings.clone_to_cstring(arg.type_name, context.temp_allocator)
			type := slang.reflection_find_type_by_name(layout, type_cname)
			if type == nil {
				composite->release()
				log.errorf(
					"Failed to find specialization type '%v' for module '%v' and entry point '%v'. " +
					"Type expected in module '%v'",
					arg.type_name,
					module_name,
					entry_name,
					arg.module_name,
				)
				return nil, .Specialization_Type_Not_Found
			}
			append(&args, {kind = .Type, type = type})
		case Expr_Specialization_Arg:
			cexpr := strings.clone_to_cstring(arg.expression, context.temp_allocator)
			append(&args, {kind = .Expr, expr = cexpr})
		}
	}

	specialization_diagnostics: ^slang.Blob
	specialized: ^slang.Component_Type
	result = composite->specialize(
		raw_data(args),
		len(args),
		&specialized,
		&specialization_diagnostics,
	)
	composite->release()
	failed = result < 0 || specialized == nil
	log_diagnostics(
		specialization_diagnostics,
		failed,
		"specializing entry point '%v' from module '%v'",
		entry_name,
		module_name,
	)
	if failed {
		return nil, .Specialization_Failed
	}

	link_diagnostics: ^slang.Blob
	linked: ^slang.Component_Type
	result = specialized->link(&linked, &link_diagnostics)
	specialized->release()
	failed = result < 0 || linked == nil
	log_diagnostics(
		link_diagnostics,
		failed,
		"linking composite from module '%v' and entry point '%v'",
		module_name,
		entry_name,
	)
	if failed {
		return nil, .Linking_Failed
	}

	code_diagnostics: ^slang.Blob
	code_blob: ^slang.Blob
	result = linked->get_entry_point_code(0, 0, &code_blob, &code_diagnostics)
	linked->release()
	failed = result < 0 || code_blob == nil
	log_diagnostics(
		code_diagnostics,
		failed,
		"generating code from module '%v' and entry point '%v'",
		module_name,
		entry_name,
	)
	if failed {
		return nil, .Code_Generation_Failed
	}

	code_blob_spirv := blob_to_spirv(code_blob)
	code_spirv := slice.clone(code_blob_spirv, allocator)
	code_blob->release()
	return code_spirv, nil
}

@(private = "file")
log_diagnostics :: proc(
	blob: ^slang.Blob,
	failed: bool,
	format: string,
	args: ..any,
	location := #caller_location,
) {
	message := fmt.tprintf(format, ..args)

	if blob != nil {
		if failed {
			log.errorf("Failure when %v:\n%v", message, blob_to_string(blob), location = location)
		} else {
			log.warnf(
				"Diagnostics from %v:\n%v",
				message,
				blob_to_string(blob),
				location = location,
			)
		}
		blob->release()
	} else if failed {
		log.errorf("Failure when %v", message, location = location)
	}
}

@(private = "file", require_results)
create_slang_session :: proc(
	global_session: ^slang.Global_Session,
	search_paths: []string,
) -> (
	^slang.Session,
	Slang_Error,
) {
	profile := global_session->find_profile("spirv_1_4")
	if profile == slang.PROFILE_UNKNOWN {
		return nil, .Profile_Not_Found
	}

	target_desc := slang.Target_Desc {
		structure_size = size_of(slang.Target_Desc),
		format         = .SPIRV,
		profile        = profile,
		flags          = {.Generate_SPIRV_Directly},
	}

	compiler_options := []slang.Compiler_Option_Entry {
		{name = .Vulkan_Use_Entry_Point_Name, value = {kind = .Int, int_value_0 = 1}},
		{name = .GLSL_Force_Scalar_Layout, value = {kind = .Int, int_value_0 = 1}},
	}

	session_search_paths := make([]cstring, len(search_paths), context.temp_allocator)
	for search_path, i in search_paths {
		session_search_paths[i] = strings.clone_to_cstring(search_path, context.temp_allocator)
	}

	session_desc := slang.Session_Desc {
		structure_size              = size_of(slang.Session_Desc),
		default_matrix_layout_mode  = .Column_Major,
		search_paths                = raw_data(session_search_paths),
		search_path_count           = len(session_search_paths),
		compiler_option_entries     = raw_data(compiler_options),
		compiler_option_entry_count = u32(len(compiler_options)),
		targets                     = &target_desc,
		target_count                = 1,
	}

	session: ^slang.Session
	result := global_session->create_session(session_desc, &session)
	if result < 0 {
		return nil, .Session_Initialization_Failed
	}

	return session, nil
}

blob_to_string :: proc(blob: ^slang.Blob) -> string {
	bytes := cast([^]byte)blob->get_buffer_pointer()
	size := int(blob->get_buffer_size())
	if size > 0 && bytes[size - 1] == 0 {
		size -= 1
	}
	return strings.string_from_ptr(bytes, size)
}

blob_to_spirv :: proc(blob: ^slang.Blob) -> []u32 {
	spirv_raw := cast([^]u32)blob->get_buffer_pointer()
	return spirv_raw[:blob->get_buffer_size() / size_of(u32)]
}
