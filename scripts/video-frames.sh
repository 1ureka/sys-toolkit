#!/bin/bash
set -euo pipefail

# video-frames — 影像擷取

usage() {
  echo "用法: sys-toolkit video-frames <file|all> [OPTIONS]"
  echo ""
  echo "參數:"
  echo "  <file>  指定影片檔案"
  echo "  all     批次處理當前目錄下所有影片"
  echo ""
  echo "選項:"
  echo "  -n <count>       擷取幀數 (預設: 8)"
  echo "  --prefix <name>  輸出檔名前墜 (預設: frame)"
  echo "  --out-dir <dir>  統一輸出目錄（否則每個影片各自子目錄）"
  echo "  --format <ext>   輸出格式 jpg|png (預設: jpg)"
  echo "  -h, --help       顯示此說明"
}

interactive() {
  local target
  target=$(gum input --placeholder "影片檔案名（或輸入 all 批次處理）")

  if [[ -z "$target" ]]; then
    gum style --foreground 196 "必須指定影片或 all"
    exit 1
  fi

  local args=("$target")

  local n
  n=$(gum input --placeholder "擷取幀數（留空=8）")
  [[ -n "$n" ]] && args+=(-n "$n")

  local fmt
  fmt=$(gum choose --header "輸出格式" jpg png)
  [[ "$fmt" != "jpg" ]] && args+=(--format "$fmt")

  local prefix
  prefix=$(gum input --placeholder "檔名前墜（留空=frame）")
  [[ -n "$prefix" ]] && args+=(--prefix "$prefix")

  local outdir
  outdir=$(gum input --placeholder "統一輸出目錄（留空=各自子目錄）")
  [[ -n "$outdir" ]] && args+=(--out-dir "$outdir")

  exec "$0" "${args[@]}"
}

[[ "${1:-}" == "--interactive" ]] && interactive

TARGET=""
N=8
PREFIX="frame"
OUT_DIR=""
FORMAT="jpg"

# Parse first positional arg
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") echo "錯誤: 請指定影片或 all"; usage; exit 1 ;;
  *) TARGET="$1"; shift ;;
esac

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n)        N="$2"; shift 2 ;;
    --prefix)  PREFIX="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --format)  FORMAT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      # Allow second positional arg as N for backwards compatibility
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        N="$1"; shift
      else
        echo "未知參數: $1"; usage; exit 1
      fi
      ;;
  esac
done

# Quality flag
QUALITY_FLAG=()
if [[ "$FORMAT" == "jpg" || "$FORMAT" == "jpeg" ]]; then
  QUALITY_FLAG=(-q:v 2)
fi

COUNTER=1

extract_frames() {
  local f="$1"
  local name="${f%.*}"
  name=$(basename "$name")

  local dest
  if [[ -n "$OUT_DIR" ]]; then
    dest="/data/$OUT_DIR"
  else
    dest="/data/$name"
  fi
  mkdir -p "$dest"

  local dur
  dur=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$f" | tr -d '[:space:]')

  if [[ -z "$dur" || "$dur" == "N/A" ]]; then
    echo "  警告: 無法取得 $f 的時長，跳過"
    return
  fi

  local output_pattern
  if [[ -n "$OUT_DIR" ]]; then
    output_pattern="$dest/${PREFIX}_$(printf '%04d' $COUNTER)_%04d.${FORMAT}"
    # Use a simpler approach: sequential naming in unified dir
    output_pattern="$dest/${PREFIX}_%04d.${FORMAT}"
    # We need to offset the counter for batch mode in unified dir
    local start_num=$COUNTER
    ffmpeg -i "$f" -vf "fps=$N/$dur" -frames:v "$N" \
      "${QUALITY_FLAG[@]}" \
      -start_number "$start_num" \
      "$dest/${PREFIX}_%04d.${FORMAT}" \
      -y -loglevel warning
    COUNTER=$((COUNTER + N))
  else
    ffmpeg -i "$f" -vf "fps=$N/$dur" -frames:v "$N" \
      "${QUALITY_FLAG[@]}" \
      "$dest/${PREFIX}_%03d.${FORMAT}" \
      -y -loglevel warning
  fi

  echo "完成: $(basename "$f") -> $dest/ ($N 幀)"
}

VIDEO_EXTS="mp4 mkv avi mov m4v flv wmv webm ts"

if [[ "$TARGET" == "all" ]]; then
  found=false
  for ext in $VIDEO_EXTS; do
    for f in /data/*."$ext"; do
      if [[ -f "$f" ]]; then
        found=true
        extract_frames "$f"
      fi
    done
  done
  if [[ "$found" == false ]]; then
    echo "目錄中沒有找到影片檔案。"
    echo "支援格式: $VIDEO_EXTS"
  fi
else
  file="/data/$TARGET"
  if [[ ! -f "$file" ]]; then
    echo "錯誤: 找不到檔案 $TARGET"
    exit 1
  fi
  extract_frames "$file"
fi
