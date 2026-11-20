package build
import "core:flags"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"

BUILD_OUT :: "build"

VMA_DIR :: "third_party/vma"
VMA_VK_VERSION :: "3"
VMA_PREMAKE_ACTION_WINDOWS :: "vs2022"

Toggle :: enum {
	auto,
	on,
	off,
}

Build_Example_Options :: struct {
	example:         string `args:"pos=0" usage:"Example to build."`,
	run:             bool `usage:"Run example."`,
	release:         bool `usage:"Optimized build (-o:speed) instead of a debug build."`,
	debug_symbols:   bool `usage:"Output debug symbols on release mode"`,
	validation:      Toggle `usage:"Vulkan validation layer: auto (on in debug), on, off."`,
	sync_validation: Toggle `usage:"Synchronization validation: auto (on in debug), on, off."`,
}

Build_Deps_Options :: struct {
	clean: bool `usage:"Clean dependencies"`,
}

Test_Options :: struct {}

main :: proc() {
	if len(os.args) < 2 {
		fmt.eprintln("usage: build <test|deps|example> [options]")
		os.exit(1)
	}

	sub_args := os.args[1:]
	switch os.args[1] {
	case "test":
		options: Test_Options
		flags.parse_or_exit(&options, sub_args, .Odin)
		catch_alloc_err(build_vma())
		catch_alloc_err(test(options))
	case "deps":
		options: Build_Deps_Options
		flags.parse_or_exit(&options, sub_args, .Odin)
		if options.clean {
			catch_alloc_err(clean_vma())
		} else {
			catch_alloc_err(build_vma())
		}
	case "example":
		options: Build_Example_Options
		flags.parse_or_exit(&options, sub_args, .Odin)
		catch_alloc_err(build_vma())
		if options.example == "" {
			fmt.eprintln("No example given, here is a list of examples you can run:")
			catch_alloc_err(list_examples())
		} else {
			catch_alloc_err(build_example(options))
		}
	case:
		fmt.eprintln("usage: build <test|deps|example> [options]")
		os.exit(1)
	}
}

catch_alloc_err :: proc(err: mem.Allocator_Error) {
	if err != nil {
		fmt.eprintfln("Out of memory: %v", err)
		os.exit(1)
	}
}

