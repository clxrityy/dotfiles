#!/usr/bin/env bash
# batch-files.sh
#
# Extract every file from a .zip archive and convert supported files to one
# target extension. This version:
#   - walks nested directories inside the zip
#   - preserves directory structure in the output directory
#   - keeps extracted originals in a temp directory (not mixed with output)
#   - avoids filename collisions when multiple source extensions share a name
#   - supports mixed source extensions for common image/audio/video/text targets
#
# Usage:
#   ./batch-files.sh <zip_file> <output_dir> <target_extension>
#
# Examples:
#   ./batch-files.sh archive.zip output png
#   ./batch-files.sh media.zip converted mp3
#   ./batch-files.sh scans.zip text txt

set -euo pipefail

IMAGE_TARGETS=(jpg jpeg png gif webp bmp tif tiff heic pdf)
AUDIO_TARGETS=(mp3 wav flac m4a ogg aac opus)
VIDEO_TARGETS=(mp4 mov mkv avi webm m4v)

TEXT_SOURCE_EXTS=(txt md csv tsv log json xml yaml yml ini conf)
IMAGE_SOURCE_EXTS=(jpg jpeg png gif webp bmp tif tiff heic)
AUDIO_SOURCE_EXTS=(mp3 wav flac m4a ogg aac opus)
VIDEO_SOURCE_EXTS=(mp4 mov mkv avi webm m4v)

ZIP_FILE=""
OUTPUT_DIR=""
TARGET_EXT=""
TARGET_KIND=""
EXTRACT_DIR=""
MAGICK_BIN=""
LAST_ACTION=""

CONVERTED=0
COPIED=0
SKIPPED=0
FAILED=0

