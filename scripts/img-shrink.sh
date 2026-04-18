#!/bin/bash
set -euo pipefail

# img-shrink — 圖片依檔案大小縮小

usage() {
  echo "用法: sys-toolkit img-shrink [OPTIONS]"
  echo ""
  echo "對當前目錄下的圖片（直接子檔案），若檔案大小超過閥值，"
  echo "反覆縮放 50% 直到低於閥值。"
  echo ""
  echo "選項:"
  echo "  --max-size <size>  檔案大小閥值，例: 500K, 2M (預設: 1M)"
  echo "  --keep             保留原檔（預設覆蓋原檔）"
  echo "  -h, --help         顯示此說明"
}

interactive() {
  local args=()

  local max_size
  max_size=$(gum input --placeholder "檔案大小閥值（例: 500K, 2M）留空=1M")
  [[ -n "$max_size" ]] && args+=(--max-size "$max_size")

  if gum confirm "保留原檔？" --default=No; then
    args+=(--keep)
  fi

  exec "$0" "${args[@]}"
}

[[ "${1:-}" == "--interactive" ]] && interactive

MAX_SIZE="1M"
KEEP=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-size) MAX_SIZE="$2"; shift 2 ;;
    --keep)     KEEP=true; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "未知參數: $1"; usage; exit 1 ;;
  esac
done

# Convert size string (e.g. 500K, 2M) to bytes
parse_size() {
  local input="$1"
  local num unit
  num="${input%%[A-Za-z]*}"
  unit="${input##*[0-9]}"
  unit=$(echo "$unit" | tr '[:lower:]' '[:upper:]')

  if [[ -z "$num" || ! "$num" =~ ^[0-9]+$ ]]; then
    echo "錯誤: 無法解析大小 '$input'（格式: 數字+單位，例: 500K, 2M）" >&2
    exit 1
  fi

  case "$unit" in
    K|KB) echo $((num * 1024)) ;;
    M|MB) echo $((num * 1024 * 1024)) ;;
    G|GB) echo $((num * 1024 * 1024 * 1024)) ;;
    B|"") echo "$num" ;;
    *)    echo "錯誤: 不支援的單位 '$unit'（支援: K, M, G）" >&2; exit 1 ;;
  esac
}

MAX_BYTES=$(parse_size "$MAX_SIZE")
echo "檔案大小閥值: $MAX_SIZE ($MAX_BYTES bytes)"

SRC_EXTS="png jpg jpeg webp avif bmp tiff tif gif"

is_image_ext() {
  local ext_lower="$1"
  for src_ext in $SRC_EXTS; do
    [[ "$ext_lower" == "$src_ext" ]] && return 0
  done
  return 1
}

shrunk=0
skipped=0
failed=0

for f in /data/*; do
  [[ -f "$f" ]] || continue

  ext_lower=$(echo "${f##*.}" | tr '[:upper:]' '[:lower:]')
  is_image_ext "$ext_lower" || continue

  size=$(stat -c%s "$f")
  if [[ $size -le $MAX_BYTES ]]; then
    skipped=$((skipped + 1))
    continue
  fi

  name=$(basename "$f")
  echo "處理: $name ($size bytes)"

  tmp="${f}.shrink.tmp"
  cp "$f" "$tmp"

  round=0
  current_size=$size
  while [[ $current_size -gt $MAX_BYTES ]]; do
    round=$((round + 1))
    if ! convert "$tmp" -resize 50% "$tmp" 2>/dev/null; then
      echo "  失敗: 無法縮放 $name"
      rm -f "$tmp"
      failed=$((failed + 1))
      continue 2
    fi
    current_size=$(stat -c%s "$tmp")
    echo "  第 $round 次縮放 -> $current_size bytes"
  done

  if [[ "$KEEP" == true ]]; then
    base="${f%.*}"
    dest="${base}_shrink.${ext_lower}"
    mv "$tmp" "$dest"
    echo "  完成: $(basename "$dest") ($current_size bytes)"
  else
    mv "$tmp" "$f"
    echo "  完成: $name ($current_size bytes)"
  fi
  shrunk=$((shrunk + 1))
done

echo ""
if [[ $shrunk -eq 0 && $failed -eq 0 ]]; then
  echo "未找到超過閥值的圖片。"
  [[ $skipped -gt 0 ]] && echo "($skipped 個圖片已低於閥值)"
else
  echo "--- 完成: 縮小 $shrunk 個, 跳過 $skipped 個, 失敗 $failed 個 ---"
  [[ "$KEEP" == true ]] && echo "(原檔已保留)"
  [[ "$KEEP" == false ]] && echo "(原檔已覆蓋)"
fi
