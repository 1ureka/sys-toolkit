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

if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$1" == "all" ]]; then
  found=false
  for f in /data/*; do
    if [[ -f "$f" ]]; then
      found=true
      name=$(basename "$f")
      echo "解壓中: $name"
      7z x "$f" -o* -y || echo "  警告: $name 解壓失敗或非壓縮檔"
    fi
  done
  if [[ "$found" == false ]]; then
    echo "目錄中沒有檔案。"
  fi
else
  file="/data/$1"
  if [[ ! -f "$file" ]]; then
    echo "錯誤: 找不到檔案 $1"
    exit 1
  fi
  echo "解壓中: $1"
  7z x "$file" -y
fi
