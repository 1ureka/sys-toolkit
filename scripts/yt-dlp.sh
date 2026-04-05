#!/bin/bash
set -euo pipefail

# yt-dlp — 下載公開影音資源

usage() {
  echo "用法: sys-toolkit yt-dlp <url[,url2,...]> [OPTIONS]"
  echo ""
  echo "參數:"
  echo "  <url>  目標 URL，多個以逗號分隔 (僅支援公開資源)"
  echo ""
  echo "選項:"
  echo "  --audio-only         僅下載音訊並轉為 mp3"
  echo "  --format <id>        指定 yt-dlp format (預設: H.264+AAC 優先)"
  echo "  --output <template>  輸出檔名模版 (預設: %(title)s.%(ext)s)"
  echo "  -h, --help           顯示此說明"
}

interactive() {
  local url
  url=$(gum input --placeholder "輸入 URL（多個以逗號分隔）" --width 80)

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
OUTPUT="%(title)s.%(ext)s"

# Parse first positional arg
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") echo "錯誤: 請提供 URL"; usage; exit 1 ;;
  *) IFS=',' read -ra URLS <<< "$1"; shift ;;
esac

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
    ((FAILED++))
  fi
done

if [[ $FAILED -gt 0 ]]; then
  echo "全部完成，$FAILED/$TOTAL 個失敗。"
  exit 1
else
  echo "全部完成，共 $TOTAL 個。"
fi
