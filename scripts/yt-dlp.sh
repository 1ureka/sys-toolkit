#!/bin/bash
set -euo pipefail

# yt-dlp — 下載公開影音資源

usage() {
  echo "用法: sys-toolkit yt-dlp <url[,url2,@file,...]> [OPTIONS]"
  echo ""
  echo "參數:"
  echo "  <url>    目標 URL，多個以逗號分隔 (僅支援公開資源)"
  echo "  @<file>  從清單文件讀取 URL（每行一個，# 開頭為註解）"
  echo "           可混用: url1,@list.txt,url2"
  echo ""
  echo "選項:"
  echo "  --audio-only         僅下載音訊並轉為 mp3"
  echo "  --format <id>        指定 yt-dlp format (預設: H.264+AAC 優先)"
  echo "  --output <template>  輸出檔名模版 (預設: %(title).80s.%(ext)s)"
  echo "  -h, --help           顯示此說明"
}

interactive() {
  local url=""

  if gum confirm "從清單文件讀取 URL？" --default=No; then
    local file
    file=$(gum file --directory /data --all)
    if [[ -z "$file" ]]; then
      gum style --foreground 196 "未選擇檔案"
      exit 1
    fi
    url="@$file"
  else
    url=$(gum input --placeholder "輸入 URL（多個以逗號分隔，可混用 @file）" --width 80)
  fi

  if [[ -z "$url" ]]; then
    gum style --foreground 196 "必須提供 URL"
    exit 1
  fi

  local args=("$url")

  if gum confirm "僅下載音訊（mp3）？" --default=No; then
    args+=(--audio-only)
  fi

  local output
  output=$(gum input --placeholder "輸出檔名模版（留空=預設）")
  [[ -n "$output" ]] && args+=(--output "$output")

  exec "$0" "${args[@]}"
}

[[ "${1:-}" == "--interactive" ]] && interactive

URLS=()
AUDIO_ONLY=false
FORMAT="bestvideo[vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[vcodec^=avc1]+bestaudio/bestvideo+bestaudio/best"
OUTPUT="%(title).80s.%(ext)s"

# Expand @file entries into URLs
resolve_urls() {
  local -a raw
  IFS=',' read -ra raw <<< "$1"
  for entry in "${raw[@]}"; do
    if [[ "$entry" == @* ]]; then
      local file="${entry#@}"
      if [[ ! -f "$file" ]]; then
        echo "錯誤: 清單文件不存在: $file" >&2
        exit 1
      fi
      while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"      # 移除註解
        line="${line#"${line%%[![:space:]]*}"}"   # trim 前導空白
        line="${line%"${line##*[![:space:]]}"}"
        [[ -n "$line" ]] && URLS+=("$line")
      done < "$file"
    else
      [[ -n "$entry" ]] && URLS+=("$entry")
    fi
  done
}

# Parse first positional arg
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") echo "錯誤: 請提供 URL"; usage; exit 1 ;;
  *) resolve_urls "$1"; shift ;;
esac

if [[ ${#URLS[@]} -eq 0 ]]; then
  echo "錯誤: 未解析到任何 URL"; usage; exit 1
fi

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --audio-only) AUDIO_ONLY=true; shift ;;
    --format)     FORMAT="$2"; shift 2 ;;
    --output)     OUTPUT="$2"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "未知參數: $1"; usage; exit 1 ;;
  esac
done

ARGS=(
  --no-warnings
  -o "/data/$OUTPUT"
)

if [[ "$AUDIO_ONLY" == true ]]; then
  ARGS+=(
    -x
    --audio-format mp3
    --audio-quality 0
  )
else
  ARGS+=(
    -f "$FORMAT"
    --merge-output-format mp4
    --postprocessor-args "Merger+ffmpeg:-c:v copy -c:a aac -b:a 192k"
  )
fi

TOTAL=${#URLS[@]}
FAILED=0
for i in "${!URLS[@]}"; do
  url="${URLS[$i]}"
  echo "[$((i+1))/$TOTAL] 下載中: $url"
  if yt-dlp "${ARGS[@]}" "$url"; then
    echo "[$((i+1))/$TOTAL] 下載完成。"
  else
    echo "[$((i+1))/$TOTAL] 下載失敗: $url"
    FAILED=$((FAILED + 1))
  fi
done

if [[ $FAILED -gt 0 ]]; then
  echo "全部完成，$FAILED/$TOTAL 個失敗。"
  exit 1
else
  echo "全部完成，共 $TOTAL 個。"
fi
