#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

IMAGE="${FFMPEG_LOONG64_IMAGE:-electron-builder:crimson-llvm-23-rustc-195}"
HOST_WORKSPACE="${FFMPEG_LOONG64_WORKSPACE:-/mnt/data/build/electron-loong64}"
KEEP_BUILD_DIR=false
RUN_DOCKER=false

usage() {
  cat <<'EOF'
Usage: scripts/ffmpeg.sh [--docker] [--workspace PATH] [--image IMAGE] [--keep-build-dir]

Regenerate Chromium FFmpeg linux/loong64 config files for both Chromium and
Chrome brandings, then merge the loong64 source list into ffmpeg_generated.gni.

This script assumes the Chromium source tree already contains the loong64 FFmpeg
script support from the chromium-loongarch64 patch set.  It does not patch
Chromium sources by itself, and it does not commit or push anything.

Default mode runs inside an already prepared loong64 builder environment using
scripts/env.sh ($SRC_PATH).  --docker runs the same script inside the builder
image from the host workspace, useful on kukuru.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker)
      RUN_DOCKER=true
      shift
      ;;
    --workspace)
      HOST_WORKSPACE="$2"
      shift 2
      ;;
    --image)
      IMAGE="$2"
      shift 2
      ;;
    --keep-build-dir)
      KEEP_BUILD_DIR=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$RUN_DOCKER" == true ]]; then
  tmp_os_release="$(mktemp)"
  trap 'rm -f "$tmp_os_release"' EXIT
  printf 'ID=debian\nNAME="Debian GNU/Linux"\n' > "$tmp_os_release"

  docker_bin="docker"
  if ! docker info >/dev/null 2>&1; then
    docker_bin="sudo docker"
  fi

  exec $docker_bin run --rm \
    -v "$HOST_WORKSPACE":/home/builduser \
    -v "$tmp_os_release":/etc/os-release:ro \
    -w /home/builduser/electron-loong64 \
    "$IMAGE" \
    bash -lc "scripts/ffmpeg.sh ${KEEP_BUILD_DIR:+--keep-build-dir}"
fi

SRC="${SRC_PATH:?SRC_PATH is not set}"
FF="$SRC/third_party/ffmpeg"
LLVM_BIN="$SRC/third_party/llvm-build/Release+Asserts/bin"

require_path() {
  if [[ ! -e "$1" ]]; then
    echo "Required path does not exist: $1" >&2
    exit 1
  fi
}

require_path "$SRC/AUTHORS"
require_path "$FF/configure"
require_path "$SRC/media/ffmpeg/scripts/build_ffmpeg.py"
require_path "$SRC/media/ffmpeg/scripts/generate_gn.py"
require_path "$SRC/media/ffmpeg/scripts/robo_lib/config.py"
require_path "$FF/chromium/scripts/copy_config.sh"
require_path "$LLVM_BIN"

export PATH="/usr/bin:/usr/local/bin:$LLVM_BIN:$PATH"

require_loong64_script_support() {
  python3 - <<'PY'
from pathlib import Path

checks = {
    'media/ffmpeg/scripts/build_ffmpeg.py': [
        "'loong64'",
        "--arch=loongarch64",
        "--enable-lsx",
        "--disable-lasx",
    ],
    'media/ffmpeg/scripts/generate_gn.py': [
        "'loong64'",
    ],
    'media/ffmpeg/scripts/robo_lib/config.py': [
        'platform.machine() == "loongarch64"',
        'self._host_architecture = "loong64"',
    ],
    'third_party/ffmpeg/chromium/scripts/copy_config.sh': [
        'loong64',
    ],
}

missing = []
for path, needles in checks.items():
    text = Path(path).read_text()
    for needle in needles:
        if needle not in text:
            missing.append(f'{path}: missing {needle}')

if missing:
    raise SystemExit(
        'Chromium tree does not contain the required loong64 FFmpeg script support.\n'
        'Apply the chromium-loongarch64 patch set first.\n' + '\n'.join(missing)
    )
PY

  python3 -m py_compile \
    media/ffmpeg/scripts/build_ffmpeg.py \
    media/ffmpeg/scripts/generate_gn.py \
    media/ffmpeg/scripts/robo_lib/config.py
}

