#!/bin/bash
set -euo pipefail

# empty-dirs — 檢查空資料夾

usage() {
  echo "用法: sys-toolkit empty-dirs [OPTIONS]"
  echo ""
  echo "選項:"
  echo "  --delete           找到空資料夾後直接刪除"
  echo "  --exclude <p1,p2>  跳過名稱以此前墜開頭的資料夾（逗號分隔或多次指定）"
  echo "  -h, --help         顯示此說明"
}

interactive() {
  local args=()

  local exclude
  exclude=$(gum input --placeholder "排除資料夾前墜（例: .git,node_modules）逗號分隔，留空=不排除")
  [[ -n "$exclude" ]] && args+=(--exclude "$exclude")

  if gum confirm "找到後直接刪除？" --default=No; then
    args+=(--delete)
  fi

  exec "$0" "${args[@]}"
}

[[ "${1:-}" == "--interactive" ]] && interactive

DELETE=false
EXCLUDES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --delete)  DELETE=true; shift ;;
    --exclude)
      IFS=',' read -ra _EX <<< "$2"
      for _e in "${_EX[@]}"; do
        _e=$(echo "$_e" | xargs)
        [[ -n "$_e" ]] && EXCLUDES+=("$_e")
      done
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知參數: $1"; usage; exit 1 ;;
  esac
done

echo "掃描空資料夾..."

if [[ ${#EXCLUDES[@]} -gt 0 ]]; then
  FIND_CMD=(find /data -mindepth 1 '(')
  first=true
  for prefix in "${EXCLUDES[@]}"; do
    [[ "$first" == true ]] && first=false || FIND_CMD+=(-o)
    FIND_CMD+=(-name "${prefix}*")
  done
  FIND_CMD+=(')' -prune -o -type d -empty -print)
  DIRS=$( "${FIND_CMD[@]}" 2>/dev/null || true)
else
  DIRS=$(find /data -mindepth 1 -type d -empty 2>/dev/null || true)
fi

if [[ -z "$DIRS" ]]; then
  echo "未找到空資料夾。"
  exit 0
fi

COUNT=$(echo "$DIRS" | wc -l)

if [[ "$DELETE" == true ]]; then
  echo "$DIRS" | while IFS= read -r dir; do
    rel=".${dir#/data}"
    rmdir "$dir"
    echo "已刪除: $rel"
  done
  echo ""
  echo "--- 共刪除 $COUNT 個空資料夾 ---"
else
  echo "$DIRS" | while IFS= read -r dir; do
    rel=".${dir#/data}"
    echo "  $rel"
  done
  echo ""
  echo "--- 共找到 $COUNT 個空資料夾 ---"
  echo "(使用 --delete 來刪除)"
fi
