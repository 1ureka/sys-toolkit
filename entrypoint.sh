#!/bin/bash
set -euo pipefail

run_interactive_menu() {
  gum style \
    --border rounded --padding "0 2" --margin "1 0" \
    "sys-toolkit"

  local cmd
  cmd=$(gum choose --header "選擇功能" \
    "count-lines  — 統計檔案行數" \
    "empty-dirs   — 檢查空資料夾" \
    "extract      — 快速解壓縮" \
    "img-convert  — 圖像格式轉換" \
    "video-frames — 影像擷取" \
    "yt-dlp       — 下載公開影音資源")

  exec /scripts/"${cmd%% *}".sh --interactive
}

case "${1:-}" in
  count-lines)   shift; exec /scripts/count-lines.sh "$@" ;;
  empty-dirs)    shift; exec /scripts/empty-dirs.sh "$@" ;;
  extract)       shift; exec /scripts/extract.sh "$@" ;;
  img-convert)   shift; exec /scripts/img-convert.sh "$@" ;;
  video-frames)  shift; exec /scripts/video-frames.sh "$@" ;;
  yt-dlp)        shift; exec /scripts/yt-dlp.sh "$@" ;;
  *)             run_interactive_menu ;;
esac
