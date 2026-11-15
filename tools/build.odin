package build

import "core:flags"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

BUILD_OUT :: "build"
PROGRAM_NAME :: "render"

VMA_DIR :: "third_party/vma"
VMA_VK_VERSION :: "3"
VMA_PREMAKE_ACTION_WINDOWS :: "vs2022"

Toggle :: enum {
	auto,
	on,
	off,
}

Options :: struct {
	release:         bool `usage:"Optimized build (-o:speed) instead of a debug build."`,
	validation:      Toggle `usage:"Vulkan validation layer: auto (on in debug), on, off."`,
	sync_validation: Toggle `usage:"Synchronization validation: auto (on in debug), on, off."`,
}

main :: proc() {
	options: Options
	flags.parse_or_exit(&options, os.args, .Odin)

	build_vma()
	build_program(options)
}

build_vma :: proc() {
	if vma_is_built() {
		return
	}

	fmt.eprintln("Building VMA")

	vk_version_arg := fmt.tprintf("--vk-version=%s", VMA_VK_VERSION)

	when ODIN_OS == .Windows {
		// Needs the MSVC toolchain on PATH, so run this from a shell with vcvars64 loaded.
		run({"premake5", vk_version_arg, VMA_PREMAKE_ACTION_WINDOWS}, VMA_DIR)
		run({"cmd", "/c", "build.bat"}, fmt.tprintf("%s/build", VMA_DIR))
	} else {
		platform, config: string
		when ODIN_OS == .Darwin {
			platform = "macosx"
			config = "release_arm64" if ODIN_ARCH == .arm64 else "release_x86_64"
		} else {
			platform = "linux"
			config = "release_x86_64"
		}

		run({"premake5", vk_version_arg, "gmake"}, VMA_DIR)
		run(
			{"make", fmt.tprintf("config=%s", config)},
			fmt.tprintf("%s/build/make/%s", VMA_DIR, platform),
		)
	}

	if !vma_is_built() {
		fmt.eprintfln("VMA build finished but no library was found in '%s'", VMA_DIR)
		os.exit(1)
	}
}

vma_is_built :: proc() -> bool {
	files, err := os.read_all_directory_by_path(VMA_DIR, context.temp_allocator)
	if err != nil {
		fmt.eprintfln("Failed to read directory '%s': %v", VMA_DIR, err)
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

build_program :: proc(options: Options) {
	mode := "release" if options.release else "debug"
	out_dir := fmt.tprintf("%s/%s", BUILD_OUT, mode)
	_ = os.make_directory_all(out_dir)

	args := make([dynamic]string, context.temp_allocator)
	append(&args, "odin", "build", ".")
	append(&args, "-o:speed" if options.release else "-debug")
	append(&args, "-vet", "-strict-style", "-disallow-do", "-warnings-as-errors")
	append(&args, fmt.tprintf("-out:%s/%s", out_dir, PROGRAM_NAME))
	append_toggle_define(&args, "ENABLE_VALIDATION", options.validation)
	append_toggle_define(&args, "ENABLE_SYNC_VALIDATION", options.sync_validation)
	append_vulkan_sdk_link_flags(&args)

	fmt.eprintfln(
		"Building %s (%s, validation: %v, sync validation: %v)",
		PROGRAM_NAME,
		mode,
		options.validation,
		options.sync_validation,
	)
	run(args[:])
}

append_vulkan_sdk_link_flags :: proc(args: ^[dynamic]string) {
	sdk, found := os.lookup_env("VULKAN_SDK", context.temp_allocator)
	if !found || sdk == "" {
		fmt.eprintln("VULKAN_SDK is not set: please install the Vulkan SDK or run its setup script")
		os.exit(1)
	}

	when ODIN_OS == .Windows {
		lib_dir, _ := filepath.join({sdk, "Lib"}, context.temp_allocator)
		append(args, fmt.tprintf("-extra-linker-flags:/LIBPATH:\"%s\"", lib_dir))
	} else {
		lib_dir, _ := filepath.join({sdk, "lib"}, context.temp_allocator)
		append(args, fmt.tprintf("-extra-linker-flags:-L%s -Wl,-rpath,%s", lib_dir, lib_dir))
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
	state, _, stderr, err := os.process_exec(
		{command = command, working_dir = working_dir},
		context.temp_allocator,
	)
	if err != nil {
		fmt.eprintfln("Failed to launch '%s': %v", command[0], err)
		os.exit(1)
	}
	if state.exit_code != 0 {
		fmt.eprintfln("'%s' failed: %s", command[0], string(stderr))
		os.exit(state.exit_code)
	}
}
