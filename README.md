# Electron for Loong64

This project aims to build a version of Electron that supports the Loong64 architecture.

**Note:** The Electron binary requires `glibc >= 2.39`.

## Branches

- `dev`: The development branch, containing the latest patches and build scripts.
- `vX.Y.Z`: The release branches, corresponding to the release versions of Electron.

## Acknowledgments

Special thanks to [@jiegec](https://github.com/jiegec) for his invaluable Chromium patches in [AOSC-Dev/chromium-loongarch64](https://github.com/AOSC-Dev/chromium-loongarch64), which make this project possible.

## Development

### Environment Requirements

- Linux host machine with Loong64 architecture
- Docker with [docker-buildx](https://github.com/docker/buildx) installed
- [LATX](https://github.com/deuso/latx-build) version 1.4.4 (required for running `ghcr.io/darkyzhou/electron-buildtools` image)
- System resources: minimum 16GB RAM and 100GB free disk space

### Source Code Preparation

> For detailed reference, check the `prepare` job in `.github/workflows/electron.yaml`

1. Launch a `ghcr.io/darkyzhou/electron-buildtools` container. All subsequent steps should be executed inside this container

2. Set up the Electron repository:
   - Clone or update the official Electron repository
   - Switch to your target branch, e.g. `v33.2.0`
   - Place it in `$BUILD_ROOT/src/electron` to match the Electron's requirement
   - Note: Do not apply `electron.patch` at this stage

### Updating Chromium Patches

1. Version alignment:
   - Check [chromium-loongarch64](https://github.com/AOSC-Dev/chromium-loongarch64) and [Electron Releases](https://www.electronjs.org/docs/latest/tutorial/electron-timelines)
   - Identify the latest compatible Chromium version with available patches for your target Electron version

2. Launch a `ghcr.io/darkyzhou/electron-buildtools` container. All subsequent steps should be executed inside this container

3. Update dependencies:
   - Modify the `DEPS` file in `$BUILD_ROOT/src/electron` to reference the selected Chromium version
   - Run `npx e sync` in `$BUILD_ROOT/src`. This will apply all existing patches from the Electron repository

4. Apply existing patches:
   - Apply `electron.patch` from the repository to `$BUILD_ROOT/src/electron` using `git apply` in `$BUILD_ROOT/src/electron`

4. Apply Chromium patches:
   - Apply the consolidated Chromium patch file (e.g., `chromium-131.0.6778.85.diff`) to `$BUILD_ROOT/src`
   - Resolve any conflicts if they occur

6. Manage patches using Electron's `npx e patches` command:
   > Note: `$BUILD_ROOT/src` is a git repository containing submodules, including `$BUILD_ROOT/src/electron` and *a few folders* in `$BUILD_ROOT/src/third_party`

   1. Commit changes in both the main repository and affected submodules
   2. Use `npx e patches <name>` in `$BUILD_ROOT/src` to update patches in `$BUILD_ROOT/src/electron`
   3. The `<name>` parameter should match entries in `$BUILD_ROOT/src/electron/patches/config.json`
   
        > In `config.json`, all the items should be a valid git repository. So if the patches modified a folder in `$BUILD_ROOT/src/third_party` but the folder itself is NOT a git repository, the modification will be collected in the main `chromium` item.

   Following commands help demonstrate the process:
   ```sh
   cd $BUILD_ROOT/src
   git add .
   # Don't commit submodules
   git restore --staged $(git submodule status | cut -d' ' -f2)
   git commit -m "loong64 support

   Co-authored-by: Jiajie Chen <c@jia.je>"
   npx e patches chromium

   # Then, we do the same thing for the submodules
   git submodule foreach git add .
   # ...
   ```

6. Run `npx e sync` again to sync the sources and apply our new patches.

### Building

1. Container setup:
   - Launch a `ghcr.io/darkyzhou/electron-builder` container. Check [available tags](https://github.com/darkyzhou/electron-loong64/pkgs/container/electron-builder) for the latest image
   - Note: You may need to create a custom image for specific Electron versions if the latest image runs into compilation issues

2. Build process:
   - Follow the steps in the `build` job from `.github/workflows/electron.yaml`
   - Ensure all environment variables from the `env` section are set
   - Note: The build process is time-intensive, typically requiring around 10 hours on a 3A6000 processor

### Troubleshooting

Common compilation errors:

- `relocation R_LARCH_B26 out of range: 172745664 is not in [-134217728, 134217727]`
   - Root cause: The library was compiled *without* the `-mcmodel=medium` flag. For more details, see [laelf.adoc](https://github.com/loongson/la-abi-specs/blob/release/laelf.adoc#code_models).
   - Resolution: Recompile the library with the `-mcmodel=medium` flag. See `Dockerfile.libffi` for implementation examples.