clean_vma :: proc() -> mem.Allocator_Error {
	fmt.eprintln("Cleaning VMA")

	vma_dir := filepath.join({#directory, "..", VMA_DIR}, context.temp_allocator) or_return
	files, err := os.read_all_directory_by_path(vma_dir, context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to read directory '%s': %v", vma_dir, err)
		os.exit(1)
	}

	for file in files {
		ext := filepath.ext(file.name)
		if (strings.has_prefix(file.name, "vma_") && ext == ".a") ||
		   (strings.has_prefix(file.name, "libvma_") && ext == ".a") ||
		   (strings.has_prefix(file.name, "vma_") && ext == ".lib") {
			os.remove(file.fullpath)
		}
	}

	os.remove_all(filepath.join({vma_dir, "build"}, context.temp_allocator) or_return)
	return nil
}

build_vma :: proc() -> mem.Allocator_Error {
	vma_dir := filepath.join({#directory, "..", VMA_DIR}, context.temp_allocator) or_return
	if vma_is_built(vma_dir) {
		return nil
	}

	premake_script_path := filepath.join(
		{vma_dir, "premake5.lua"},
		context.temp_allocator,
	) or_return
	if !os.exists(premake_script_path) {
		fmt.eprintfln(
			"VMA submodule is empty, please run 'git submodule update --init --recursive'",
		)
		os.exit(1)
	}

	fmt.eprintln("Building VMA")
	vk_version_arg := fmt.tprintf("--vk-version=%s", VMA_VK_VERSION)
	when ODIN_OS == .Windows {
		install_dir, found := os.lookup_env("VCINSTALLDIR", context.temp_allocator)
		if !found || install_dir == "" {
			fmt.eprintln(
				"The MSVC environment is not loaded: run this from an " +
				"x64 Native Tools Command Prompt, or run vcvars64.bat first",
			)
			os.exit(1)
		}

		arch, _ := os.lookup_env("VSCMD_ARG_TGT_ARCH", context.temp_allocator)
		if arch != "x64" {
			fmt.eprintfln(
				"The MSVC environment targets '%s', but this build needs x64: use vcvars64.bat",
				arch,
			)
			os.exit(1)
		}

		run({"premake5", vk_version_arg, VMA_PREMAKE_ACTION_WINDOWS}, vma_dir)
		run({"cmd", "/c", "build.bat"}, fmt.tprintf("%s/build", vma_dir))
	} else {
		platform, config: string
		when ODIN_OS == .Darwin {
			platform = "macosx"
			config = "release_arm64" if ODIN_ARCH == .arm64 else "release_x86_64"
		} else {
			platform = "linux"
			config = "release_arm64" if ODIN_ARCH == .arm64 else "release_x86_64"
		}

		run({"premake5", vk_version_arg, "gmake"}, vma_dir)
		run(
			{"make", fmt.tprintf("config=%s", config)},
			filepath.join({vma_dir, "build", "make", platform}, context.temp_allocator) or_return,
		)
	}

	if !vma_is_built(vma_dir) {
		fmt.eprintfln("VMA build finished but no library was found in '%s'", vma_dir)
		os.exit(1)
	}

	return nil
}

vma_is_built :: proc(vma_dir: string) -> bool {
	files, err := os.read_all_directory_by_path(vma_dir, context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to read directory '%s': %v", vma_dir, err)
		os.exit(1)
	}

	for file in files {
		ext := filepath.ext(file.name)
		if (strings.has_prefix(file.name, "vma_") && ext == ".a") ||
		   (strings.has_prefix(file.name, "libvma_") && ext == ".a") ||
		   (strings.has_prefix(file.name, "vma_") && ext == ".lib") {
			return true
		}
	}
	return false
}

list_examples :: proc() -> mem.Allocator_Error {
	example_dir := filepath.join({#directory, "..", "examples"}, context.temp_allocator) or_return
	files, err := os.read_all_directory_by_path(example_dir, context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to read directory '%s': %v", example_dir, err)
		os.exit(1)
	}

	for file in files {
		if file.type == .Directory {
			fmt.eprintfln(" * %s", file.name)
		}
	}

	return nil
}

test :: proc(options: Test_Options) -> mem.Allocator_Error {
	project_dir := filepath.join({#directory, ".."}, context.temp_allocator) or_return

	out_dir := filepath.join({project_dir, BUILD_OUT, "tests"}, context.temp_allocator) or_return
	out_path := filepath.join({out_dir, "basalt"}, context.temp_allocator) or_return
	when ODIN_OS == .Windows {
		out_path = fmt.tprintf("%s.exe", out_path)
	}

	_ = os.make_directory_all(out_dir)

	args := make([dynamic]string, context.temp_allocator)
	append(&args, "odin", "test", project_dir)
	append(&args, "-debug", "-vet", "-strict-style", "-disallow-do", "-warnings-as-errors")
	append(&args, fmt.tprintf("-out:%s", out_path))
	append_toggle_define(&args, "ENABLE_VALIDATION", .on)
	append_toggle_define(&args, "ENABLE_SYNC_VALIDATION", .on)
	append_vulkan_sdk_link_flags(&args)

	run(args[:])
	return nil
}

build_example :: proc(options: Build_Example_Options) -> mem.Allocator_Error {
	project_dir := filepath.join({#directory, ".."}, context.temp_allocator) or_return
	example_path := filepath.join(
		{project_dir, "examples", options.example},
		context.temp_allocator,
	) or_return
	if !os.exists(example_path) {
		fmt.eprintfln("Example '%v' does not exist", options.example)
		os.exit(1)
	}

	mode := "release" if options.release else "debug"
	out_dir := filepath.join({project_dir, BUILD_OUT, mode}, context.temp_allocator) or_return
	out_path := filepath.join({out_dir, options.example}, context.temp_allocator) or_return
	when ODIN_OS == .Windows {
		out_path = fmt.tprintf("%s.exe", out_path)
	}

	_ = os.make_directory_all(out_dir)

	args := make([dynamic]string, context.temp_allocator)
	append(&args, "odin", "build", example_path)
	if options.release {
		append(&args, "-o:speed")
	}
	if !options.release || options.debug_symbols {
		append(&args, "-debug")
	}
	append(&args, "-vet", "-strict-style", "-disallow-do", "-warnings-as-errors")
	append(&args, fmt.tprintf("-out:%s", out_path))
	append_toggle_define(&args, "ENABLE_VALIDATION", options.validation)
	append_toggle_define(&args, "ENABLE_SYNC_VALIDATION", options.sync_validation)
	append_vulkan_sdk_link_flags(&args)

	fmt.eprintfln(
		"Building example '%s' (%s, validation: %v, sync validation: %v)",
		options.example,
		mode,
		options.validation,
		options.sync_validation,
	)

	run(args[:])
	if options.run {
		run({out_path}, project_dir)
	}
	return nil
}

append_vulkan_sdk_link_flags :: proc(args: ^[dynamic]string) {
	sdk, found := os.lookup_env("VULKAN_SDK", context.temp_allocator)
	if !found || sdk == "" {
		fmt.eprintln(
			"VULKAN_SDK is not set: please install the Vulkan SDK or run its setup script",
		)
		os.exit(1)
	}

	when ODIN_OS == .Windows {
		lib_dir, _ := filepath.join({sdk, "Lib"}, context.temp_allocator)
		append(args, fmt.tprintf("-extra-linker-flags:/LIBPATH:\"%s\"", lib_dir))
	} else {
		lib_dir, _ := filepath.join({sdk, "lib"}, context.temp_allocator)
		append(
			args,
			fmt.tprintf("-extra-linker-flags:-L\"%s\" -Wl,-rpath,\"%s\"", lib_dir, lib_dir),
		)
	}
}

append_toggle_define :: proc(args: ^[dynamic]string, name: string, toggle: Toggle) {
	switch toggle {
	case .auto:
	case .on:
		append(args, fmt.tprintf("-define:%s=true", name))
	case .off:
		append(args, fmt.tprintf("-define:%s=false", name))
	}
}

run :: proc(command: []string, working_dir := "") {
	process, start_err := os.process_start(
		{command = command, working_dir = working_dir, stdout = os.stdout, stderr = os.stderr},
	)
	if start_err != nil {
		fmt.eprintfln("Failed to launch '%s': %v", command[0], start_err)
		os.exit(1)
	}

	state, wait_err := os.process_wait(process)
	if wait_err != nil {
		fmt.eprintfln("Failed to wait for process '%s': %v", command[0], wait_err)
		os.exit(1)
	}

	if state.exit_code != 0 {
		fmt.eprintfln("'%s' failed", command[0])
		os.exit(state.exit_code)
	}
}