copy_reference_ffversion() {
  python3 - <<'PY'
from pathlib import Path
import re

candidates = [
    Path('third_party/ffmpeg/chromium/config/Chrome/linux/x64/libavutil/ffversion.h'),
    Path('third_party/ffmpeg/chromium/config/Chromium/linux/x64/libavutil/ffversion.h'),
]
version = None
for p in candidates:
    if p.exists():
        m = re.search(r'FFMPEG_VERSION "([^"]+)"', p.read_text())
        if m:
            version = m.group(1)
            break
if not version:
    raise SystemExit('Could not determine reference FFMPEG_VERSION')

for brand in ('Chrome', 'Chromium'):
    p = Path(f'third_party/ffmpeg/chromium/config/{brand}/linux/loong64/libavutil/ffversion.h')
    if not p.exists():
        continue
    s = re.sub(r'FFMPEG_VERSION "[^"]+"', f'FFMPEG_VERSION "{version}"', p.read_text())
    p.write_text(s)
print(f'Using FFMPEG_VERSION {version} for linux/loong64')
PY
}

snapshot_ffmpeg_generation_noise_inputs() {
  local credits_backup="$1"
  local autorename_backup_dir="$2"

  cp third_party/ffmpeg/CREDITS.chromium "$credits_backup"
  python3 - "$autorename_backup_dir" <<'PY'
from pathlib import Path
import shutil
import sys

backup_root = Path(sys.argv[1])
ffmpeg_root = Path('third_party/ffmpeg')

for path in ffmpeg_root.rglob('autorename_*'):
    if not path.is_file():
        continue
    rel = path.relative_to(ffmpeg_root)
    if 'loongarch' in rel.parts:
        continue
    if any(part.startswith('build.') for part in rel.parts):
        continue
    dest = backup_root / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, dest)
PY
}

restore_ffmpeg_generation_noise_inputs() {
  local credits_backup="$1"
  local autorename_backup_dir="$2"

  cp "$credits_backup" third_party/ffmpeg/CREDITS.chromium
  python3 - "$autorename_backup_dir" <<'PY'
from pathlib import Path
import shutil
import sys

backup_root = Path(sys.argv[1])
ffmpeg_root = Path('third_party/ffmpeg')

for path in ffmpeg_root.rglob('autorename_*'):
    if not path.is_file():
        continue
    rel = path.relative_to(ffmpeg_root)
    if 'loongarch' in rel.parts:
        continue
    if any(part.startswith('build.') for part in rel.parts):
        continue
    path.unlink()

for src in backup_root.rglob('*'):
    if not src.is_file():
        continue
    dest = ffmpeg_root / src.relative_to(backup_root)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
PY
}

