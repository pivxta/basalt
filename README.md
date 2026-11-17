# Basalt

Basalt is a small hobby 3D Vulkan renderer written in the Odin programming language.

## Dependencies

All platforms need:

- **[Odin](https://odin-lang.org/docs/install/)**
- **The [Vulkan SDK](https://vulkan.lunarg.com/sdk/home)**, with the `VULKAN_SDK` environment variable set. It provides Slang (the shader compiler, loaded at runtime) and the validation layers.
- **premake5**, used to build VMA. It's in the package manager on most platforms below; otherwise [download it](https://premake.github.io/download) and put it on your `PATH`.
- **The git submodules:**

  ```sh
  git submodule update --init --recursive
  ```

### Linux

Odin needs `clang` to link, and GLFW has to come from the system.

**Fedora**

```sh
sudo dnf install clang make glfw-devel premake
```

**Arch**

```sh
sudo pacman -S clang make glfw premake
```

**Ubuntu / Debian**

```sh
sudo apt install clang make libglfw3-dev
```

The `premake4` package is too old, so [download premake5](https://premake.github.io/download) instead.

For the Vulkan SDK, download the Linux tarball, extract it, and source its setup script in your shell (or your shell profile):

```sh
source /path/to/vulkansdk/<version>/setup-env.sh
```

### Windows

- **Visual Studio 2022** with the "Desktop development with C++" workload, for the MSVC toolchain that Odin and VMA need.
- **The Vulkan SDK installer**, which sets `VULKAN_SDK` and adds the SDK's `Bin` folder to `PATH`.
- **[premake5](https://premake.github.io/download)** on your `PATH`.
- Run the build from an **x64 Native Tools Command Prompt** (or any shell where `vcvars64.bat` has been run).

GLFW comes with Odin's `vendor:glfw`, so there's nothing to install for it.

### macOS

> Untested.

```sh
xcode-select --install
brew install premake
```

Install the macOS Vulkan SDK (which includes MoltenVK) and source its `setup-env.sh` as on Linux. GLFW comes with Odin's `vendor:glfw`.

## Building

All commands are always run from the repository root. Arguments after `--` go to the build tool.

### Examples

List the available examples:

```sh
odin run -file tools/build.odin -- example
```

Build an example (debug build, validation layers on):

```sh
odin run -file tools/build.odin -- example flycam
```

Build and run it:

```sh
odin run -file tools/build.odin -- example flycam -run
```

Optimized build, optionally with debug symbols for profiling:

```sh
odin run -file tools/build.odin -- example flycam -release
odin run -file tools/build.odin -- example flycam -release -debug_symbols
```

Validation layers default to on in debug builds and off in release builds. Override them with `on` or `off`:

```sh
odin run -file tools/build.odin -- example flycam -validation:off
odin run -file tools/build.odin -- example flycam -release -validation:on -sync_validation:on
```

Binaries are written to `build/debug/` or `build/release/`.

### Dependencies

VMA is built automatically the first time you build an example. To build it on its own, or to clean it so it's rebuilt from scratch:

```sh
odin run -file tools/build.odin -- deps
odin run -file tools/build.odin -- deps -clean
```
