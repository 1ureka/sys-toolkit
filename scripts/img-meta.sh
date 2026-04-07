#!/bin/bash
set -euo pipefail

# img-meta — 圖片元資料提取

usage() {
  echo "用法: sys-toolkit img-meta <file|all> [OPTIONS]"
  echo ""
  echo "參數:"
  echo "  <file>  指定圖片檔案"
  echo "  all     處理當前目錄下所有圖片"
  echo ""
  echo "選項:"
  echo "  --output <file>  輸出到 JSON 檔案（預設: 輸出到終端）"
  echo "  --pretty         格式化 JSON 輸出（預設: 壓縮）"
  echo "  -h, --help       顯示此說明"
}

interactive() {
  local target
  target=$(gum input --placeholder "圖片檔案名（或輸入 all 批次處理）")

  if [[ -z "$target" ]]; then
    gum style --foreground 196 "必須指定檔案或 all"
    exit 1
  fi

  local args=("$target")

  local output
  output=$(gum input --placeholder "輸出 JSON 檔名（留空=輸出到終端）")
  [[ -n "$output" ]] && args+=(--output "$output")

  if gum confirm "格式化 JSON？" --default=Yes; then
    args+=(--pretty)
  fi

  exec "$0" "${args[@]}"
}

[[ "${1:-}" == "--interactive" ]] && interactive

TARGET=""
OUTPUT=""
PRETTY=false

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") echo "錯誤: 請指定檔案或 all"; usage; exit 1 ;;
  *) TARGET="$1"; shift ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) OUTPUT="$2"; shift 2 ;;
    --pretty) PRETTY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知參數: $1"; usage; exit 1 ;;
  esac
done

SRC_EXTS="png jpg jpeg webp avif bmp tiff tif gif"

is_image_ext() {
  local ext_lower="$1"
  for src_ext in $SRC_EXTS; do
    [[ "$ext_lower" == "$src_ext" ]] && return 0
  done
  return 1
}

PARSE_SCRIPT='
import sys, json

def parse_single(lines):
    info = {}
    properties = {}
    in_props = False
    current_key = None

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue

        if not in_props:
            if stripped.startswith("Filename:"):
                fname = stripped.split(": ", 1)[1]
                if fname.startswith("/data/"):
                    fname = fname[6:]
                info["file"] = fname
            elif stripped.startswith("Format:"):
                info["format"] = stripped.split(": ", 1)[1].split()[0]
            elif stripped.startswith("Geometry:"):
                info["geometry"] = stripped.split(": ", 1)[1]
            elif stripped.startswith("Colorspace:"):
                info["colorspace"] = stripped.split(": ", 1)[1]
            elif stripped.startswith("Filesize:"):
                info["filesize"] = stripped.split(": ", 1)[1]

        if stripped == "Properties:":
            in_props = True
            current_key = None
            continue

        if in_props:
            if line.startswith("    ") and not line.startswith("      "):
                if ": " in stripped:
                    key, _, val = stripped.partition(": ")
                    properties[key] = val
                    current_key = key
                elif stripped.endswith(":"):
                    in_props = False
                    current_key = None
            elif line.startswith("      ") and current_key:
                properties[current_key] += "\n" + stripped
            elif not line.startswith("    "):
                in_props = False
                current_key = None

    if properties:
        info["properties"] = properties

    return info

text = sys.stdin.read()
pretty = "--pretty" in sys.argv

blocks = []
current = []
for line in text.splitlines():
    if line.rstrip() == "Image:":
        if current:
            blocks.append(current)
        current = []
    else:
        current.append(line)
if current:
    blocks.append(current)

results = [parse_single(b) for b in blocks]

indent = 2 if pretty else None
print(json.dumps(results, indent=indent, ensure_ascii=False))
'

# Collect files
FILES=()

if [[ "$TARGET" == "all" ]]; then
  for f in /data/*; do
    [[ -f "$f" ]] || continue
    ext_lower=$(echo "${f##*.}" | tr '[:upper:]' '[:lower:]')
    is_image_ext "$ext_lower" || continue
    FILES+=("$f")
  done
  if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "目錄中沒有找到圖片檔案。"
    echo "支援格式: $SRC_EXTS"
    exit 0
  fi
else
  file="/data/$TARGET"
  if [[ ! -f "$file" ]]; then
    echo "錯誤: 找不到檔案 '$TARGET'"
    exit 1
  fi
  FILES+=("$file")
fi

echo "提取元資料: ${#FILES[@]} 個檔案" >&2

PRETTY_FLAG=""
[[ "$PRETTY" == true ]] && PRETTY_FLAG="--pretty"

COMBINED=""
processed=0
failed=0

for f in "${FILES[@]}"; do
  name=$(basename "$f")
  meta=$(identify -verbose "$f" 2>/dev/null) || {
    echo "  警告: 無法讀取 $name" >&2
    failed=$((failed + 1))
    continue
  }
  COMBINED+="$meta"$'\n'
  processed=$((processed + 1))
done

if [[ $processed -eq 0 ]]; then
  echo "沒有成功讀取任何檔案的元資料。" >&2
  exit 1
fi

RESULT=$(echo "$COMBINED" | python3 -c "$PARSE_SCRIPT" $PRETTY_FLAG)

if [[ -n "$OUTPUT" ]]; then
  echo "$RESULT" > "/data/$OUTPUT"
  echo "已輸出至 $OUTPUT（$processed 個檔案）" >&2
else
  echo "$RESULT"
fi

[[ $failed -gt 0 ]] && echo "警告: $failed 個檔案讀取失敗" >&2
echo "完成: 成功 $processed / 共 ${#FILES[@]} 個檔案" >&2
