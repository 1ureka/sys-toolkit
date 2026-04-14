#!/bin/bash
set -euo pipefail

# count-lines — 統計檔案行數

usage() {
  echo "用法: sys-toolkit count-lines [OPTIONS]"
  echo ""
  echo "選項:"
  echo "  --exclude <p1,p2>  跳過名稱以此前墜開頭的資料夾（逗號分隔或多次指定）"
  echo "  --ext <ext1,ext2>  僅計算指定副檔名"
  echo "  --min-lines <n>    低於此行數的檔案不顯示 (預設: 1)"
  echo "  --summary          以副檔名分組統計"
  echo "  -h, --help         顯示此說明"
}

interactive() {
  local args=()

  local preset
  preset=$(gum choose --header "選擇預設組合" \
    "React       — js,ts,jsx,tsx,css,html  排除 node_modules,dist,.git" \
    "Svelte      — js,ts,svelte,css,html   排除 node_modules,dist,.git" \
    "Python      — py                      排除 __pycache__,.git,venv" \
    "全部檔案    — 不篩選副檔名            排除 .git" \
    "其他        — 自訂所有選項")

  case "$preset" in
    React*)
      args=(--ext "js,ts,jsx,tsx,css,html" --exclude "node_modules,dist,.git")
      ;;
    Svelte*)
      args=(--ext "js,ts,svelte,css,html" --exclude "node_modules,dist,.git,.svelte-kit,build")
      ;;
    Python*)
      args=(--ext "py" --exclude "__pycache__,.git,venv")
      ;;
    全部*)
      args=(--exclude ".git")
      ;;
    其他*)
      local ext
      ext=$(gum input --placeholder "副檔名篩選（例: py,js,ts）留空=全部")
      [[ -n "$ext" ]] && args+=(--ext "$ext")

      local exclude
      exclude=$(gum input --placeholder "排除資料夾前墜（例: node_modules,.git）逗號分隔，留空=不排除")
      [[ -n "$exclude" ]] && args+=(--exclude "$exclude")
      ;;
  esac

  local min
  min=$(gum input --placeholder "最少行數（留空=1）")
  [[ -n "$min" ]] && args+=(--min-lines "$min")

  if gum confirm "以副檔名分組統計？" --default=No; then
    args+=(--summary)
  fi

  exec "$0" "${args[@]}"
}

[[ "${1:-}" == "--interactive" ]] && interactive

EXCLUDES=()
EXT=""
MIN_LINES=1
SUMMARY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --exclude)
      IFS=',' read -ra _EX <<< "$2"
      for _e in "${_EX[@]}"; do
        _e=$(echo "$_e" | xargs)  # trim whitespace
        [[ -n "$_e" ]] && EXCLUDES+=("$_e")
      done
      shift 2 ;;
    --ext)       EXT="$2"; shift 2 ;;
    --min-lines) MIN_LINES="$2"; shift 2 ;;
    --summary)   SUMMARY=true; shift ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "未知參數: $1"; usage; exit 1 ;;
  esac
done

echo "統計檔案行數..."
[[ ${#EXCLUDES[@]} -gt 0 ]] && echo "排除資料夾: ${EXCLUDES[*]}"
[[ -n "$EXT" ]] && echo "篩選副檔名: $EXT"
echo "最低行數: $MIN_LINES"

# Build find command with exclusion
FIND_CMD=(find /data -mindepth 1)
if [[ ${#EXCLUDES[@]} -gt 0 ]]; then
  FIND_CMD+=('(')
  first=true
  for prefix in "${EXCLUDES[@]}"; do
    [[ "$first" == true ]] && first=false || FIND_CMD+=(-o)
    FIND_CMD+=(-name "${prefix}*")
  done
  FIND_CMD+=(')' -prune -o)
fi
FIND_CMD+=(-type f -print)

# Collect files and count lines
declare -A ext_files ext_lines
TOTAL_FILES=0
TOTAL_LINES=0
RESULTS=""

while IFS= read -r file; do
  # Extension filter
  if [[ -n "$EXT" ]]; then
    file_lower=$(echo "$file" | tr '[:upper:]' '[:lower:]')
    matched=false
    IFS=',' read -ra EXTS <<< "$EXT"
    for e in "${EXTS[@]}"; do
      e=$(echo "$e" | tr -d ' .' | tr '[:upper:]' '[:lower:]')
      if [[ "$file_lower" == *".${e}" ]]; then
        matched=true
        break
      fi
    done
    [[ "$matched" == false ]] && continue
  fi

  # Count lines
  lines=$(wc -l < "$file" 2>/dev/null || echo 0)
  lines=$((lines + 0))  # ensure numeric

  [[ $lines -lt $MIN_LINES ]] && continue

  rel=".${file#/data}"
  file_ext="${file##*.}"
  file_ext=$(echo "$file_ext" | tr '[:upper:]' '[:lower:]')
  [[ "$file" != *.* ]] && file_ext="_no_ext_"

  TOTAL_FILES=$((TOTAL_FILES + 1))
  TOTAL_LINES=$((TOTAL_LINES + lines))

  if [[ "$SUMMARY" == true ]]; then
    ext_files["$file_ext"]=$(( ${ext_files["$file_ext"]:-0} + 1 ))
    ext_lines["$file_ext"]=$(( ${ext_lines["$file_ext"]:-0} + lines ))
  else
    RESULTS="${RESULTS}$(printf '%6d  %s\n' "$lines" "$rel")"$'\n'
  fi
done < <("${FIND_CMD[@]}" 2>/dev/null || true)

if [[ $TOTAL_FILES -eq 0 ]]; then
  echo ""
  echo "未找到符合條件的檔案。"
  exit 0
fi

if [[ "$SUMMARY" == true ]]; then
  echo ""
  echo "--- 依副檔名統計 ---"
  printf '%-12s %8s %12s\n' "Extension" "Files" "TotalLines"
  printf '%-12s %8s %12s\n' "---------" "-----" "----------"

  # Sort by total lines descending
  for ext in "${!ext_lines[@]}"; do
    echo "${ext_lines[$ext]} $ext ${ext_files[$ext]}"
  done | sort -rn | while read -r tl ext fc; do
    if [[ "$ext" == "_no_ext_" ]]; then
      printf '%-12s %8d %12d\n' "(no ext)" "$fc" "$tl"
    else
      printf '%-12s %8d %12d\n' ".$ext" "$fc" "$tl"
    fi
  done
else
  echo ""
  echo "$RESULTS" | sort -rn | head -n -1
fi

echo ""
echo "--- 共計: $TOTAL_FILES 個檔案, $TOTAL_LINES 行 ---"
