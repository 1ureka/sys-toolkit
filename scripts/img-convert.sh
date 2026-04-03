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
  echo "  -h, --help       顯示此說明"
}

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

TARGET_FMT=""
KEEP=false
QUALITY=90

# Parse first positional arg
case "$1" in
  -h|--help) usage; exit 0 ;;
  *) TARGET_FMT=$(echo "$1" | tr '[:upper:]' '[:lower:]'); shift ;;
esac

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep)    KEEP=true; shift ;;
    --quality) QUALITY="$2"; shift 2 ;;
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

converted=0
failed=0

for f in /data/*; do
  [[ -f "$f" ]] || continue

  # Check if source is an image by extension
  ext="${f##*.}"
  ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

  is_image=false
  for src_ext in $SRC_EXTS; do
    if [[ "$ext_lower" == "$src_ext" ]]; then
      is_image=true
      break
    fi
  done
  [[ "$is_image" == true ]] || continue

  # Skip if already target format
  target_check="$TARGET_FMT"
  [[ "$target_check" == "jpg" ]] && target_check="jpg|jpeg"
  [[ "$target_check" == "jpeg" ]] && target_check="jpg|jpeg"
  if [[ "$ext_lower" =~ ^($target_check)$ ]]; then
    continue
  fi

  basename_no_ext="${f%.*}"
  output="${basename_no_ext}.${TARGET_FMT}"
  name=$(basename "$f")

  echo "轉換: $name -> $(basename "$output")"
  if convert "$f" -quality "$QUALITY" "$output" 2>/dev/null; then
    converted=$((converted + 1))
    if [[ "$KEEP" == false ]]; then
      rm "$f"
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
