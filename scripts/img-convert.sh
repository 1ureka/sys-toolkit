#!/bin/bash
set -euo pipefail

# img-convert — 圖像格式轉換

usage() {
  echo "用法: sys-toolkit img-convert <target-format> [OPTIONS]"
  echo ""
  echo "參數:"
  echo "  <target-format>  目標格式: png, jpg, webp, avif, bmp, tiff, gif"
  echo ""
  echo "選項:"
  echo "  --keep           轉換後保留原檔 (預設刪除原檔)"
  echo "  --quality <n>    輸出品質 1-100 (預設: 90)"
  echo "  --resize <spec>  縮放尺寸（例: 50%, 1920x, x1080, 800x600）"
  echo "  -h, --help       顯示此說明"
}

interactive() {
  local fmt
  fmt=$(gum choose --header "目標格式" png jpg webp avif bmp tiff gif)

  local args=("$fmt")

  if gum confirm "保留原檔？" --default=No; then
    args+=(--keep)
  fi

  local quality
  quality=$(gum input --placeholder "輸出品質 1-100（留空=90）")
  [[ -n "$quality" ]] && args+=(--quality "$quality")

  local resize
  resize=$(gum input --placeholder "縮放尺寸（例: 50%, 1920x, x1080）留空=不縮放")
  [[ -n "$resize" ]] && args+=(--resize "$resize")

  exec "$0" "${args[@]}"
}

[[ "${1:-}" == "--interactive" ]] && interactive

TARGET_FMT=""
KEEP=false
QUALITY=90
RESIZE=""

# Parse first positional arg
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") echo "錯誤: 請指定目標格式"; usage; exit 1 ;;
  *) TARGET_FMT=$(echo "$1" | tr '[:upper:]' '[:lower:]'); shift ;;
esac

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep)    KEEP=true; shift ;;
    --quality) QUALITY="$2"; shift 2 ;;
    --resize)  RESIZE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知參數: $1"; usage; exit 1 ;;
  esac
done

# Validate target format
VALID_FMTS="png jpg jpeg webp avif bmp tiff gif"
valid=false
for fmt in $VALID_FMTS; do
  if [[ "$TARGET_FMT" == "$fmt" ]]; then
    valid=true
    break
  fi
done
if [[ "$valid" == false ]]; then
  echo "錯誤: 不支援的格式 '$TARGET_FMT'"
  echo "支援格式: $VALID_FMTS"
  exit 1
fi

# Source image extensions to scan
SRC_EXTS="png jpg jpeg webp avif bmp tiff tif gif"

is_image_ext() {
  local ext_lower="$1"
  for src_ext in $SRC_EXTS; do
    [[ "$ext_lower" == "$src_ext" ]] && return 0
  done
  return 1
}

is_target_format() {
  local ext_lower="$1"
  case "$TARGET_FMT" in
    jpg|jpeg) [[ "$ext_lower" == "jpg" || "$ext_lower" == "jpeg" ]] ;;
    *)        [[ "$ext_lower" == "$TARGET_FMT" ]] ;;
  esac
}

build_convert_args() {
  local src="$1" dest="$2"
  CONVERT_CMD=("$src" -quality "$QUALITY")
  [[ -n "$RESIZE" ]] && CONVERT_CMD+=(-resize "$RESIZE")
  CONVERT_CMD+=("$dest")
}

converted=0
failed=0

for f in /data/*; do
  [[ -f "$f" ]] || continue

  ext_lower=$(echo "${f##*.}" | tr '[:upper:]' '[:lower:]')
  is_image_ext "$ext_lower" || continue
  is_target_format "$ext_lower" && continue

  output="${f%.*}.${TARGET_FMT}"
  name=$(basename "$f")

  echo "轉換: $name -> $(basename "$output")"
  build_convert_args "$f" "$output"
  if convert "${CONVERT_CMD[@]}" 2>/dev/null; then
    converted=$((converted + 1))
    if [[ "$KEEP" == false ]]; then
      rm "$f" 2>/dev/null || echo "  警告: 轉換成功但無法刪除原檔 $name（檔案可能被其他程式佔用）"
    fi
  else
    echo "  失敗: $name"
    failed=$((failed + 1))
  fi
done

echo ""
if [[ $converted -eq 0 && $failed -eq 0 ]]; then
  echo "未找到需要轉換的圖像檔案。"
else
  echo "--- 轉換完成: 成功 $converted 個, 失敗 $failed 個 ---"
  [[ "$KEEP" == false ]] && echo "(原檔已刪除)"
  [[ "$KEEP" == true ]] && echo "(原檔已保留)"
fi
