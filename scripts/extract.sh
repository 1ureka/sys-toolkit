#!/bin/bash
set -euo pipefail

# extract — 快速解壓縮

usage() {
  echo "用法: sys-toolkit extract <file|all>"
  echo ""
  echo "參數:"
  echo "  <file>  解壓指定檔案"
  echo "  all     解壓當前目錄下所有壓縮檔（每個檔案解壓至同名子目錄）"
  echo ""
  echo "選項:"
  echo "  -h, --help  顯示此說明"
}

interactive() {
  local target
  target=$(gum input --placeholder "檔案名稱（或輸入 all 批次解壓）")

  if [[ -z "$target" ]]; then
    gum style --foreground 196 "必須指定檔案或 all"
    exit 1
  fi

  exec "$0" "$target"
}

[[ "${1:-}" == "--interactive" ]] && interactive

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") echo "錯誤: 請指定檔案或 all"; usage; exit 1 ;;
esac

ARCHIVE_EXTS="zip 7z tar gz bz2 xz rar tgz tbz2 txz zst lz4 cab iso"

is_archive() {
  local name_lower
  name_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  for ext in $ARCHIVE_EXTS; do
    if [[ "$name_lower" == *".${ext}" ]]; then
      return 0
    fi
  done
  # Handle .tar.* double extensions
  if [[ "$name_lower" == *.tar.* ]]; then
    return 0
  fi
  return 1
}

extract_to_subdir() {
  local f="$1"
  local name
  name=$(basename "$f")
  # Strip all archive extensions to get dir name
  local dir_name="$name"
  dir_name="${dir_name%%.[tT][aA][rR].*}"  # strip .tar.* first
  dir_name="${dir_name%.*}"                 # strip remaining ext
  local dest="/data/$dir_name"
  mkdir -p "$dest"
  echo "解壓中: $name -> $dir_name/"
  7zz x "$f" -o"$dest" -y || echo "  警告: $name 解壓失敗"
}

if [[ "$1" == "all" ]]; then
  found=false
  for f in /data/*; do
    [[ -f "$f" ]] || continue
    is_archive "$(basename "$f")" || continue
    found=true
    extract_to_subdir "$f"
  done
  if [[ "$found" == false ]]; then
    echo "目錄中沒有找到壓縮檔。"
    echo "支援格式: $ARCHIVE_EXTS"
  fi
else
  file="/data/$1"
  if [[ ! -f "$file" ]]; then
    echo "錯誤: 找不到檔案 $1"
    exit 1
  fi
  extract_to_subdir "$file"
fi
