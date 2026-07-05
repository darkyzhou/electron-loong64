# Electron for LoongArch (Loong64)

This project aims to build a version of Electron that supports the Loong64 architecture.

**Note:** The Electron binaries require `glibc >= 2.38` (i.e. [New-World LoongArch](https://areweloongyet.com/docs/old-and-new-worlds/)) and [LSX](https://docs.kernel.org/arch/loongarch/introduction.html#vrs) support.

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

## Electron Patches

See [darkyzhou/electron](https://github.com/darkyzhou/electron).

## Acknowledgments

Special thanks to [@jiegec](https://github.com/jiegec) and AOSC team for their invaluable Chromium patches in [AOSC-Dev/chromium-loongarch64](https://github.com/AOSC-Dev/chromium-loongarch64), which make this project possible.

## Development

### Environment Requirements

- Linux host machine with Loong64 architecture
- Docker with [docker-buildx](https://github.com/docker/buildx) installed
- QEMU/binfmt support for running x86_64 Chromium build tools when depot_tools/CIPD fetches Linux x64 host binaries
- System resources: minimum 32GiB RAM and 200GiB free disk space

### Available Builder Images

Current local images:

- `ghcr.io/darkyzhou/electron-buildtools:crimson-node-24`: native Loong64 buildtools image for Electron 42 / Node.js 24, based on Deepin crimson.
- `ghcr.io/darkyzhou/electron-builder:crimson-llvm-23-rustc-195`: native Loong64 builder image for Electron 42 / Chromium 148, based on Deepin crimson with LLVM 23, Rust 1.95 nightly, Node.js 24.15.0, and the Chromium 148 GN revision.

Older published builder images:

- `ghcr.io/darkyzhou/electron-builder:deepin-25-llvm-20-rustc-188`: for `37.x.x`
- `ghcr.io/darkyzhou/electron-builder:deepin-25-llvm-21-rustc-192`: for `39.x.x`

### Building from Source

1. Launch an `electron-buildtools:crimson-node-24` container. All subsequent update/sync steps should be executed inside this container. Running `scripts/sync.sh` requires **binfmt support** for x86_64 host tools fetched by depot_tools/CIPD.
2. Change the variables inside `./scripts/env.sh` according to your environment and needs.
3. Run following scripts in sequence.

```bash
# Clone or update the local electron repository
./scripts/update.sh

# Fetch or update the dependencies of electron
# Note: This could take a really long time, grab your coffee or take a sleep!
./scripts/sync.sh
```

4. Launch a container with the corresponding builder image listed above, for example `electron-builder:crimson-llvm-23-rustc-195` for Electron 42. All subsequent build/package steps should be executed inside this container.

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

1. Launch an `electron-buildtools:crimson-node-24` container. All subsequent patch update/export steps should be executed inside this container

2. Update versions and sync sources:
   - Edit `ELECTRON_VERSION` to point to the new version to build in `env.sh`
   - Run `scripts/update.sh`

3. Update dependencies:
   - Run `scripts/sync.sh` to install dependencies

4. Update Chromium patches:
   1. Prepare the consolidated Chromium patch file (e.g., `chromium-131.0.6778.85.diff`) from [AOSC-Dev/chromium-loongarch64](https://github.com/AOSC-Dev/chromium-loongarch64)
   2. Run `scripts/apply.sh chromium-131.0.6778.85.diff` to apply the patches
   3. Resolve any conflicts if any
   4. Run `scripts/export.sh` to export patches for Chromium and submodule commits

`scripts/export.sh` supports the following modes:

```bash
# Export Chromium main-repo patches only, then run patch lint.
scripts/export.sh --chromium

# Export Chromium patches and patches for submodules listed in the file.
scripts/export.sh changed.submodules

# Export only patches for submodules listed in the file.
scripts/export.sh --submodules changed.submodules

# Export Chromium and selected submodule patches explicitly.
scripts/export.sh --chromium --submodules changed.submodules

# Skip patch lint only when it is known to be blocked by an unrelated checkout issue.
scripts/export.sh --chromium --no-lint
```

The submodules file should contain paths such as `third_party/ffmpeg` or `third_party/devtools-frontend/src`, one per line. Empty lines and `#` comments are ignored. The script uses `electron/patches/config.json` to map submodule paths to Electron patch set names, and it does not assume the generated `.patch` file name.

#### Patch export notes for newer Electron

Recent Electron versions treat files under `electron/patches` as reproducible output from the corresponding Chromium and third-party repository commits. When `npx e patches <repo>` or `script/check-patch-diff.ts` is used, patch content, patch file names, and patch descriptions are regenerated from the source commits.

If patch lint reports that a patch has no description, do not edit the exported `.patch` file by hand. Amend the source commit in the corresponding repository instead, and put the justification and removal plan in the commit body. Then rerun the export. For example:

```bash
cd src/third_party/ffmpeg
git commit --amend \
  -m "loong64: add LoongArch64 support" \
  -m "This patch adds generated FFmpeg linux/loong64 configs and source lists for Chromium and Chrome brandings." \
  -m "It can be removed once Chromium FFmpeg ships upstream LoongArch64 Linux config generation and generated configs."

cd ../..
npx e patches ffmpeg
```

`scripts/export.sh` runs `node script/lint.js --patches --only --` by default after exporting.

`script/check-patch-diff.ts` may export every repository listed in `electron/patches/config.json`, not only the patch directory currently being changed. If an unrelated checkout has a broken base revision or missing objects, the check can generate a large amount of unrelated patch output. In that case, manually reset and clean the patch directory, export only the repository being updated, and run patch lint directly:

```bash
cd src/electron
git reset --hard HEAD
git clean -fd patches

cd ..
npx e patches chromium
npx e patches ffmpeg

cd electron
node script/lint.js --patches --only --
```

Only commit the intended patch directories. If `check-patch-diff.ts` is still blocked by an unrelated third-party checkout issue, document the failure and the manual lint result in the commit or release notes.

### Troubleshooting

Common compilation errors:

- `relocation R_LARCH_B26 out of range: 172745664 is not in [-134217728, 134217727]`
   - Root cause: The library was compiled *without* the `-mcmodel=medium` flag. For more details, see [laelf.adoc](https://github.com/loongson/la-abi-specs/blob/release/laelf.adoc#code_models).
   - Resolution: Recompile the library with the `-mcmodel=medium` flag. See `Dockerfile.libffi` for implementation examples.