merge_loong64_generated_gni() {
  python3 - <<'PY'
from pathlib import Path

full_path = Path('third_party/ffmpeg/ffmpeg_generated.gni')
loong_path = Path('/tmp/ffmpeg_generated_loong64_only.gni')
full = full_path.read_text()
loong = loong_path.read_text()

def find_matching_brace(text, open_index):
    depth = 0
    for i in range(open_index, len(text)):
        c = text[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                j = i + 1
                while j < len(text) and text[j] in ' \t\r\n':
                    j += 1
                return j
    raise ValueError('unmatched brace')

def extract_filtered_loong_blocks(text):
    blocks = []
    pos = 0
    variables = ('ffmpeg_c_sources', 'ffmpeg_gas_sources', 'ffmpeg_asm_sources')
    while True:
        idx = text.find('if (', pos)
        if idx == -1:
            break
        brace = text.find('{', idx)
        if brace == -1:
            break
        header = text[idx:brace].rstrip()
        end = find_matching_brace(text, brace)
        block = text[idx:end]
        if 'current_cpu == "loong64"' in header:
            for var in variables:
                items = [item for item in extract_list_items(block, var) if '/loongarch/' in item]
                if items:
                    body = ''.join(f'    {item}\n' for item in items)
                    blocks.append(f'{header} {{\n  {var} += [\n{body}  ]\n}}\n\n')
        pos = end
    return blocks

def remove_if_blocks_with(text, needle):
    out = []
    pos = 0
    while True:
        idx = text.find('if (', pos)
        if idx == -1:
            out.append(text[pos:])
            break
        brace = text.find('{', idx)
        if brace == -1:
            out.append(text[pos:])
            break
        header = text[idx:brace]
        end = find_matching_brace(text, brace)
        if needle in header:
            out.append(text[pos:idx])
            pos = end
        else:
            out.append(text[pos:end])
            pos = end
    return ''.join(out)

def extract_list_items(text, list_name):
    marker = f'{list_name} += ['
    idx = text.find(marker)
    if idx == -1:
        return []
    end = text.find(']', idx)
    if end == -1:
        return []
    items = []
    for line in text[idx:end].splitlines():
        line = line.strip()
        if line.startswith('"') and line.endswith('",'):
            items.append(line)
    return items

loong_deps = [item for item in extract_list_items(loong, 'ffmpeg_c_deps') if 'loongarch' in item]
if loong_deps:
    dep_marker = 'ffmpeg_c_deps += [\n'
    dep_start = full.find(dep_marker)
    dep_end = full.find(']\n', dep_start)
    if dep_start == -1 or dep_end == -1:
        raise SystemExit('Could not find ffmpeg_c_deps block')
    dep_block = full[dep_start:dep_end]
    additions = ''.join(f'  {item}\n' for item in loong_deps if item not in dep_block)
    if additions:
        full = full[:dep_end] + additions + full[dep_end:]

loong_blocks = extract_filtered_loong_blocks(loong)
if not loong_blocks:
    raise SystemExit('No loongarch source entries found in generated loong64 gni')
full = remove_if_blocks_with(full, 'current_cpu == "loong64"')
insert_marker = 'if (use_linux_config && current_cpu == "riscv64"'
insert_at = full.find(insert_marker)
if insert_at == -1:
    insert_marker = 'if ((current_cpu == "arm64"'
    insert_at = full.find(insert_marker)
if insert_at == -1:
    raise SystemExit('Could not find insertion point for loong64 gni blocks')
full = full[:insert_at] + ''.join(loong_blocks) + full[insert_at:]
full_path.write_text(full)
PY
}

cd "$SRC"
require_loong64_script_support
rm -rf "$FF/build.loong64.linux"

python3 media/ffmpeg/scripts/build_ffmpeg.py linux loong64
(
  cd "$FF"
  bash chromium/scripts/copy_config.sh
)
copy_reference_ffversion

full_gni_backup="$(mktemp)"
credits_backup="$(mktemp)"
autorename_backup_dir="$(mktemp -d)"
cp third_party/ffmpeg/ffmpeg_generated.gni "$full_gni_backup"
snapshot_ffmpeg_generation_noise_inputs "$credits_backup" "$autorename_backup_dir"
trap 'rm -f "$full_gni_backup" "$credits_backup" /tmp/ffmpeg_generated_loong64_only.gni; rm -rf "$autorename_backup_dir"' EXIT
(
  cd "$FF"
  python3 "$SRC/media/ffmpeg/scripts/generate_gn.py" \
    -s . \
    -b . >/tmp/ffmpeg_generate_gn_loong64.log
  cp ffmpeg_generated.gni /tmp/ffmpeg_generated_loong64_only.gni
  cp "$full_gni_backup" ffmpeg_generated.gni
)
restore_ffmpeg_generation_noise_inputs "$credits_backup" "$autorename_backup_dir"
merge_loong64_generated_gni

if [[ "$KEEP_BUILD_DIR" != true ]]; then
  rm -rf "$FF/build.loong64.linux"
fi

git -C "$SRC" status --short -- \
  media/ffmpeg/scripts \
  third_party/ffmpeg | sed -n '1,200p'