log_info()    { printf '[INFO] %s\n' "$*"; }
log_success() { printf '[OK] %s\n' "$*"; }
log_warning() { printf '[WARN] %s\n' "$*"; }
log_error()   { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
Usage: batch-files.sh <zip_file> <output_dir> <target_extension>

Examples:
  batch-files.sh archive.zip output png
  batch-files.sh media.zip converted mp3
  batch-files.sh scans.zip text txt

Notes:
  - Converts supported files from anywhere inside the zip, including nested folders.
  - Output files are written to <output_dir>.
  - Original extracted files go into a temporary directory and are removed automatically.
  - When two input files would produce the same output filename, the script appends
    a suffix like "__from-jpg" to avoid overwriting.
EOF
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

in_list() {
  local needle="$1"
  shift
  local item

  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Required command not found: $cmd"
    return 1
  fi
}

ensure_magick() {
  if [[ -n "$MAGICK_BIN" ]]; then
    return 0
  fi

  if command -v magick >/dev/null 2>&1; then
    MAGICK_BIN="$(command -v magick)"
    return 0
  fi

  if command -v convert >/dev/null 2>&1; then
    MAGICK_BIN="$(command -v convert)"
    return 0
  fi

  log_error "ImageMagick is required for this target. Install 'magick' or 'convert'."
  return 1
}

target_kind() {
  local ext="$1"

  if in_list "$ext" "${IMAGE_TARGETS[@]}"; then
    printf 'image'
    return 0
  fi

  if in_list "$ext" "${AUDIO_TARGETS[@]}"; then
    printf 'audio'
    return 0
  fi

  if in_list "$ext" "${VIDEO_TARGETS[@]}"; then
    printf 'video'
    return 0
  fi

  if [[ "$ext" == "txt" ]]; then
    printf 'text'
    return 0
  fi

  return 1
}

file_extension() {
  local path="$1"
  local base

  base="$(basename "$path")"

  if [[ "$base" != *.* ]]; then
    printf ''
    return 0
  fi

  printf '%s' "$(to_lower "${base##*.}")"
}

file_stem() {
  local path="$1"
  local base
  local stem

  base="$(basename "$path")"
  stem="${base%.*}"

  if [[ -z "$stem" ]]; then
    stem="$base"
  fi

  printf '%s' "$stem"
}

build_output_path() {
  local dest_dir="$1"
  local stem="$2"
  local target_ext="$3"
  local source_ext="$4"

  local candidate="$dest_dir/$stem.$target_ext"
  local suffix
  local counter=2

  if [[ ! -e "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  suffix="__from-${source_ext:-file}"
  candidate="$dest_dir/$stem${suffix}.$target_ext"

  while [[ -e "$candidate" ]]; do
    candidate="$dest_dir/$stem${suffix}-${counter}.$target_ext"
    counter=$((counter + 1))
  done

  printf '%s\n' "$candidate"
}

cleanup() {
  if [[ -n "${EXTRACT_DIR:-}" && -d "$EXTRACT_DIR" ]]; then
    rm -rf "$EXTRACT_DIR"
  fi
}

copy_file() {
  local src="$1"
  local dest="$2"

  cp "$src" "$dest"
  LAST_ACTION="copied"
}

convert_to_image_or_pdf() {
  local src="$1"
  local dest="$2"
  local src_ext="$3"
  local tmp_dir=""
  local tmp_png=""

  if [[ "$src_ext" == "$TARGET_EXT" ]]; then
    copy_file "$src" "$dest"
    return 0
  fi

  # Video -> image
  # - gif keeps animation
  # - other image/pdf targets get one representative thumbnail frame
  if in_list "$src_ext" "${VIDEO_SOURCE_EXTS[@]}"; then
    require_cmd ffmpeg || return 1

    if [[ "$TARGET_EXT" == "gif" ]]; then
      ffmpeg -y -hide_banner -loglevel error -i "$src" "$dest" || return 1
      LAST_ACTION="converted"
      return 0
    fi

    if [[ "$TARGET_EXT" == "pdf" || "$TARGET_EXT" == "heic" ]]; then
      ensure_magick || return 1

      tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/batch-frame.XXXXXX")"
      tmp_png="$tmp_dir/frame.png"

      ffmpeg -y -hide_banner -loglevel error -i "$src" -vf "thumbnail" -frames:v 1 "$tmp_png" || {
        rm -rf "$tmp_dir"
        return 1
      }

      "$MAGICK_BIN" "$tmp_png" "$dest" || {
        rm -rf "$tmp_dir"
        return 1
      }

      rm -rf "$tmp_dir"
      LAST_ACTION="converted"
      return 0
    fi

    ffmpeg -y -hide_banner -loglevel error -i "$src" -vf "thumbnail" -frames:v 1 "$dest" || return 1
    LAST_ACTION="converted"
    return 0
  fi

  ensure_magick || return 1

  if in_list "$src_ext" "${IMAGE_SOURCE_EXTS[@]}"; then
    "$MAGICK_BIN" "$src" "$dest"
    LAST_ACTION="converted"
    return 0
  fi

  if [[ "$src_ext" == "pdf" && "$TARGET_EXT" != "pdf" ]]; then
    # Convert only the first page when targeting an image format.
    "$MAGICK_BIN" "${src}[0]" "$dest"
    LAST_ACTION="converted"
    return 0
  fi

  if in_list "$src_ext" "${TEXT_SOURCE_EXTS[@]}"; then
    "$MAGICK_BIN" -background white -fill black -size 1600x caption:@"$src" "$dest"
    LAST_ACTION="converted"
    return 0
  fi

  return 2
}

convert_to_audio() {
  local src="$1"
  local dest="$2"
  local src_ext="$3"

  require_cmd ffmpeg || return 1

  if [[ "$src_ext" == "$TARGET_EXT" ]]; then
    copy_file "$src" "$dest"
    return 0
  fi

  if in_list "$src_ext" "${AUDIO_SOURCE_EXTS[@]}" || in_list "$src_ext" "${VIDEO_SOURCE_EXTS[@]}"; then
    ffmpeg -y -hide_banner -loglevel error -i "$src" -vn "$dest"
    LAST_ACTION="converted"
    return 0
  fi

  return 2
}

convert_to_video() {
  local src="$1"
  local dest="$2"
  local src_ext="$3"

  require_cmd ffmpeg || return 1

  if [[ "$src_ext" == "$TARGET_EXT" ]]; then
    copy_file "$src" "$dest"
    return 0
  fi

  if in_list "$src_ext" "${VIDEO_SOURCE_EXTS[@]}"; then
    ffmpeg -y -hide_banner -loglevel error -i "$src" "$dest"
    LAST_ACTION="converted"
    return 0
  fi

  return 2
}

convert_to_text() {
  local src="$1"
  local dest="$2"
  local src_ext="$3"

  if [[ "$src_ext" == "txt" ]]; then
    copy_file "$src" "$dest"
    return 0
  fi

  if in_list "$src_ext" "${TEXT_SOURCE_EXTS[@]}"; then
    cp "$src" "$dest"
    LAST_ACTION="converted"
    return 0
  fi

  if in_list "$src_ext" "${IMAGE_SOURCE_EXTS[@]}"; then
    require_cmd tesseract || return 1
    tesseract "$src" "${dest%.*}" >/dev/null 2>&1
    LAST_ACTION="converted"
    return 0
  fi

  return 2
}

convert_one() {
  local src="$1"
  local dest="$2"
  local src_ext="$3"

  LAST_ACTION=""

  case "$TARGET_KIND" in
    image)
      convert_to_image_or_pdf "$src" "$dest" "$src_ext"
      ;;
    audio)
      convert_to_audio "$src" "$dest" "$src_ext"
      ;;
    video)
      convert_to_video "$src" "$dest" "$src_ext"
      ;;
    text)
      convert_to_text "$src" "$dest" "$src_ext"
      ;;
    *)
      log_error "Internal error: unsupported target kind '$TARGET_KIND'"
      return 1
      ;;
  esac
}

