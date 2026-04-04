#!/bin/bash
set -euo pipefail

usage() {
  echo "用法: sys-toolkit <command> [options]"
  echo ""
  echo "可用指令:"
  echo "  count-lines   統計目錄下所有檔案的行數"
  echo "  empty-dirs    檢查空資料夾"
  echo "  extract       快速解壓縮"
  echo "  img-convert   圖像格式轉換"
  echo "  video-frames  影像擷取"
  echo "  yt-dlp        下載公開影音資源"
  echo ""
  echo "不帶參數執行會進入互動模式。"
  echo "各指令可加 --help 查看詳細用法。"
}

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
  "")            run_interactive_menu ;;
  -h|--help)     usage; exit 0 ;;
  count-lines)   shift; exec /scripts/count-lines.sh "$@" ;;
  empty-dirs)    shift; exec /scripts/empty-dirs.sh "$@" ;;
  extract)       shift; exec /scripts/extract.sh "$@" ;;
  img-convert)   shift; exec /scripts/img-convert.sh "$@" ;;
  video-frames)  shift; exec /scripts/video-frames.sh "$@" ;;
  yt-dlp)        shift; exec /scripts/yt-dlp.sh "$@" ;;
  *)             echo "未知指令: $1"; usage; exit 1 ;;
esac
