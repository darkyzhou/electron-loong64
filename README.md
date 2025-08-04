# Electron for Loong64

This project aims to build a version of Electron that supports the Loong64 architecture.

**Note:** The Electron binaries require `glibc >= 2.38`.

## Usage

1. Check [releases](https://github.com/darkyzhou/electron-loong64/releases) for available versions.
2. Install the `electron` npm package with corresponding version and specify the download mirror like this:

```
ELECTRON_MIRROR="https://github.com/darkyzhou/electron-loong64/releases/download/" electron_use_remote_checksums=1 npm install electron@THE_VERSION
```

You may also refer to [darkyzhou/electron-builder-loong64](https://github.com/darkyzhou/electron-builder-loong64) for insturctions on how to build your Electron project with [electron-builder](https://github.com/electron-userland/electron-builder).

## Branches

- `dev`: The development branch, containing the latest patches and build scripts.
- `X.Y.Z`: The release branches, corresponding to the release versions of Electron.

## Acknowledgments

Special thanks to [@jiegec](https://github.com/jiegec) and AOSC team for their invaluable Chromium patches in [AOSC-Dev/chromium-loongarch64](https://github.com/AOSC-Dev/chromium-loongarch64), which make this project possible.

## How This Project Works

1. This project builds upon the official Electron repository by applying custom patches. See `electron.patch` for details.
2. The build process runs in a dedicated container environment that includes all necessary build tools and dependencies. See `Dockerfile.builder` for details.

## Development

### Environment Requirements

- Linux host machine with Loong64 architecture
- Docker with [docker-buildx](https://github.com/docker/buildx) installed
- [LATX](https://github.com/deuso/latx-build) version 1.4.4 (required for running `ghcr.io/darkyzhou/electron-buildtools` image)
- System resources: minimum 32GiB RAM and 200GiB free disk space

### Building from Source

1. Launch a `ghcr.io/darkyzhou/electron-buildtools` container. All subsequent steps should be executed inside this container.
2. Change the variables inside `./scripts/env.sh` according to your environment and needs.
3. Run following scripts in sequence.

```bash
# Clone or update the local electron repository
./scripts/update.sh

# Apply patches from electron-loong64
./scripts/patch.sh

# Fetch or update the dependencies of electron
# Note: This could take a really long time, grab your coffee or take a sleep!
./scripts/sync.sh
```

4. Launch a `ghcr.io/darkyzhou/electron-builder:deepin-25-llvm-20-rustc-188` container. All subsequent steps should be executed inside this container.
5. Run following scripts in sequence.

```bash
# Replace binaries with native ones
./scripts/binaries.sh
./scripts/rollup.sh

# Build the electron
# Note: This could also take a long time, better get some sleep.
./scripts/build.sh

# Package the electron
./scripts/package.sh
```

### Updating Patches

1. Launch a `ghcr.io/darkyzhou/electron-buildtools` container. All subsequent steps should be executed inside this container.

2. Update versions and sync sources:
   - Edit `ELECTRON_VERSION` to point to the new version to build in `env.sh`.
   - Run `scripts/update.sh`.

3. Update dependencies:
   - Run `scripts/sync.sh`. This will apply all original patches from the Electron repository.

4. Apply Chromium patches:
   - Apply the consolidated Chromium patch file (e.g., `chromium-131.0.6778.85.diff`) to `$BUILD_ROOT/src`.
   - Resolve any conflicts if any.

5. Export Chromium patches using `npx e patches` command:
   > Note: `$BUILD_ROOT/src` is a git repository containing submodules, including `$BUILD_ROOT/src/electron` and *a few folders* in `$BUILD_ROOT/src/third_party`.

   1. Run `scripts/export.sh` to commit changes for both chromium and submodule changes.
   2. Run `npx e patches $NAME` to export patches for submodule commits.
   3. Export changes in `$BUILD_ROOT/src/electron` to `patches/`.

6. Apply Electron patches from `patches/electron.patch`.

7. Run `scripts/sync.sh` again to sync the sources and apply all patches.

### Troubleshooting

Common compilation errors:

- `relocation R_LARCH_B26 out of range: 172745664 is not in [-134217728, 134217727]`
   - Root cause: The library was compiled *without* the `-mcmodel=medium` flag. For more details, see [laelf.adoc](https://github.com/loongson/la-abi-specs/blob/release/laelf.adoc#code_models).
   - Resolution: Recompile the library with the `-mcmodel=medium` flag. See `Dockerfile.libffi` for implementation examples.