parse_args() {
  if [[ $# -ne 3 ]]; then
    usage
    exit 1
  fi

  ZIP_FILE="$1"
  OUTPUT_DIR="$2"
  TARGET_EXT="$(to_lower "${3#.}")"

  if [[ ! -f "$ZIP_FILE" ]]; then
    log_error "Zip file not found: $ZIP_FILE"
    exit 1
  fi

  TARGET_KIND="$(target_kind "$TARGET_EXT" || true)"
  if [[ -z "$TARGET_KIND" ]]; then
    log_error "Unsupported target extension: .$TARGET_EXT"
    log_error "Supported targets:"
    log_error "  images/pdf: ${IMAGE_TARGETS[*]}"
    log_error "  audio:      ${AUDIO_TARGETS[*]}"
    log_error "  video:      ${VIDEO_TARGETS[*]}"
    log_error "  text:       txt"
    exit 1
  fi
}

extract_zip() {
  require_cmd unzip
  mkdir -p "$OUTPUT_DIR"

  EXTRACT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/batch-files.XXXXXX")"
  trap cleanup EXIT

  log_info "Extracting '$ZIP_FILE'..."
  unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"
}

process_files() {
  local found_any=0
  local src=""
  local rel_path=""
  local rel_dir=""
  local dest_dir=""
  local dest=""
  local stem=""
  local src_ext=""
  local rc=0
  local dest_display=""

  while IFS= read -r -d '' src; do
    found_any=1
    rel_path="${src#$EXTRACT_DIR/}"
    rel_dir="$(dirname "$rel_path")"
    stem="$(file_stem "$src")"
    src_ext="$(file_extension "$src")"

    if [[ "$rel_dir" == "." ]]; then
      dest_dir="$OUTPUT_DIR"
    else
      dest_dir="$OUTPUT_DIR/$rel_dir"
    fi

    mkdir -p "$dest_dir"
    dest="$(build_output_path "$dest_dir" "$stem" "$TARGET_EXT" "${src_ext:-file}")"
    dest_display="${dest#$OUTPUT_DIR/}"

    if convert_one "$src" "$dest" "$src_ext"; then
      if [[ "$LAST_ACTION" == "copied" ]]; then
        COPIED=$((COPIED + 1))
        log_success "Copied: $rel_path -> $dest_display"
      else
        CONVERTED=$((CONVERTED + 1))
        log_success "Converted: $rel_path -> $dest_display"
      fi
    else
      rc=$?
      if [[ "$rc" -eq 2 ]]; then
        SKIPPED=$((SKIPPED + 1))
        log_warning "Skipped unsupported source: $rel_path"
      else
        FAILED=$((FAILED + 1))
        log_error "Failed: $rel_path"
      fi
    fi
  done < <(find "$EXTRACT_DIR" -type f -print0)

  if [[ "$found_any" -eq 0 ]]; then
    log_error "No files were found inside the zip archive."
    exit 1
  fi
}

print_summary() {
  log_info "Summary: converted=$CONVERTED copied=$COPIED skipped=$SKIPPED failed=$FAILED"

  if [[ "$FAILED" -gt 0 ]]; then
    exit 1
  fi

  if [[ $((CONVERTED + COPIED)) -eq 0 ]]; then
    log_error "No files could be converted to '.$TARGET_EXT'."
    exit 1
  fi
}

main() {
  parse_args "$@"
  extract_zip
  process_files
  print_summary
}

main "$@"
