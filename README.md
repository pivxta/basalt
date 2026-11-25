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

Use `build.sh` (Linux and macOS) or `build.bat` (Windows) from anywhere in the repository. They compile and run the build tool in `tools/`, and pass all arguments on to it.

On Windows, run them from an **x64 Native Tools Command Prompt** (or any shell where `vcvars64.bat` has been run), since building VMA needs the MSVC tools.

### Examples

List the available examples:

```sh
./build.sh example
```

Build an example, or build and run it:

```sh
./build.sh example flycam
./build.sh example flycam -run
```

Optimized build, optionally with debug symbols for profiling:

```sh
./build.sh example flycam -release
./build.sh example flycam -release -debug_symbols
```

The Vulkan validation layers default to on in debug builds. Override them with `on` or `off`:

```sh
./build.sh example flycam -validation:off
./build.sh example flycam -release -validation:on -sync_validation:on
```

`-clean` removes all example binaries first:

```sh
./build.sh example flycam -clean
```

### Tests

Run all tests, or only the ones you name:

```sh
./build.sh test
./build.sh test becs.test_spawn_and_get becs.test_resources
```

Remove the test binaries:

```sh
./build.sh test -clean
```

### Dependencies

VMA is built automatically the first time it's needed. To build it on its own, or remove it so it's rebuilt from scratch:

```sh
./build.sh deps
./build.sh deps -clean
```

### Cleaning everything

Remove all example and test binaries, and the built VMA:

```sh
./build.sh clean
```

### Output

| What | Where |
|---|---|
| Debug examples | `build/debug/` |
| Release examples | `build/release/` |
| Tests | `build/tests/` |
| The build tool itself | `build/tools/` |

On Windows, use `build.bat` in place of `./build.sh` with the same arguments.
